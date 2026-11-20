"""Combat specialist demonstration behind AIDM's internal service boundary.

Purpose: Test-only CombatAgent(Braider) with untrusted inference, no combat mechanics.
Usage: combat = CombatAgent(runtime=fake, model_targets=targets, approved_encounter_context="...")
       result = combat.handle(request)
Change Log: 2026-11-20 COSTA — AIDM-DES-004.1 mock combat handler.
"""

from __future__ import annotations

from collections.abc import Mapping

from braider import Braider, BraiderErrorCode, ContextItem, ModelChoice, ModelRuntime, ModelTarget

from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_result, safe_failure,
)


MOCK_COMBAT_OPERATION = "mock_combat_intent"


class CombatAgent(Braider):
    """A small synthetic Combat Orchestrator handler, not a rules engine.

    Does not interpret rules, make dice rolls, change HP, write events or speak
    directly to the player. A trusted application injects already-approved
    encounter context; untrusted request payload cannot expand this context.
    """

    def __init__(
        self,
        *,
        runtime: ModelRuntime,
        model_targets: Mapping[ModelChoice, ModelTarget],
        approved_encounter_context: str,
        model_choice: ModelChoice = ModelChoice.BALANCED,
    ) -> None:
        if not isinstance(approved_encounter_context, str) or not approved_encounter_context.strip():
            raise ValueError("Approved synthetic encounter context must be nonempty")
        super().__init__(
            runtime=runtime,
            model_targets=model_targets,
            model_choice=model_choice,
            instructions=(
                "Synthetic CombatAgent demonstration only. "
                "Return a proposed intention, not a rules result."
            ),
            allowed_context=frozenset({ContextItem.TASK_CONTEXT}),
        )
        self._approved_encounter_context = approved_encounter_context

    def handle(self, request: InternalRequest) -> InternalResult:
        """Adapter to DES-033.1; safe even when called without a Dungeon Master."""
        if request.capability != "combat" or request.operation != MOCK_COMBAT_OPERATION:
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY,
                                status=ResultStatus.BLOCKED)
        if request.is_mutation:
            # A proposed attack must never accidentally become a world command.
            return safe_failure(request, ErrorCode.UNSUPPORTED_RULE,
                                status=ResultStatus.BLOCKED)
        player_text = request.payload.get("player_text")
        if not isinstance(player_text, str) or not player_text.strip():
            return safe_failure(request, ErrorCode.INVALID_INPUT,
                                status=ResultStatus.NEEDS_PLAYER_INPUT)
        proposal = self.invoke(
            player_text, approved_context={ContextItem.TASK_CONTEXT: self._approved_encounter_context},
            trace_id=request.correlation_id,
        )
        if proposal.error_code is not None:
            if proposal.error_code is BraiderErrorCode.CONTEXT_NOT_APPROVED:
                return safe_failure(request, ErrorCode.UNAUTHORISED,
                                    status=ResultStatus.BLOCKED)
            if proposal.error_code is BraiderErrorCode.INVALID_INPUT:
                return safe_failure(request, ErrorCode.INVALID_INPUT,
                                    status=ResultStatus.NEEDS_PLAYER_INPUT)
            return safe_failure(request, ErrorCode.DEPENDENCY_UNAVAILABLE)
        # The model's proposal is untrusted. It is not copied to the player-safe
        # summary or a generally exposed result data field until a future
        # trusted validator/projector exists. This proves the injectable seam.
        return make_result(
            request, ResultStatus.COMPLETED,
            safe_summary=(
                "Simulation only: the combat intention was received; "
                "no dice were rolled, no damage was calculated, "
                "and no hit points or world state were changed."
            ),
            data={
                "simulated": True,
                "original_player_text": player_text,
                "proposal_received": True,
                "combat_resolved": False,
            },
        )