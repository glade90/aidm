"""Offline AIDM-DES-004.1 CombatAgent(Braider) tests.

Purpose: Verify original player text, correlation, safe fake result and no game effects.
Usage: python -m pytest aidm/combat/test/test_agent.py -q
Change Log: 2026-11-20 COSTA — first Combat stub tests.
"""

from __future__ import annotations

import pytest

from braider import ContextItem, FakeModelRuntime, ModelChoice, ModelTarget, Braider
from aidm.combat import CombatAgent, MOCK_COMBAT_OPERATION
from aidm.internal_messages import ErrorCode, ResultStatus, make_request


def make_agent(*, fail=False, response="Private proposed intent: synthetic only"):
    runtime = FakeModelRuntime(response, fail=fail)
    agent = CombatAgent(runtime=runtime,
                        model_targets={ModelChoice.BALANCED: ModelTarget("fake-provider", "synthetic")},
                        approved_encounter_context="Two synthetic actors on an imaginary stage")
    return agent, runtime


def request(*, operation=MOCK_COMBAT_OPERATION, text="I swing my sword at the orc!", **extra):
    return make_request(caller="DM", capability="combat", operation=operation,
                        request_id="req-101", correlation_id="turn-445",
                        payload={"player_text": text, **extra}, encounter_id="synthetic-encounter")


def test_is_braider_without_dm_injection():
    agent, _ = make_agent()
    assert isinstance(agent, Braider)
    assert callable(agent.handle)


def test_mock_sword_orc_retains_original_text_and_ids():
    agent, runtime = make_agent()
    out = agent.handle(request())
    assert out.status is ResultStatus.COMPLETED
    assert out.request_id == "req-101" and out.correlation_id == "turn-445"
    assert out.data["original_player_text"] == "I swing my sword at the orc!"
    assert out.data["simulated"] is True and out.data["combat_resolved"] is False
    assert out.event_refs == () and out.new_world_version is None
    assert "Simulation only" in out.safe_summary
    assert "no dice" in out.safe_summary and "no damage" in out.safe_summary
    assert "no hit points" in out.safe_summary
    assert len(runtime.calls) == 1
    assert runtime.calls[0]["input_text"] == "I swing my sword at the orc!"
    assert runtime.calls[0]["approved_context"] == {ContextItem.TASK_CONTEXT: "Two synthetic actors on an imaginary stage"}


def test_original_text_not_normalised_or_reinterpreted():
    agent, runtime = make_agent()
    text = "  I feint?  Then STOP!  "
    out = agent.handle(request(text=text))
    assert out.data["original_player_text"] == text
    assert runtime.calls[0]["input_text"] == text


def test_untrusted_request_context_cannot_override_injected_context():
    agent, runtime = make_agent()
    out = agent.handle(request(context="PRIVATE_SECRET_SHOULD_NOT_REACH_MODEL"))
    assert out.status is ResultStatus.COMPLETED
    assert "PRIVATE_SECRET" not in str(out.data)
    assert "PRIVATE_SECRET" not in str(runtime.calls)


def test_private_model_output_never_leaks_into_player_safe_result():
    secret = "PRIVATE_MODEL_PROPOSAL_DO_NOT_DISCLOSE"
    agent, _ = make_agent(response=secret)
    out = agent.handle(request())
    assert out.status is ResultStatus.COMPLETED
    assert secret not in repr(out)
    assert out.committed_effects is None


@pytest.mark.parametrize("operation", ["unknown_action", "combat_attack", "resolve_hp"])
def test_unknown_operations_blocked_without_invoking_runtime(operation):
    agent, runtime = make_agent()
    out = agent.handle(request(operation=operation))
    assert out.status is ResultStatus.BLOCKED and out.error.code is ErrorCode.UNKNOWN_CAPABILITY
    assert runtime.calls == [] and out.committed_effects is None


def test_unknown_capability_is_blocked():
    agent, runtime = make_agent()
    input_request = make_request(caller="DM", capability="other", operation=MOCK_COMBAT_OPERATION,
                                 payload={"player_text": "I swing"}, request_id="req-102", correlation_id="turn-445")
    out = agent.handle(input_request)
    assert out.status is ResultStatus.BLOCKED and runtime.calls == []


@pytest.mark.parametrize("text", ["", "   ", None, 4])
def test_missing_text_requires_player_input(text):
    agent, runtime = make_agent()
    out = agent.handle(request(text=text))
    assert out.status is ResultStatus.NEEDS_PLAYER_INPUT
    assert out.error.code is ErrorCode.INVALID_INPUT and runtime.calls == []


def test_model_exception_is_safe_and_not_retried():
    agent, runtime = make_agent(fail=True)
    out = agent.handle(request())
    assert out.status is ResultStatus.ERROR
    assert out.error.code is ErrorCode.DEPENDENCY_UNAVAILABLE
    assert len(runtime.calls) == 1
    assert "private diagnostic" not in repr(out).lower()
    assert out.event_refs == ()


def test_model_missing_alias_does_not_fake_success():
    agent, runtime = make_agent()
    agent._model_targets.clear()  # controlled fixture simulates absent injected alias
    out = agent.handle(request())
    assert out.status is ResultStatus.ERROR and out.error.code is ErrorCode.DEPENDENCY_UNAVAILABLE
    assert runtime.calls == []


def test_rejects_world_mutation_command_without_invocation():
    agent, runtime = make_agent()
    input_request = make_request(caller="DM", capability="combat", operation=MOCK_COMBAT_OPERATION,
                                 payload={"player_text": "hit"}, request_id="req-102", correlation_id="turn-445",
                                 is_mutation=True, command_id="cmd-1", expected_world_version=1)
    out = agent.handle(input_request)
    assert out.status is ResultStatus.BLOCKED
    assert out.committed_effects is None and runtime.calls == []


def test_invalid_approved_context_rejected_on_constructor():
    with pytest.raises(ValueError, match="Approved synthetic encounter context"):
        CombatAgent(runtime=FakeModelRuntime(),
                    model_targets={ModelChoice.BALANCED: ModelTarget("fake", "m")},
                    approved_encounter_context="")


def test_no_http_or_game_dependencies_imported():
    import sys
    import aidm.combat.agent as module
    assert "fastapi" not in module.__dict__
    assert "uvicorn" not in module.__dict__
    assert "crewai" not in module.__dict__

@pytest.mark.parametrize("code,expected_status,expected_error", [
    ("CONTEXT_NOT_APPROVED", ResultStatus.BLOCKED, ErrorCode.UNAUTHORISED),
    ("INVALID_INPUT", ResultStatus.NEEDS_PLAYER_INPUT, ErrorCode.INVALID_INPUT),
])
def test_generic_failure_maps_to_safe_aidm_result(monkeypatch, code, expected_status, expected_error):
    from braider import BraiderOutput, BraiderErrorCode
    agent, runtime = make_agent()
    fake_output = BraiderOutput(
        text=None, error_code=BraiderErrorCode[code],
        model_choice=ModelChoice.BALANCED, model_target=None, trace_id="turn-445",
    )
    monkeypatch.setattr(agent, "invoke", lambda *args, **kwargs: fake_output)
    out = agent.handle(request())
    assert out.status is expected_status and out.error.code is expected_error
    assert out.event_refs == () and runtime.calls == []