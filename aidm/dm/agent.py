"""Thin player-facing Dungeon Master gateway for the combat-first AIDM prototype.

Purpose: Forward one approved synthetic combat turn to an injected specialist.
Usage: dm = DungeonMasterAgent(runtime=fake, model_targets=targets,
                              combat_handler=combat.handle,
                              approved_encounter_id="synthetic-encounter")
       result = dm.handle(player_turn_request)
Change Log: 2026-11-20 DAVOS — AIDM-DES-015.2 initial non-LLM gateway.
            2026-11-20 DAVOS — AIDM-DES-014.1 accept the approved period fixture.

The DM inherits programme-wide Braider but deliberately never calls invoke().
Real DM intent selection, narration, context memory and game state are deferred.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping

from braider import Braider, ModelChoice, ModelRuntime, ModelTarget

from aidm.combat import MOCK_COMBAT_OPERATION
from aidm.internal_messages import (
    ContractError, ErrorCode, InternalRequest, InternalResult, ResultStatus,
    make_child_request, make_result, safe_call, safe_failure,
)

# This narrowly scripted fixture is NOT a natural-language intent router.
# DES-016 and DES-041 own actual service selection and DM behaviour.
_SCRIPTED_COMBAT_TEXT = "i swing my sword at the orc"


class DungeonMasterAgent(Braider):
    """Non-LLM gateway: one trusted synthetic encounter, one combat call.

    The Combat specialist owns its own Braider model invocation and produces
    the only narration. This DM simply correlates and safely projects it.
    """

    def __init__(
        self,
        *,
        runtime: ModelRuntime,
        model_targets: Mapping[ModelChoice, ModelTarget],
        combat_handler: Callable[[InternalRequest], InternalResult] | None,
        approved_encounter_id: str | None,
        model_choice: ModelChoice = ModelChoice.BALANCED,
    ) -> None:
        super().__init__(
            runtime=runtime,
            model_targets=model_targets,
            model_choice=model_choice,
            instructions="Dungeon Master gateway prototype; no DM model invocation.",
            allowed_context=frozenset(),
        )
        self._combat_handler = combat_handler
        self._approved_encounter_id = approved_encounter_id

    def __call__(self, request: InternalRequest) -> InternalResult:
        """Callable adapter for COSTA's Meta Service registry."""
        return self.handle(request)

    def handle(self, request: InternalRequest) -> InternalResult:
        """Use DES-033.1 envelopes; never interpret or resolve game mechanics."""
        if request.capability != "dm" or request.operation != "player_turn":
            return safe_failure(
                request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED,
            )
        if request.is_mutation:
            return safe_failure(
                request, ErrorCode.UNSUPPORTED_RULE, status=ResultStatus.BLOCKED,
            )

        player_text = request.payload.get("message")
        if not isinstance(player_text, str) or not player_text.strip():
            return safe_failure(
                request, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT,
            )
        # An exact, predetermined demo phrase is the only accepted action.
        # Do not parse free-form language into attacks or add DM LLM calls here.
        # BON's browser fixture uses a final period; the earlier DM test used
        # an exclamation mark. Accept only these scripted variants and forward
        # the exact original text. This is NOT general intent interpretation.
        if player_text.strip().casefold() not in (
            _SCRIPTED_COMBAT_TEXT,
            _SCRIPTED_COMBAT_TEXT + ".",
            _SCRIPTED_COMBAT_TEXT + "!",
        ):
            return safe_failure(
                request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED,
            )

        if not isinstance(self._approved_encounter_id, str) or not self._approved_encounter_id:
            return safe_failure(
                request, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT,
            )
        if (request.encounter_id is not None
                and request.encounter_id != self._approved_encounter_id):
            # A declared encounter ID cannot grant access to another fixture.
            return safe_failure(
                request, ErrorCode.UNAUTHORISED, status=ResultStatus.BLOCKED,
            )
        if not callable(self._combat_handler):
            return safe_failure(request, ErrorCode.DEPENDENCY_UNAVAILABLE)

        try:
            child = make_child_request(
                request, caller="DM", capability="combat",
                operation=MOCK_COMBAT_OPERATION,
                payload={"player_text": player_text},
                encounter_id=self._approved_encounter_id,
                knowledge_scope=None,  # A claimed scope is not specialist authority.
            )
        except ContractError:
            return safe_failure(request, ErrorCode.INTERNAL_ERROR)

        # Calls exactly once, with no automatic retries or model work in the DM.
        combat_result = safe_call(
            child, self._combat_handler,
            supported_operations=(MOCK_COMBAT_OPERATION,),
        )

        # No actual Bookkeeper exists in this stub. Reject any claimed receipt.
        if combat_result.committed_effects is not None:
            return safe_failure(request, ErrorCode.INTERNAL_ERROR)
        if combat_result.status is ResultStatus.COMPLETED and (
            combat_result.safe_summary is None
            or combat_result.data.get("simulated") is not True
            or combat_result.data.get("combat_resolved") is not False
        ):
            return safe_failure(request, ErrorCode.INTERNAL_ERROR)

        # Re-envelope against the PARENT request ID, not the child tool-call ID.
        # Only known safe flags survive; opaque specialist data is not public.
        return make_result(
            request, combat_result.status,
            safe_summary=combat_result.safe_summary,
            error_code=combat_result.error.code if combat_result.error else None,
            data=(
                {"mock": True, "simulated": True, "combat_resolved": False}
                if combat_result.status is ResultStatus.COMPLETED else {}
            ),
        )
