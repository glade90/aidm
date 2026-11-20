"""Player-turn HTTP boundary, built on COSTA's Meta runtime and message contracts.

Purpose: Validate one local player turn and project only player-safe typed outcomes.
Usage: The Meta create_app factory mounts router at POST /api/turn.
Change Log: 2026-11-20 DAVOS — AIDM-DES-013.2 initial mock-first vertical slice.

No real DM, tool routing policy, combat mechanics or game state lives here.
"""

from __future__ import annotations

import asyncio
import re
from typing import Any

from fastapi import APIRouter, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator

from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_request,
    safe_call, safe_failure,
)
from aidm.meta.runtime import MissingServiceError

_IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
router = APIRouter()


class TurnRequest(BaseModel):
    """Only player-facing data; callers cannot claim an internal identity/scope."""

    model_config = ConfigDict(extra="forbid")
    message: str = Field(min_length=1, max_length=4000)
    session_id: str | None = None
    correlation_id: str | None = None

    @field_validator("message")
    @classmethod
    def nonblank_message(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Player message is required")
        return value.strip()

    @field_validator("session_id", "correlation_id")
    @classmethod
    def safe_identifier(cls, value: str | None) -> str | None:
        if value is not None and _IDENTIFIER.fullmatch(value) is None:
            raise ValueError("Invalid identifier")
        return value


class TurnError(BaseModel):
    code: ErrorCode
    message: str


class TurnResponse(BaseModel):
    status: ResultStatus
    message: str
    request_id: str
    correlation_id: str
    session_id: str | None = None
    simulated: bool = False
    tool_outcome: dict[str, bool] | None = None
    error: TurnError | None = None


_FALLBACK = {
    ResultStatus.COMPLETED: "The request was processed.",
    ResultStatus.NEEDS_PLAYER_INPUT: "Please clarify your request.",
    ResultStatus.BLOCKED: "That action is not available.",
    ResultStatus.NEEDS_RULING: "That action needs a ruling.",
    ResultStatus.ERROR: "The request could not be completed.",
    ResultStatus.HANDOFF: "The request was handed off; no action is confirmed complete.",
}


def _response(request: InternalRequest, result: InternalResult) -> TurnResponse:
    """Explicit allowlist; never serialize arbitrary result data or event claims."""
    mock = result.status is ResultStatus.COMPLETED and result.data.get("mock") is True
    return TurnResponse(
        status=result.status,
        message=result.safe_summary or (result.error.message if result.error else _FALLBACK[result.status]),
        request_id=result.request_id,
        correlation_id=result.correlation_id,
        session_id=request.session_id,
        simulated=mock,
        tool_outcome={"mock": True} if mock else None,
        error=TurnError(code=result.error.code, message=result.error.message) if result.error else None,
    )


def _http_status(result: InternalResult) -> int:
    if result.status is ResultStatus.ERROR:
        return 504 if result.error and result.error.code is ErrorCode.TIMEOUT else 503
    return 200


def _json(request: InternalRequest, result: InternalResult, *, status_code: int | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=_http_status(result) if status_code is None else status_code,
        content=_response(request, result).model_dump(mode="json"),
    )


async def turn_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Never expose Pydantic's input echo, invalid JSON fragments or tracebacks."""
    boundary = make_request(caller="Meta", capability="dm", operation="player_turn", payload={})
    return _json(
        boundary,
        safe_failure(boundary, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT),
        status_code=422,
    )


@router.post("/api/turn", response_model=TurnResponse)
async def player_turn(payload: TurnRequest, request: Request) -> Any:
    """One bounded call to an injected DM; no retries or game-state authority."""
    runtime = request.app.state.meta_runtime
    boundary = make_request(
        caller="Meta", capability="dm", operation="player_turn",
        payload={"message": payload.message},
        correlation_id=payload.correlation_id,
        session_id=payload.session_id,
    )
    with runtime.correlation(boundary.correlation_id):
        if not runtime.ready:
            return _json(boundary, safe_failure(boundary, ErrorCode.DEPENDENCY_UNAVAILABLE))
        try:
            handler = runtime.registry.get("dm")
        except MissingServiceError:
            return _json(boundary, safe_failure(boundary, ErrorCode.DEPENDENCY_UNAVAILABLE))
        if not callable(handler):
            return _json(boundary, safe_failure(boundary, ErrorCode.DEPENDENCY_UNAVAILABLE))
        try:
            # Thread offload keeps the ASGI event loop responsive. The demo is
            # read-only: a timed-out thread must never own real world-state writes.
            result = await asyncio.wait_for(
                asyncio.to_thread(safe_call, boundary, handler, supported_operations=("player_turn",)),
                timeout=runtime.settings.request_timeout_seconds,
            )
        except TimeoutError:
            result = safe_failure(boundary, ErrorCode.TIMEOUT)
        except Exception:
            result = safe_failure(boundary, ErrorCode.INTERNAL_ERROR)
        # The shared safe_call rejects mismatched IDs and fabricated write receipts.
        return _json(boundary, result)
