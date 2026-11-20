"""Framework-neutral Golden Braid agent superclass (DES-042.1).

Purpose: One injected, approved-context model invocation; no tools or domain state.
Usage: from braider import Braider, ModelChoice, ContextItem, ModelTarget
Change Log: 2026-11-20 COSTA — AIDM-DES-042.1 first reusable increment.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from enum import Enum
from typing import Protocol


class ModelChoice(str, Enum):
    """Logical quality/cost choices, never actual model identifiers."""

    ECONOMY = "economy"
    BALANCED = "balanced"
    CAPABLE = "capable"


class ContextItem(str, Enum):
    """Categories of pre-authorised context; categories confer no permission."""

    RECENT_CONVERSATION = "recent_conversation"
    TASK_CONTEXT = "task_context"
    REFERENCE_MATERIAL = "reference_material"
    WORKING_STATE = "working_state"


class BraiderErrorCode(str, Enum):
    """Stable safe inference errors (not an AIDM service status)."""

    INVALID_INPUT = "INVALID_INPUT"
    CONTEXT_NOT_APPROVED = "CONTEXT_NOT_APPROVED"
    MODEL_NOT_CONFIGURED = "MODEL_NOT_CONFIGURED"
    MODEL_ERROR = "MODEL_ERROR"


@dataclass(frozen=True, slots=True)
class ModelTarget:
    """Injected opaque provider/model coordinates, not credentials."""

    provider: str
    model: str

    def __post_init__(self) -> None:
        for value in (self.provider, self.model):
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Provider and model names must be nonempty")


@dataclass(frozen=True, slots=True)
class BraiderOutput:
    """A model's proposed text or a safe error; never an executed action."""

    text: str | None
    error_code: BraiderErrorCode | None
    model_choice: ModelChoice
    model_target: ModelTarget | None
    trace_id: str | None = None

    @property
    def succeeded(self) -> bool:
        return self.error_code is None


class ModelRuntime(Protocol):
    """Replaceable provider/fake, called exactly once for an accepted input."""

    def invoke(
        self,
        *,
        model_target: ModelTarget,
        instructions: str,
        input_text: str,
        approved_context: Mapping[ContextItem, str],
    ) -> str:
        ...


class FakeModelRuntime:
    """Offline deterministic fake. It NEVER contacts an LLM or external host."""

    def __init__(self, response: str = "Simulated model response", *, fail: bool = False) -> None:
        self.response = response
        self.fail = fail
        self.calls: list[dict[str, object]] = []

    def invoke(
        self,
        *,
        model_target: ModelTarget,
        instructions: str,
        input_text: str,
        approved_context: Mapping[ContextItem, str],
    ) -> str:
        self.calls.append({
            "model_target": model_target,
            "instructions": instructions,
            "input_text": input_text,
            "approved_context": dict(approved_context),
        })
        if self.fail:
            raise RuntimeError("Injected private diagnostic value must never escape")
        return self.response


class Braider:
    """Project-neutral superclass, not an orchestrator, context provider or agent loop.

    The caller's trusted adapter must assemble and authorise the context; this
    class only checks an explicitly configured category allowlist. No retries,
    tool use, memory, retrieval, network, credentials, or domain-side effects.
    """

    def __init__(
        self,
        *,
        runtime: ModelRuntime,
        model_targets: Mapping[ModelChoice, ModelTarget],
        model_choice: ModelChoice = ModelChoice.BALANCED,
        allowed_context: frozenset[ContextItem] = frozenset(),
        instructions: str = "",
    ) -> None:
        if not isinstance(model_choice, ModelChoice):
            raise ValueError("Invalid model choice")
        if not isinstance(model_targets, Mapping) or any(
            not isinstance(key, ModelChoice) or not isinstance(value, ModelTarget)
            for key, value in model_targets.items()
        ):
            raise ValueError("Invalid model mapping")
        if not isinstance(allowed_context, frozenset) or any(
            not isinstance(item, ContextItem) for item in allowed_context
        ):
            raise ValueError("Invalid allowed context categories")
        if not isinstance(instructions, str):
            raise ValueError("Invalid instructions")
        self._runtime = runtime
        self._model_targets = dict(model_targets)
        self.model_choice = model_choice
        self.allowed_context = allowed_context
        self.instructions = instructions

    def invoke(
        self,
        input_text: str,
        *,
        approved_context: Mapping[ContextItem, str],
        trace_id: str | None = None,
    ) -> BraiderOutput:
        """One synchronous model proposal, after explicit context checks.

        A successful response means the fake/provider returned text, NOT that a
        game, database, tool, or external transaction has been committed.
        """
        trace = trace_id if isinstance(trace_id, str) and 0 < len(trace_id) <= 128 else None
        target = self._model_targets.get(self.model_choice)

        def failure(code: BraiderErrorCode) -> BraiderOutput:
            return BraiderOutput(None, code, self.model_choice, target, trace)

        if not isinstance(input_text, str) or not input_text.strip():
            return failure(BraiderErrorCode.INVALID_INPUT)
        if trace_id is not None and trace is None:
            return failure(BraiderErrorCode.INVALID_INPUT)
        if not isinstance(approved_context, Mapping):
            return failure(BraiderErrorCode.INVALID_INPUT)
        # Fail closed: category labels are not permissions; never forward
        # unapproved content, including content of an invalid packet.
        for category, value in approved_context.items():
            if not isinstance(category, ContextItem) or not isinstance(value, str):
                return failure(BraiderErrorCode.INVALID_INPUT)
            if category not in self.allowed_context:
                return failure(BraiderErrorCode.CONTEXT_NOT_APPROVED)
        if target is None:
            return failure(BraiderErrorCode.MODEL_NOT_CONFIGURED)
        try:
            result = self._runtime.invoke(
                model_target=target,
                instructions=self.instructions,
                input_text=input_text,
                approved_context=dict(approved_context),
            )
        except Exception:  # Provider exception text may contain secrets.
            return failure(BraiderErrorCode.MODEL_ERROR)
        if not isinstance(result, str) or not result.strip():
            return failure(BraiderErrorCode.MODEL_ERROR)
        return BraiderOutput(result, None, self.model_choice, target, trace)