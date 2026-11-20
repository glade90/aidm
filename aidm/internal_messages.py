"""Shared AIDM in-process request/result contracts, not an agent framework.

Purpose: Traceable, typed component-boundary calls with safe failure semantics.
Usage: from aidm.internal_messages import make_request, make_child_request, safe_call
Change Log: 2026-11-20 COSTA — AIDM-DES-033.1 first contract increment.

Neither caller nor knowledge_scope is an authorization credential. Actual permissions,
state/version locking, command deduplication and commits belong to trusted services.
No HTTP, CrewAI, LLM, persistence, retries or dispatch engine lives here.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, field
from enum import Enum
import re
from typing import Any
from uuid import uuid4


class ResultStatus(str, Enum):
    """The six possible boundary outcomes; HANDOFF is not completion."""

    COMPLETED = "COMPLETED"
    NEEDS_PLAYER_INPUT = "NEEDS_PLAYER_INPUT"
    BLOCKED = "BLOCKED"
    NEEDS_RULING = "NEEDS_RULING"
    ERROR = "ERROR"
    HANDOFF = "HANDOFF"


class ErrorCode(str, Enum):
    """Stable codes without raw exception text or sensitive details."""

    INVALID_INPUT = "INVALID_INPUT"
    UNAUTHORISED = "UNAUTHORISED"
    UNKNOWN_CAPABILITY = "UNKNOWN_CAPABILITY"
    UNSUPPORTED_RULE = "UNSUPPORTED_RULE"
    STATE_VERSION_CONFLICT = "STATE_VERSION_CONFLICT"
    TIMEOUT = "TIMEOUT"
    DEPENDENCY_UNAVAILABLE = "DEPENDENCY_UNAVAILABLE"
    INTERNAL_ERROR = "INTERNAL_ERROR"


_SAFE_EXPLANATIONS: dict[ErrorCode, str] = {
    ErrorCode.INVALID_INPUT: "The request needs correction or clarification.",
    ErrorCode.UNAUTHORISED: "That operation is not permitted.",
    ErrorCode.UNKNOWN_CAPABILITY: "This operation is not supported.",
    ErrorCode.UNSUPPORTED_RULE: "This operation needs a rules ruling.",
    ErrorCode.STATE_VERSION_CONFLICT: "The world state has changed; refresh before continuing.",
    ErrorCode.TIMEOUT: "The operation's outcome is unknown; check authoritative state before retrying.",
    ErrorCode.DEPENDENCY_UNAVAILABLE: "A required service is currently unavailable.",
    ErrorCode.INTERNAL_ERROR: "The operation could not be completed.",
}
_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
_NAME_RE = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,63}\Z")


class ContractError(ValueError):
    """Safe validation error; never formats the rejected value."""


class UnknownOperation(Exception):
    """Trusted tool reports an operation not implemented by that tool."""


class PlayerClarificationRequired(Exception):
    """Trusted tool needs clarification instead of guessing an outcome."""


class RulesRulingRequired(Exception):
    """Trusted tool cannot resolve a rule deterministically."""


class ServiceUnavailable(Exception):
    """Trusted tool dependency is unavailable; no automatic retry."""


def _identifier(value: object, field_name: str, *, optional: bool = False) -> None:
    if optional and value is None:
        return
    if not isinstance(value, str) or _ID_RE.fullmatch(value) is None:
        raise ContractError(f"Invalid {field_name}; expected nonempty identifier")


def _operation_name(value: object, name: str) -> None:
    if not isinstance(value, str) or _NAME_RE.fullmatch(value) is None:
        raise ContractError(f"Invalid {name}; expected a simple operation name")


def _version(value: object, name: str) -> None:
    if type(value) is not int or value < 0:
        raise ContractError(f"Invalid {name}; expected nonnegative integer")


def _payload(value: object, name: str) -> dict[str, Any]:
    if not isinstance(value, Mapping) or any(
        not isinstance(key, str) or not _NAME_RE.fullmatch(key) for key in value
    ):
        raise ContractError(f"Invalid {name}; expected mapping with named fields")
    return dict(value)  # Snapshot outer mapping; nested domain values remain tool-owned.


@dataclass(frozen=True, slots=True)
class InternalRequest:
    """One boundary invocation. Claimed caller and scope are NOT permissions."""

    request_id: str
    correlation_id: str
    caller: str
    capability: str
    operation: str
    payload: Mapping[str, Any]
    session_id: str | None = None
    campaign_id: str | None = None
    expedition_id: str | None = None
    encounter_id: str | None = None
    parent_request_id: str | None = None
    knowledge_scope: str | None = None
    is_mutation: bool = False
    command_id: str | None = None
    expected_world_version: int | None = None

    def __post_init__(self) -> None:
        for name in ("request_id", "correlation_id", "caller"):
            _identifier(getattr(self, name), name)
        for name in ("capability", "operation"):
            _operation_name(getattr(self, name), name)
        for name in (
            "session_id", "campaign_id", "expedition_id", "encounter_id",
            "parent_request_id", "knowledge_scope",
        ):
            _identifier(getattr(self, name), name, optional=True)
        object.__setattr__(self, "payload", _payload(self.payload, "payload"))
        if type(self.is_mutation) is not bool:
            raise ContractError("Invalid is_mutation flag")
        if self.is_mutation:
            _identifier(self.command_id, "command_id")
            _version(self.expected_world_version, "expected_world_version")
        elif self.command_id is not None or self.expected_world_version is not None:
            raise ContractError("Read-only request cannot carry mutation metadata")


def make_request(
    *, caller: str, capability: str, operation: str, payload: Mapping[str, Any],
    request_id: str | None = None, correlation_id: str | None = None,
    **context: Any,
) -> InternalRequest:
    """Construct a boundary request, generating IDs if a trusted entrypoint has not."""
    rid = request_id if request_id is not None else f"call-{uuid4().hex}"
    cid = correlation_id if correlation_id is not None else rid
    return InternalRequest(
        request_id=rid, correlation_id=cid,
        caller=caller, capability=capability, operation=operation, payload=payload,
        **context,
    )


def make_child_request(
    parent: InternalRequest, *, caller: str, capability: str,
    operation: str, payload: Mapping[str, Any], request_id: str | None = None,
    **context: Any,
) -> InternalRequest:
    """New invocation ID, same correlation ID and causation, inherited domain context.

    Mutation metadata must be supplied explicitly; do not reuse a parent's
    command ID or automatically retry a state-changing action.
    """
    inherited = {
        name: getattr(parent, name)
        for name in ("session_id", "campaign_id", "expedition_id", "encounter_id", "knowledge_scope")
    }
    if "correlation_id" in context or "parent_request_id" in context:
        raise ContractError("Child correlation and parent request ID are inherited")
    inherited.update(context)
    if request_id is not None and request_id == parent.request_id:
        raise ContractError("Child invocation ID must be distinct from parent")
    return make_request(
        caller=caller, capability=capability, operation=operation, payload=payload,
        request_id=request_id, correlation_id=parent.correlation_id,
        parent_request_id=parent.request_id, **inherited,
    )


@dataclass(frozen=True, slots=True)
class SafeError:
    """Public-safe error envelope; use safe_error to avoid leaking exception text."""

    code: ErrorCode
    message: str
    source_operation: str
    correlation_id: str

    def __post_init__(self) -> None:
        if not isinstance(self.code, ErrorCode):
            raise ContractError("Invalid error_code")
        _operation_name(self.source_operation, "source_operation")
        _identifier(self.correlation_id, "correlation_id")
        # Only fixed approved messages are accepted for the first increment.
        if self.message != _SAFE_EXPLANATIONS[self.code]:
            raise ContractError("Unsafe error description")


def safe_error(request: InternalRequest, code: ErrorCode) -> SafeError:
    """Create a safe error without copying untrusted exception or payload text."""
    if not isinstance(code, ErrorCode):
        raise ContractError("Invalid error_code")
    return SafeError(code, _SAFE_EXPLANATIONS[code], request.operation, request.correlation_id)


@dataclass(frozen=True, slots=True)
class CommittedEffects:
    """Receipt data from an actual trusted commit; this type itself grants no trust.

    Bookkeeper (later Story) must authoritatively verify these IDs and version.
    Never synthesize this receipt from an LLM proposal or an arbitrary HTTP body.
    """

    command_id: str
    event_refs: tuple[str, ...]
    new_world_version: int

    def __post_init__(self) -> None:
        _identifier(self.command_id, "committed_command_id")
        if (not isinstance(self.event_refs, tuple) or not self.event_refs
                or any(not isinstance(value, str) or not _ID_RE.fullmatch(value) for value in self.event_refs)
                or len(set(self.event_refs)) != len(self.event_refs)):
            raise ContractError("Invalid committed event references")
        _version(self.new_world_version, "new_world_version")


@dataclass(frozen=True, slots=True)
class InternalResult:
    """One invocation outcome. Data and player summary must be projected by trusted code."""

    request_id: str
    correlation_id: str
    status: ResultStatus
    safe_summary: str | None = None
    data: Mapping[str, Any] = field(default_factory=dict)
    error: SafeError | None = None
    committed_effects: CommittedEffects | None = None

    def __post_init__(self) -> None:
        _identifier(self.request_id, "request_id")
        _identifier(self.correlation_id, "correlation_id")
        if not isinstance(self.status, ResultStatus):
            raise ContractError("Invalid result status")
        if self.safe_summary is not None and (not isinstance(self.safe_summary, str)
                                               or not self.safe_summary.strip()):
            raise ContractError("Invalid player-safe summary")
        object.__setattr__(self, "data", _payload(self.data, "result data"))
        if self.error is not None and (
            not isinstance(self.error, SafeError) or self.error.correlation_id != self.correlation_id
        ):
            raise ContractError("Error and result correlation must match")
        if self.status in (ResultStatus.ERROR, ResultStatus.BLOCKED) and self.error is None:
            raise ContractError("ERROR/BLOCKED results require a safe error")
        if self.error is not None and self.status not in (
            ResultStatus.ERROR, ResultStatus.BLOCKED, ResultStatus.NEEDS_PLAYER_INPUT,
            ResultStatus.NEEDS_RULING,
        ):
            raise ContractError("Successful/handoff results cannot carry errors")
        if self.committed_effects is not None and (
            not isinstance(self.committed_effects, CommittedEffects)
            or self.status != ResultStatus.COMPLETED
        ):
            raise ContractError("Committed events require an actual completed result")

    @property
    def event_refs(self) -> tuple[str, ...]:
        """Event references are empty until a trusted service supplies a receipt."""
        return self.committed_effects.event_refs if self.committed_effects else ()

    @property
    def new_world_version(self) -> int | None:
        return self.committed_effects.new_world_version if self.committed_effects else None


def make_result(
    request: InternalRequest, status: ResultStatus, *,
    safe_summary: str | None = None, data: Mapping[str, Any] | None = None,
    error_code: ErrorCode | None = None, committed_effects: CommittedEffects | None = None,
) -> InternalResult:
    """Return outcome matching the request, without treating proposals as commits."""
    if committed_effects is not None:
        if (not request.is_mutation or request.command_id != committed_effects.command_id
                or committed_effects.new_world_version <= request.expected_world_version):
            raise ContractError("Commit receipt does not match the world command")
    return InternalResult(
        request_id=request.request_id,
        correlation_id=request.correlation_id,
        status=status,
        safe_summary=safe_summary,
        data=data if data is not None else {},
        error=safe_error(request, error_code) if error_code is not None else None,
        committed_effects=committed_effects,
    )


def safe_failure(request: InternalRequest, code: ErrorCode, *,
                 status: ResultStatus = ResultStatus.ERROR) -> InternalResult:
    """Fixed safe response; no raw exceptions, event claims, or writes."""
    return make_result(request, status, error_code=code)


def safe_call(
    request: InternalRequest,
    handler: Callable[[InternalRequest], InternalResult],
    *, supported_operations: Iterable[str] | None = None,
) -> InternalResult:
    """Protect a single injected tool boundary; NOT a registry or dispatcher.

    This helper cannot authenticate callers or filter the tool's player projection.
    Trusted callers must enforce authorization and knowledge scope outside it.
    No automatic retries, especially for state-changing commands.
    """
    if supported_operations is not None and request.operation not in supported_operations:
        return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
    try:
        result = handler(request)
        if not isinstance(result, InternalResult) or (
            result.request_id != request.request_id
            or result.correlation_id != request.correlation_id
        ):
            return safe_failure(request, ErrorCode.INTERNAL_ERROR)
        if result.committed_effects is not None:
            # A trusted adapter must separately verify this receipt with Bookkeeper.
            if (not request.is_mutation or request.command_id != result.committed_effects.command_id
                    or result.new_world_version <= request.expected_world_version):
                return safe_failure(request, ErrorCode.INTERNAL_ERROR)
        return result
    except UnknownOperation:
        return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
    except PlayerClarificationRequired:
        return safe_failure(request, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT)
    except RulesRulingRequired:
        return safe_failure(request, ErrorCode.UNSUPPORTED_RULE, status=ResultStatus.NEEDS_RULING)
    except PermissionError:
        return safe_failure(request, ErrorCode.UNAUTHORISED, status=ResultStatus.BLOCKED)
    except TimeoutError:
        return safe_failure(request, ErrorCode.TIMEOUT)
    except ServiceUnavailable:
        return safe_failure(request, ErrorCode.DEPENDENCY_UNAVAILABLE)
    except Exception:  # Only the public boundary is sanitized, never catch BaseException.
        return safe_failure(request, ErrorCode.INTERNAL_ERROR)