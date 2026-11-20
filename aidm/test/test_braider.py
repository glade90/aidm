"""Cross-project offline contract tests for programme-wide Braider.

Purpose: Exercise the shared agent without importing AIDM production modules.
Usage: python -m pytest aidm/test/test_braider.py
Change Log: 2026-11-20 COSTA — AIDM-DES-042.1 tests.
"""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

import pytest

from braider import (
    Braider, BraiderErrorCode, ContextItem, FakeModelRuntime,
    ModelChoice, ModelTarget,
)

TARGETS = {
    ModelChoice.ECONOMY: ModelTarget("fake-provider", "tiny"),
    ModelChoice.BALANCED: ModelTarget("fake-provider", "middle"),
    ModelChoice.CAPABLE: ModelTarget("alt-fake-provider", "large"),
}


class GameLikeBraider(Braider):
    def __init__(self, runtime: FakeModelRuntime, **kwargs):
        super().__init__(runtime=runtime, model_targets=TARGETS,
                         instructions="Propose an intention; no mechanics.",
                         allowed_context=frozenset({ContextItem.TASK_CONTEXT}), **kwargs)


class ResearchBraider(Braider):
    def __init__(self, runtime: FakeModelRuntime, **kwargs):
        super().__init__(runtime=runtime, model_targets=TARGETS,
                         instructions="Summarise only approved material.",
                         allowed_context=frozenset({ContextItem.REFERENCE_MATERIAL}), **kwargs)


def test_model_choice_and_context_values_are_exact():
    assert [m.value for m in ModelChoice] == ["economy", "balanced", "capable"]
    assert [m.value for m in ContextItem] == [
        "recent_conversation", "task_context", "reference_material", "working_state",
    ]


def test_default_balanced_and_one_inference():
    fake = FakeModelRuntime("A simulated suggestion")
    agent = GameLikeBraider(fake)
    out = agent.invoke("I swing at the orc", approved_context={ContextItem.TASK_CONTEXT: "training fixture"})
    assert out.succeeded and out.text == "A simulated suggestion"
    assert out.model_choice is ModelChoice.BALANCED and out.model_target == TARGETS[ModelChoice.BALANCED]
    assert len(fake.calls) == 1 and fake.calls[0]["input_text"] == "I swing at the orc"
    assert fake.calls[0]["instructions"] == "Propose an intention; no mechanics."
    assert fake.calls[0]["approved_context"] == {ContextItem.TASK_CONTEXT: "training fixture"}


@pytest.mark.parametrize("choice, model", [(ModelChoice.ECONOMY, "tiny"), (ModelChoice.CAPABLE, "large")])
def test_aliases_change_without_subclass_code(choice, model):
    fake = FakeModelRuntime("fixed")
    agent = GameLikeBraider(fake, model_choice=choice)
    out = agent.invoke("I swing", approved_context={})
    assert out.succeeded and out.model_target.model == model


def test_missing_model_alias_fails_closed():
    fake = FakeModelRuntime()
    agent = Braider(runtime=fake, model_targets={ModelChoice.ECONOMY: TARGETS[ModelChoice.ECONOMY]})
    out = agent.invoke("A task", approved_context={})
    assert out.error_code is BraiderErrorCode.MODEL_NOT_CONFIGURED
    assert out.text is None and fake.calls == []


def test_research_and_game_subclasses_share_exact_runtime_contract():
    game = FakeModelRuntime("Game proposal")
    research = FakeModelRuntime("Research summary")
    a = GameLikeBraider(game).invoke("I swing", approved_context={ContextItem.TASK_CONTEXT: "neutral"})
    b = ResearchBraider(research).invoke("Summarise", approved_context={ContextItem.REFERENCE_MATERIAL: "approved extract"})
    assert (a.text, b.text) == ("Game proposal", "Research summary")
    assert len(game.calls) == len(research.calls) == 1


def test_forbidden_context_never_reaches_model_or_response():
    private_note = "PRIVATE_SECRET_NOTE_DO_NOT_LEAK"
    fake = FakeModelRuntime()
    result = ResearchBraider(fake).invoke("Summarise", approved_context={ContextItem.WORKING_STATE: private_note})
    assert result.error_code is BraiderErrorCode.CONTEXT_NOT_APPROVED
    assert result.text is None and fake.calls == []
    assert private_note not in repr(result)


def test_invalid_category_cannot_be_used_to_grant_permission():
    fake = FakeModelRuntime()
    result = ResearchBraider(fake).invoke("Summarise", approved_context={"reference_material": "mislabelled"})  # type: ignore[dict-item]
    assert result.error_code is BraiderErrorCode.INVALID_INPUT
    assert fake.calls == []


def test_trace_passes_without_project_dependency():
    fake = FakeModelRuntime("text")
    out = ResearchBraider(fake).invoke("Question", approved_context={}, trace_id="trace-927")
    assert out.trace_id == "trace-927" and out.succeeded


def test_invalid_trace_is_rejected_before_call():
    fake = FakeModelRuntime()
    out = ResearchBraider(fake).invoke("Question", approved_context={}, trace_id="")
    assert out.error_code is BraiderErrorCode.INVALID_INPUT and fake.calls == []


def test_runtime_exception_redacts_error_and_does_not_retry():
    fake = FakeModelRuntime(fail=True)
    out = ResearchBraider(fake).invoke("Question", approved_context={}, trace_id="trace-fail")
    assert out.error_code is BraiderErrorCode.MODEL_ERROR
    assert out.text is None and out.trace_id == "trace-fail"
    assert len(fake.calls) == 1
    assert "private diagnostic" not in repr(out).lower()


@pytest.mark.parametrize("answer", ["", "  ", None, 42])
def test_runtime_bad_result_is_never_success(answer):
    fake = FakeModelRuntime(answer)  # type: ignore[arg-type]
    out = ResearchBraider(fake).invoke("Question", approved_context={})
    assert not out.succeeded and out.error_code is BraiderErrorCode.MODEL_ERROR
    assert len(fake.calls) == 1


@pytest.mark.parametrize("message", ["", "   ", None, 5])
def test_invalid_text_does_not_invoke_model(message):
    fake = FakeModelRuntime()
    out = ResearchBraider(fake).invoke(message, approved_context={})  # type: ignore[arg-type]
    assert out.error_code is BraiderErrorCode.INVALID_INPUT and fake.calls == []


def test_context_data_must_be_text_and_approved():
    fake = FakeModelRuntime()
    out = ResearchBraider(fake).invoke("Question", approved_context={ContextItem.REFERENCE_MATERIAL: 4})  # type: ignore[dict-item]
    assert out.error_code is BraiderErrorCode.INVALID_INPUT and fake.calls == []


def test_bad_context_mapping_is_safe():
    fake = FakeModelRuntime()
    out = ResearchBraider(fake).invoke("Question", approved_context=None)  # type: ignore[arg-type]
    assert out.error_code is BraiderErrorCode.INVALID_INPUT and fake.calls == []


def test_bad_model_constructor_fails_without_secret_values():
    with pytest.raises(ValueError, match="Provider and model names"):
        ModelTarget("", "safe")
    with pytest.raises(ValueError, match="Invalid model mapping"):
        Braider(runtime=FakeModelRuntime(), model_targets={"balanced": "bad"})  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="Invalid allowed context"):
        Braider(runtime=FakeModelRuntime(), model_targets=TARGETS, allowed_context=frozenset({"task_context"}))  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="Invalid instructions"):
        Braider(runtime=FakeModelRuntime(), model_targets=TARGETS, instructions=None)  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="Invalid model choice"):
        Braider(runtime=FakeModelRuntime(), model_targets=TARGETS, model_choice="balanced")  # type: ignore[arg-type]


def test_package_import_is_isolated_and_side_effect_free(tmp_path):
    root = Path(__file__).resolve().parents[2]
    script = """import sys
initial = set(sys.modules)
import braider
new_modules = set(sys.modules) - initial
assert not any(x == name or x.startswith(name + '.')
               for name in ('aidm', 'fastapi', 'crewai', 'requests', 'openai', 'boto3')
               for x in new_modules)
print(braider.Braider.__name__)
"""
    env = dict(os.environ, PYTHONPATH=str(root))
    p = subprocess.run([sys.executable, "-c", script], cwd=tmp_path, env=env,
                       check=False, capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    assert p.stdout.strip() == "Braider"