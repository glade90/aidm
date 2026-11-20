"""Deterministic AIDM-DES-015.2 DM gateway tests.

Purpose: Protect typed pass-through, genuine Combat stub integration and safe errors.
Usage: python -m pytest aidm/dm/test/test_dm_agent.py -q
Change Log: 2026-11-20 DAVOS — first non-LLM DungeonMasterAgent regression.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from braider import Braider, FakeModelRuntime, ModelChoice, ModelTarget
from aidm.combat import CombatAgent, MOCK_COMBAT_OPERATION
from aidm.config import load_config
from aidm.dm import DungeonMasterAgent
from aidm.internal_messages import (
    CommittedEffects, ErrorCode, InternalResult, ResultStatus, make_request,
    make_result, safe_failure,
)
from aidm.meta.http import create_app
from aidm.meta.runtime import ServiceRegistry

WORDS = "I swing my sword at the orc!"
SUMMARY = "Simulation only: a specialist accepted the synthetic intention; no effects."


def targets():
    return {ModelChoice.BALANCED: ModelTarget("offline-fake", "synthetic")}


def turn(text=WORDS, *, correlation="turn-42", session="session-1", **changes):
    config = dict(
        caller="Meta", capability="dm", operation="player_turn",
        payload={"message": text}, request_id="parent-1",
        correlation_id=correlation, session_id=session,
    )
    config.update(changes)
    return make_request(**config)


class RecordingCombat:
    def __init__(self, *, status=ResultStatus.COMPLETED,
                 error_code=None, safe_summary=SUMMARY):
        self.calls = []
        self.status = status
        self.error_code = error_code
        self.safe_summary = safe_summary

    def __call__(self, request):
        self.calls.append(request)
        return make_result(
            request, self.status, safe_summary=self.safe_summary,
            error_code=self.error_code,
            data={"simulated": True, "combat_resolved": False,
                  "private_model_proposal": "DO_NOT_LEAK"},
        )


def gateway(handler=None, *, encounter="synthetic-encounter"):
    runtime = FakeModelRuntime("DM PRIVATE MODEL MUST NOT RUN")
    combat = handler if handler is not None else RecordingCombat()
    dm = DungeonMasterAgent(
        runtime=runtime, model_targets=targets(),
        combat_handler=combat, approved_encounter_id=encounter,
    )
    return dm, runtime, combat


def test_is_braider_and_is_callable_without_dm_inference():
    dm, runtime, combat = gateway()
    assert isinstance(dm, Braider)
    result = dm(turn())
    assert result.status is ResultStatus.COMPLETED
    assert len(combat.calls) == 1 and runtime.calls == []


def test_forwards_original_words_and_shared_message_correlation():
    dm, runtime, combat = gateway()
    raw = "  I swing my sword at the orc!  "
    parent = turn(raw, encounter_id="synthetic-encounter",
                  knowledge_scope="untrusted_scope")
    returned = dm.handle(parent)
    child = combat.calls[0]
    assert child.payload["player_text"] == raw  # original bytes, not normalized
    assert child.capability == "combat" and child.operation == MOCK_COMBAT_OPERATION
    assert child.caller == "DM"
    assert child.parent_request_id == parent.request_id
    assert child.request_id != parent.request_id
    assert child.correlation_id == parent.correlation_id
    assert child.session_id == parent.session_id
    assert child.encounter_id == "synthetic-encounter"
    assert child.knowledge_scope is None
    assert returned.request_id == parent.request_id
    assert returned.correlation_id == parent.correlation_id
    assert runtime.calls == []


def test_preserves_specialist_status_and_exact_approved_narrative():
    dm, _, _ = gateway()
    response = dm.handle(turn())
    assert response.status is ResultStatus.COMPLETED
    assert response.safe_summary == SUMMARY  # never paraphrased or re-narrated
    assert response.data == {"mock": True, "simulated": True, "combat_resolved": False}
    assert response.committed_effects is None
    assert response.event_refs == ()
    assert response.new_world_version is None
    assert "DO_NOT_LEAK" not in str(response)


def test_actual_combat_agent_stub_uses_only_its_own_fake_model():
    combat_runtime = FakeModelRuntime("SECRET untrusted model proposal")
    combat = CombatAgent(
        runtime=combat_runtime, model_targets=targets(),
        approved_encounter_context="An approved synthetic two-actor encounter",
    )
    dm_runtime = FakeModelRuntime()
    dm = DungeonMasterAgent(
        runtime=dm_runtime, model_targets=targets(),
        combat_handler=combat.handle, approved_encounter_id="fixture-1",
    )
    response = dm.handle(turn())
    assert response.status is ResultStatus.COMPLETED
    assert response.safe_summary == (
        "Simulation only: the combat intention was received; "
        "no dice were rolled, no damage was calculated, "
        "and no hit points or world state were changed."
    )
    assert len(combat_runtime.calls) == 1
    assert combat_runtime.calls[0]["input_text"] == WORDS
    assert dm_runtime.calls == []
    assert response.data == {"mock": True, "simulated": True, "combat_resolved": False}
    assert "SECRET" not in repr(response)


@pytest.mark.parametrize("message", ["", "   ", None, 19])
def test_invalid_or_missing_player_text_asks_for_clarification(message):
    dm, runtime, combat = gateway()
    result = dm.handle(turn(message))
    assert result.status is ResultStatus.NEEDS_PLAYER_INPUT
    assert result.error.code is ErrorCode.INVALID_INPUT
    assert not combat.calls and not runtime.calls


@pytest.mark.parametrize("message", [
    "I examine the wall",
    "I swing at the unknown dragon",
    "I swing my sword at the orc then drink a potion",
    "How much HP did the orc lose?",
])
def test_noncombat_or_unscripted_action_is_blocked_without_guessing(message):
    dm, runtime, combat = gateway()
    result = dm.handle(turn(message))
    assert result.status is ResultStatus.BLOCKED
    assert result.error.code is ErrorCode.UNKNOWN_CAPABILITY
    assert result.event_refs == ()
    assert not combat.calls and not runtime.calls


@pytest.mark.parametrize("changes,code", [
    ({"operation": "unknown_operation"}, ErrorCode.UNKNOWN_CAPABILITY),
    ({"capability": "bookkeeper"}, ErrorCode.UNKNOWN_CAPABILITY),
    ({"is_mutation": True, "command_id": "cmd-1", "expected_world_version": 0},
     ErrorCode.UNSUPPORTED_RULE),
])
def test_wrong_operations_and_mutation_are_blocked(changes, code):
    dm, _, combat = gateway()
    result = dm.handle(turn(**changes))
    assert result.status is ResultStatus.BLOCKED
    assert result.error.code is code
    assert combat.calls == []


@pytest.mark.parametrize("encounter", [None, "", 33])
def test_missing_encounter_asks_for_input_and_never_calls_combat(encounter):
    dm, _, combat = gateway(encounter=encounter)
    result = dm.handle(turn())
    assert result.status is ResultStatus.NEEDS_PLAYER_INPUT
    assert result.error.code is ErrorCode.INVALID_INPUT
    assert combat.calls == []


def test_unapproved_encounter_id_cannot_override_injected_fixture():
    dm, _, combat = gateway()
    result = dm.handle(turn(encounter_id="different-encounter"))
    assert result.status is ResultStatus.BLOCKED
    assert result.error.code is ErrorCode.UNAUTHORISED
    assert combat.calls == []


def test_bad_injected_encounter_identifier_fails_safely():
    dm, _, combat = gateway(encounter="contains spaces")
    result = dm.handle(turn())
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR
    assert combat.calls == []


def test_missing_handler_is_explicit_unavailable_not_success():
    dm = DungeonMasterAgent(
        runtime=FakeModelRuntime(), model_targets=targets(),
        combat_handler=None, approved_encounter_id="fixture-1",
    )
    result = dm.handle(turn())
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.DEPENDENCY_UNAVAILABLE
    assert result.committed_effects is None


def test_combat_exception_is_sanitised_with_no_retry():
    calls = []

    def broken(request):
        calls.append(request)
        raise RuntimeError("PRIVATE_API_KEY_NEVER_SHOW")

    dm, runtime, _ = gateway(broken)
    result = dm.handle(turn(correlation="turn-error"))
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR
    assert result.correlation_id == "turn-error"
    assert len(calls) == 1 and runtime.calls == []
    assert "PRIVATE_API_KEY" not in repr(result)


def test_mismatched_child_result_id_fails_safely():
    def mismatched(request):
        other = make_request(caller="DM", capability="combat",
                             operation=MOCK_COMBAT_OPERATION,
                             payload={}, correlation_id=request.correlation_id)
        return make_result(other, ResultStatus.COMPLETED, safe_summary=SUMMARY,
                           data={"simulated": True, "combat_resolved": False})

    dm, _, _ = gateway(mismatched)
    result = dm.handle(turn())
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR


@pytest.mark.parametrize("status,error_code", [
    (ResultStatus.NEEDS_PLAYER_INPUT, ErrorCode.INVALID_INPUT),
    (ResultStatus.BLOCKED, ErrorCode.UNKNOWN_CAPABILITY),
    (ResultStatus.NEEDS_RULING, ErrorCode.UNSUPPORTED_RULE),
    (ResultStatus.ERROR, ErrorCode.DEPENDENCY_UNAVAILABLE),
])
def test_specialist_non_success_status_and_safe_error_are_preserved(status, error_code):
    combat = RecordingCombat(status=status, error_code=error_code, safe_summary=None)
    dm, _, _ = gateway(combat)
    parent = turn(correlation="corr-2")
    result = dm.handle(parent)
    assert result.status is status
    assert result.error.code is error_code
    assert result.safe_summary is None
    assert result.request_id == parent.request_id
    assert result.correlation_id == parent.correlation_id
    assert result.committed_effects is None


def test_specialist_handoff_is_not_reported_as_complete():
    combat = RecordingCombat(status=ResultStatus.HANDOFF,
                             safe_summary="Passed to another specialist; not finished.")
    dm, _, _ = gateway(combat)
    result = dm.handle(turn())
    assert result.status is ResultStatus.HANDOFF
    assert result.safe_summary == "Passed to another specialist; not finished."
    assert result.data == {} and result.committed_effects is None


@pytest.mark.parametrize("summary,flags", [
    (None, {"simulated": True, "combat_resolved": False}),
    (SUMMARY, {"simulated": False, "combat_resolved": False}),
    (SUMMARY, {"simulated": True, "combat_resolved": True}),
    (SUMMARY, {"simulated": True}),
])
def test_completed_result_cannot_falsely_claim_combat_executed(summary, flags):
    def suspicious(request):
        return make_result(request, ResultStatus.COMPLETED,
                           safe_summary=summary, data=flags)
    dm, _, _ = gateway(suspicious)
    result = dm.handle(turn())
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR


def test_fabricated_commit_receipt_is_not_forwarded():
    def suspicious(request):
        return InternalResult(
            request_id=request.request_id, correlation_id=request.correlation_id,
            status=ResultStatus.COMPLETED, safe_summary=SUMMARY,
            data={"simulated": True, "combat_resolved": False},
            committed_effects=CommittedEffects(
                command_id="cmd-unsafe", event_refs=("fake-event",), new_world_version=5,
            ),
        )
    dm, _, _ = gateway(suspicious)
    result = dm.handle(turn())
    assert result.status is ResultStatus.ERROR
    assert result.error.code is ErrorCode.INTERNAL_ERROR
    assert result.committed_effects is None


def test_two_sequential_turns_have_separate_ids_and_no_extra_calls():
    dm, runtime, combat = gateway()
    first = turn(correlation="correlation-1", session="session-1")
    second = turn(correlation="correlation-2", session="session-2",
                  request_id="parent-2")
    first_result = dm.handle(first)
    second_result = dm.handle(second)
    assert first_result.request_id == "parent-1"
    assert second_result.request_id == "parent-2"
    assert first_result.correlation_id == "correlation-1"
    assert second_result.correlation_id == "correlation-2"
    assert len(combat.calls) == 2
    assert combat.calls[0].request_id != combat.calls[1].request_id
    assert [c.session_id for c in combat.calls] == ["session-1", "session-2"]
    assert [c.correlation_id for c in combat.calls] == ["correlation-1", "correlation-2"]
    assert runtime.calls == []


class FakeLogger:
    def start(self, settings): pass
    def info(self, message): pass
    def error(self, message): pass
    def close(self): pass


def test_actual_fastapi_route_uses_injected_dm_without_other_endpoint():
    combat_runtime = FakeModelRuntime()
    combat = CombatAgent(runtime=combat_runtime, model_targets=targets(),
                         approved_encounter_context="Synthetic test arena")
    dm_runtime = FakeModelRuntime()
    dm = DungeonMasterAgent(
        runtime=dm_runtime, model_targets=targets(),
        combat_handler=combat.handle, approved_encounter_id="fixture-1",
    )
    registry = ServiceRegistry(required=("dm",))
    registry.register("dm", dm)
    registry.register("combat", combat.handle)
    settings = load_config(
        environ={"AIDM_MODE": "test"}, dotenv_path="/definitely/nonexistent/.env",
    )
    app = create_app(settings=settings, registry=registry, logger=FakeLogger())
    with TestClient(app) as client:
        response = client.post("/api/turn", json={
            "message": WORDS, "session_id": "session-http",
            "correlation_id": "turn-http",
        })
        body = response.json()
        assert response.status_code == 200
        assert body["status"] == "COMPLETED"
        assert body["correlation_id"] == "turn-http"
        assert body["session_id"] == "session-http"
        assert body["simulated"] is True and body["tool_outcome"] == {"mock": True}
        assert "no dice were rolled" in body["message"]
        assert len(combat_runtime.calls) == 1 and dm_runtime.calls == []
        assert client.post("/api/turn", json={"message": "I inspect the room"}).json()["status"] == "BLOCKED"
        assert client.get("/health").json() == {"state": "READY", "ready": True}
        assert client.get("/status").json()["capabilities"] == ["combat", "dm"]
