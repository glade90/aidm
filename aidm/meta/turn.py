"""Player-turn HTTP boundary, built on COSTA's Meta runtime and message contracts.

Purpose: Validate one local player turn and project only player-safe typed outcomes.
Usage: The Meta create_app factory mounts router at POST /api/turn.
Change Log: 2026-11-20 DAVOS — AIDM-DES-013.2 initial mock-first vertical slice.
            2026-11-20 DAVOS — AIDM-DES-025.2 additive typed combat turn/view.

No real combat mechanics or game state lives here. The typed combat view is
strictly an allowlisted projection; an injected Combat Session owns state.
"""

from __future__ import annotations

import asyncio
import re
from typing import Any, Literal

from fastapi import APIRouter, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator

from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_request,
    safe_call, safe_failure,
)
from aidm.meta.runtime import MissingServiceError

_IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
router = APIRouter()


class CombatTurnIntent(BaseModel):
    """Additive, player-supplied CLAIMS only; server verifies every token/ID."""

    model_config = ConfigDict(extra="forbid")
    kind: Literal["START", "ACTION", "VIEW_LOG", "RESET"]
    encounter_id: str | None = None
    actor_id: str | None = None
    decision_token: str | None = None
    expected_encounter_version: int | None = Field(default=None, ge=0)
    client_action_id: str | None = None
    log_since_sequence: int | None = Field(default=None, ge=0)

    @field_validator("encounter_id", "actor_id", "decision_token", "client_action_id")
    @classmethod
    def safe_combat_identifier(cls, value: str | None) -> str | None:
        if value is not None and _IDENTIFIER.fullmatch(value) is None:
            raise ValueError("Invalid combat identifier")
        return value

    @model_validator(mode="after")
    def require_action_fields(self):
        if self.kind == "ACTION" and any(
            value is None for value in (
                self.encounter_id, self.actor_id, self.decision_token,
                self.expected_encounter_version, self.client_action_id,
            )
        ):
            raise ValueError("Combat ACTION requires current decision metadata")
        if self.kind in ("VIEW_LOG", "RESET") and self.encounter_id is None:
            raise ValueError("Combat VIEW_LOG or RESET requires encounter identifier")
        return self


class TurnRequest(BaseModel):
    """Existing message-only turns plus optional typed combat intent."""

    model_config = ConfigDict(extra="forbid")
    message: str | None = Field(default=None, max_length=4000)
    session_id: str | None = None
    correlation_id: str | None = None
    combat: CombatTurnIntent | None = None

    @field_validator("message")
    @classmethod
    def nonblank_message(cls, value: str | None) -> str | None:
        return value.strip() if value is not None else None

    @field_validator("session_id", "correlation_id")
    @classmethod
    def safe_identifier(cls, value: str | None) -> str | None:
        if value is not None and _IDENTIFIER.fullmatch(value) is None:
            raise ValueError("Invalid identifier")
        return value

    @model_validator(mode="after")
    def require_text_at_action_time(self):
        # Preserve strict legacy request validation. START/VIEW_LOG are the
        # only permitted typed control turns without player prose.
        if (self.combat is None or self.combat.kind == "ACTION") and not self.message:
            raise ValueError("Player message required")
        return self


class CombatRollView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    attack_face: int | None = None
    attack_die_id: str | None = None
    attack_modifier: int | None = None
    attack_total: int | None = None
    damage_face: int | None = None
    damage_die_id: str | None = None
    damage_modifier: int | None = None
    damage_total: int | None = None
    hit: bool | None = None


class CombatLogView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    seq: int = Field(ge=1)
    round: int = Field(ge=1)
    phase: str = Field(max_length=80)
    kind: str = Field(max_length=80)
    text: str = Field(max_length=1000)
    cue: Literal["HIT", "MISS", "FALL", "HOLD", "ROUND", "INITIATIVE",
                 "VICTORY", "DEFEAT", "END"] | None = None
    roll: CombatRollView | None = None


class CombatDecisionView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    actor_id: str
    prompt: str = Field(max_length=1000)
    decision_token: str
    allowed_targets: list[str]


class PartyMemberView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    actor_id: str
    name: str
    hp_current: int = Field(ge=0)
    hp_max: int = Field(ge=0)


class PlayerCombatView(BaseModel):
    """Deliberately narrow public allowlist. No opponent exact HP/AC/secrets."""

    model_config = ConfigDict(extra="forbid")
    encounter_id: str
    intent_mode: Literal["OFFLINE_SCRIPTED", "LIVE_LLM", "INJECTED_POLICY"] = "OFFLINE_SCRIPTED"
    state_version: int = Field(ge=0)
    current_round: int = Field(ge=1)
    phase_label: str = Field(max_length=80)
    terminal: bool
    outcome: str | None
    awaiting_player: bool
    next_decision: CombatDecisionView | None = None
    new_log_entries: list[CombatLogView]
    log_next_cursor: int = Field(ge=0)
    party_status: list[PartyMemberView] = Field(default_factory=list)
    surviving_party_summary: list[PartyMemberView] | None = None
    deferred_labels: list[str]


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
    combat: PlayerCombatView | None = None


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
    combat_view = None
    raw_view = result.data.get("combat_view")
    if raw_view is not None:
        try:
            combat_view = PlayerCombatView.model_validate(raw_view)
        except (ValueError, TypeError, ValidationError):
            # Never forward arbitrary or malformed specialist private data.
            return TurnResponse(
                status=ResultStatus.ERROR,
                message="The combat result could not be safely displayed.",
                request_id=request.request_id,
                correlation_id=request.correlation_id,
                session_id=request.session_id,
                error=TurnError(code=ErrorCode.INTERNAL_ERROR,
                                message="The operation could not be completed."),
            )
    return TurnResponse(
        status=result.status,
        message=result.safe_summary or (result.error.message if result.error else _FALLBACK[result.status]),
        request_id=result.request_id,
        correlation_id=result.correlation_id,
        session_id=request.session_id,
        simulated=mock,
        tool_outcome={"mock": True} if mock else None,
        error=TurnError(code=result.error.code, message=result.error.message) if result.error else None,
        combat=combat_view,
    )


def _http_status(result: InternalResult) -> int:
    if result.status is ResultStatus.ERROR:
        return 504 if result.error and result.error.code is ErrorCode.TIMEOUT else 503
    return 200


def _json(request: InternalRequest, result: InternalResult, *, status_code: int | None = None) -> JSONResponse:
    public = _response(request, result)
    code = _http_status(result) if status_code is None else status_code
    if public.status is ResultStatus.ERROR and result.status is not ResultStatus.ERROR:
        code = 503  # A malformed proposed public combat view failed projection.
    return JSONResponse(status_code=code, content=public.model_dump(mode="json"))


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
        payload={
            "message": payload.message if payload.message is not None else "",
            **({"combat": payload.combat.model_dump(mode="json", exclude_none=True)}
               if payload.combat is not None else {}),
        },
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
            # Thread offload keeps ASGI responsive. State-changing combat work
            # may CONTINUE after timeout: no rollback/retry is implied. Clients
            # must VIEW_LOG before reissuing a potentially completed action.
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
