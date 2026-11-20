"""Deterministic fake DM and dispatcher for a local request-to-mock-tool demo.

Purpose: Show one injected tool call without an LLM, dice, damage, or game state.
Usage: uvicorn aidm.meta.mock_turn:create_mock_app --factory --host 127.0.0.1
Change Log: 2026-11-20 DAVOS — AIDM-DES-013.2 demo composition.
"""

from __future__ import annotations

import re

from aidm.config import Settings
from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_child_request,
    make_result, safe_call, safe_failure, ServiceUnavailable,
)
from aidm.meta.http import create_app
from aidm.meta.runtime import MockTool, RuntimeLogger, ServiceRegistry

_OPERATION = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,63}\Z")


class MockDispatcher:
    """Only calls an explicitly registered mock tool; no production routing."""

    def __init__(self, registry: ServiceRegistry) -> None:
        self.registry = registry

    def __call__(self, request: InternalRequest) -> InternalResult:
        if request.capability != "mock_tool":
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
        tool = self.registry.get("mock_tool")
        if not callable(tool):
            raise ServiceUnavailable()
        return safe_call(request, tool, supported_operations=("mock_ping",))


class MockDungeonMaster:
    """Pretends to understand a turn; it never interprets real combat rules."""

    def __init__(self, registry: ServiceRegistry) -> None:
        self.registry = registry

    def __call__(self, request: InternalRequest) -> InternalResult:
        if request.operation != "player_turn":
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
        message = request.payload["message"]
        is_attack = "attack" in message.casefold()
        operation = "mock_ping"
        if message.casefold().startswith("tool:"):
            operation = message[5:].strip()
            if _OPERATION.fullmatch(operation) is None:
                operation = "unsupported_operation"
        child = make_child_request(
            request, caller="DM", capability="mock_tool", operation=operation, payload={},
        )
        dispatcher = self.registry.get("dispatcher")
        if not callable(dispatcher):
            raise ServiceUnavailable()
        tool_result = safe_call(child, dispatcher)
        if tool_result.status is ResultStatus.COMPLETED:
            summary = (
                "Mock attack demonstration only. No attack roll, damage, or HP change "
                "was calculated. " + (tool_result.safe_summary or "")
                if is_attack else tool_result.safe_summary
            )
            return make_result(
                request, ResultStatus.COMPLETED, safe_summary=summary,
                data={"mock": True},
            )
        return make_result(
            request, tool_result.status, safe_summary=tool_result.safe_summary,
            error_code=tool_result.error.code if tool_result.error else None,
        )


def create_mock_app(*, settings: Settings | None = None, logger: RuntimeLogger | None = None):
    """Compose COSTA's one Meta app with fake services; no second HTTP server."""
    registry = ServiceRegistry(required=("dm", "dispatcher", "mock_tool"))
    registry.register("mock_tool", MockTool())
    registry.register("dispatcher", MockDispatcher(registry))
    registry.register("dm", MockDungeonMaster(registry))
    return create_app(settings=settings, registry=registry, logger=logger)
