"""AIDM-DES-004.2.1 — integrated narration regression with scripted model.

Source repo tests, not evidence of genuine provider access or BON UAT.
"""
from __future__ import annotations

import json

from fastapi.testclient import TestClient

from aidm.combat.test.test_round_agent import fake_agent
from aidm.combat.test.test_combat_session import make_app, start, act, log, WIN_FACES


def test_structured_narration_in_browser_is_unwrapped_once_and_journal_preserved():
    specialist, runtime = fake_agent(
        '{"narration":"Round one ends. The party regroups."}')
    app, service, sources = make_app(faces=WIN_FACES, policy=specialist)
    with TestClient(app) as client:
        initial = start(client)["combat"]
        first = act(client, initial, "HOLD", action_id="json-first")
        assert len(runtime.calls) == 0  # not a completed verified round
        second = act(client, first["combat"], "HOLD", action_id="json-second")
        assert len(runtime.calls) == 1
        assert 'Narrative (non-authoritative): Round one ends.' in second["message"]
        assert '{"narration"' not in second["message"]
        assert any(e["kind"] == "ROUND_COMPLETED"
                   for e in second["combat"]["new_log_entries"])
        last = log(client, second["combat"])
        assert len(runtime.calls) == 1  # VIEW_LOG never prompts model
        assert last["combat"]["terminal"] is False


def test_malformed_structured_narration_does_not_replace_verified_round_journal():
    specialist, runtime = fake_agent('{"narration":"Round one is unfinished"')
    app, service, sources = make_app(faces=WIN_FACES, policy=specialist)
    with TestClient(app) as client:
        initial = start(client)["combat"]
        first = act(client, initial, "HOLD", action_id="fallback-first")
        second = act(client, first["combat"], "HOLD", action_id="fallback-second")
        assert len(runtime.calls) == 1
        assert 'Narrative (non-authoritative)' not in second["message"]
        assert '"narration"' not in second["message"]
        assert any(e["kind"] == "ROUND_COMPLETED"
                   for e in second["combat"]["new_log_entries"])


def test_terminal_verified_event_narration_is_clean_prose_not_json():
    agent, runtime = fake_agent('{"narration":"The party has prevailed."}')
    result = agent.narrate(verified_events=("Combat ends: PARTY_VICTORY",))
    assert result == "The party has prevailed."
    task = json.loads(runtime.calls[0][0])
    assert task == {"task":"NARRATE", "verified_public_events":["Combat ends: PARTY_VICTORY"]}
    assert len(runtime.calls) == 1  # no second DM rewriting call


def test_terminal_plain_prose_compatibility():
    agent, runtime = fake_agent("The party wins the battle.")
    assert agent.narrate(verified_events=("Combat ends: PARTY_VICTORY",)) == "The party wins the battle."
    assert len(runtime.calls) == 1
