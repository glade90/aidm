"""AIDM-DES-025.2 — source-matched HTTP/DM/real CombatEngine tests.

Purpose: Human 3v3 multi-round interface, deterministic physical dice,
         error/idempotency/log/session isolation and fake LLM proof.
Usage: python -m pytest aidm/combat/test/test_combat_session.py -q
Change Log: 2026-11-20 DAVOS — first real human combat integration tests.
"""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from aidm.combat.dice import FixedRollSource
from aidm.combat.live_policy import OpenAIResponsesPolicy
from aidm.combat.rules_reference import RuleProfile
from aidm.combat.session import CombatSessionService, ScriptedIntentPolicy
from aidm.config import load_config
from aidm.web import create_chat_app


class FakeLogger:
    def start(self, settings): pass
    def info(self, message): pass
    def error(self, message): pass
    def close(self): pass


# Round 1: party 6-2, Alho holds, Evro d20=12/d8=5 kills orc-01,
# two orcs miss with d20=1. Round 2: party 6-2,
# Alho d20=17/flail d6=4 kills orc-02,
# Evro d20=12/d8=3 kills orc-03. Exactly two actual rounds.
WIN_FACES = (6, 2, 12, 5, 1, 1, 6, 2, 17, 4, 12, 3)


def make_app(*, faces=WIN_FACES, policy=None, rule_profile=None):
    sources = []

    def dice_source():
        result = FixedRollSource(faces)
        sources.append(result)
        return result

    service = CombatSessionService(
        roll_source_factory=dice_source, intent_policy=policy,
        rule_profile_factory=(lambda: rule_profile) if rule_profile is not None else None,
    )
    settings = load_config(
        environ={"AIDM_MODE": "test", "AIDM_REQUEST_TIMEOUT_SECONDS": "10"},
        dotenv_path="/definitely/nonexistent/.env",
    )
    return create_chat_app(
        settings=settings, logger=FakeLogger(),
        combat_session_handler=service,
    ), service, sources


def start(client, session="s1"):
    response = client.post("/api/turn", json={
        "session_id": session, "correlation_id": f"start-{session}",
        "combat": {"kind": "START"},
    })
    assert response.status_code == 200, response.text
    return response.json()


def act(client, view, statement, *, action_id, session="s1",
        actor=None, token=None, version=None, encounter=None):
    decision = view["next_decision"]
    assert decision, "Expected a pending human decision"
    response = client.post("/api/turn", json={
        "message": statement, "session_id": session,
        "correlation_id": f"corr-{action_id}",
        "combat": {
            "kind": "ACTION",
            "encounter_id": view["encounter_id"] if encounter is None else encounter,
            "actor_id": decision["actor_id"] if actor is None else actor,
            "decision_token": decision["decision_token"] if token is None else token,
            "expected_encounter_version": view["state_version"] if version is None else version,
            "client_action_id": action_id,
            "log_since_sequence": view["log_next_cursor"],
        },
    })
    return response.json()


def log(client, view, *, session="s1", since=0):
    r = client.post("/api/turn", json={
        "session_id": session, "combat": {
            "kind": "VIEW_LOG", "encounter_id": view["encounter_id"],
            "log_since_sequence": since,
        },
    })
    return r.json()


def test_real_start_only_path_preserves_meta_contract_and_human_prompt():
    app, service, sources = make_app()
    with TestClient(app) as client:
        started = start(client)
        assert started["status"] == "NEEDS_PLAYER_INPUT"
        assert started["simulated"] is False and started["tool_outcome"] is None
        assert started["session_id"] == "s1"
        v = started["combat"]
        assert v["state_version"] == 0 and v["current_round"] == 1
        assert v["awaiting_player"] and not v["terminal"] and v["outcome"] is None
        assert v["next_decision"]["actor_id"] == "alho"
        assert {"orc-01", "orc-02", "orc-03"} == set(v["next_decision"]["allowed_targets"])
        assert "Alho" in v["next_decision"]["prompt"]
        assert "enc-" in v["encounter_id"]
        assert sources[0].cursor == 2  # raw initiative faces only
        assert any(x["kind"] == "SIDE_INITIATIVE" for x in v["new_log_entries"])
        assert client.get("/status").json()["capabilities"] == ["combat", "combat_session", "dm"]
        assert client.get("/chat").status_code == 200
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 6


def test_two_real_rounds_roll_math_human_handoff_and_terminal_in_browser_api():
    app, service, sources = make_app()
    with TestClient(app) as client:
        first = start(client)
        a1 = act(client, first["combat"], "HOLD", action_id="action-1")
        assert a1["status"] == "NEEDS_PLAYER_INPUT"
        v1 = a1["combat"]
        assert v1["next_decision"]["actor_id"] == "sho-rembo"
        # Evro is AGENT: no browser prompt, but his actual attack was resolved.
        evro = [e for e in v1["new_log_entries"] if e["kind"] == "MELEE_RESOLVED"]
        assert len(evro) == 1
        roll = evro[0]["roll"]
        assert roll["attack_face"] == 12
        assert roll["attack_modifier"] == 3 and roll["attack_total"] == 15
        assert roll["damage_face"] == 5
        assert roll["damage_modifier"] == 3 and roll["damage_total"] == 8
        assert roll["attack_die_id"].startswith("fixture-evro")
        assert roll["damage_die_id"].startswith("fixture-evro")
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 0

        a2 = act(client, v1, "Sho holds position", action_id="action-2")
        # That phrase is deliberately unsupported: parser must not guess a HOLD.
        assert a2["status"] == "NEEDS_PLAYER_INPUT"
        assert a2["combat"]["state_version"] == v1["state_version"]
        a2 = act(client, v1, "HOLD", action_id="action-2-fixed")
        v2 = a2["combat"]
        assert a2["status"] == "NEEDS_PLAYER_INPUT"
        assert v2["current_round"] == 2 and v2["next_decision"]["actor_id"] == "alho"
        assert a2["session_id"] == "s1"
        assert a1["correlation_id"] != a2["correlation_id"]
        assert len([e for e in service._sessions["s1"].engine.journal()
                    if e.kind == "SIDE_INITIATIVE"]) == 2
        assert sources[0].cursor == 8

        done = act(client, v2, "Alho attacks Orc 2 with his flail", action_id="action-3")
        assert done["status"] == "COMPLETED"
        final = done["combat"]
        assert final["terminal"] and final["outcome"] == "PARTY_VICTORY"
        assert final["current_round"] == 2 and not final["awaiting_player"]
        assert final["next_decision"] is None
        assert {p["actor_id"] for p in final["surviving_party_summary"]} == {
            "alho", "evro", "sho-rembo",
        }
        assert all(p["hp_current"] >= 0 for p in final["surviving_party_summary"])
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-02"] == 0
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-03"] == 0
        assert sources[0].cursor == len(WIN_FACES)
        assert len([e for e in service._sessions["s1"].engine.journal()
                    if e.kind == "ENCOUNTER_TERMINAL"]) == 1

        whole = log(client, final)
        logs = whole["combat"]["new_log_entries"]
        assert whole["status"] == "COMPLETED"
        assert [e["seq"] for e in logs] == sorted(set(e["seq"] for e in logs))
        assert any(e["kind"] == "ROUND_STARTED" and e["round"] == 1 for e in logs)
        assert any(e["kind"] == "ROUND_STARTED" and e["round"] == 2 for e in logs)
        assert any(e["kind"] == "ENCOUNTER_TERMINAL" for e in logs)
        assert any(e["phase"] == "MISSILE" and "SCENARIO_RULE_DISABLED" in e["text"]
                   for e in logs)
        text = json.dumps(whole)
        for private in ("defender_ac", "hp_before", "hp_after", "hidden_traits",
                        "source_event_id", "private_model_proposal", "rules_profile_ref"):
            assert private not in text
        assert sources[0].cursor == len(WIN_FACES)  # VIEW_LOG read only

        rejected = client.post("/api/turn", json={
            "session_id": "s1", "message": "attack orc-03",
            "combat": {"kind": "ACTION", "encounter_id": final["encounter_id"],
                       "actor_id": "alho", "decision_token": v2["next_decision"]["decision_token"],
                       "expected_encounter_version": v2["state_version"],
                       "client_action_id": "action-after-terminal"},
        }).json()
        assert rejected["status"] == "BLOCKED"
        assert sources[0].cursor == len(WIN_FACES)


def test_bad_actor_target_token_and_duplicate_action_never_roll():
    app, service, sources = make_app()
    with TestClient(app) as client:
        base = start(client)["combat"]
        init_cursor = sources[0].cursor
        foreign = act(client, base, "HOLD", action_id="wrong-actor", actor="evro")
        assert foreign["status"] == "BLOCKED"
        stale = act(client, base, "HOLD", action_id="wrong-version", version=999)
        assert stale["status"] == "BLOCKED"
        token = act(client, base, "HOLD", action_id="wrong-token", token="bogus")
        assert token["status"] == "BLOCKED"
        invalid_target = act(client, base, "attack orc 99", action_id="unknown-target")
        assert invalid_target["status"] == "NEEDS_PLAYER_INPUT"
        assert sources[0].cursor == init_cursor
        assert service._sessions["s1"].engine.version == 0

        good = act(client, base, "HOLD", action_id="unique-hold")
        cursor_after = sources[0].cursor
        replay = act(client, base, "HOLD", action_id="unique-hold")
        assert replay["status"] == "BLOCKED"
        assert replay["error"]["code"] == "STATE_VERSION_CONFLICT"
        assert service._sessions["s1"].engine.version == good["combat"]["state_version"]
        assert sources[0].cursor == cursor_after


def test_log_since_cursor_does_not_consume_rng_or_mutate_history():
    app, service, sources = make_app()
    with TestClient(app) as client:
        base = start(client)["combat"]
        prior = service._sessions["s1"].engine.snapshot()
        count = len(service._sessions["s1"].engine.journal())
        first_cursor = base["log_next_cursor"]
        first = log(client, base, since=first_cursor)
        assert first["combat"]["new_log_entries"] == []
        assert first["combat"]["log_next_cursor"] == first_cursor
        whole = log(client, base, since=0)
        assert whole["combat"]["new_log_entries"]
        assert sources[0].cursor == 2
        assert service._sessions["s1"].engine.snapshot() == prior
        assert len(service._sessions["s1"].engine.journal()) == count


def test_separate_browser_sessions_and_wrong_encounter_cannot_mutate():
    app, service, sources = make_app()
    with TestClient(app) as client:
        a, b = start(client, "player-a"), start(client, "player-b")
        av, bv = a["combat"], b["combat"]
        assert av["encounter_id"] != bv["encounter_id"]
        assert av["next_decision"]["decision_token"] != bv["next_decision"]["decision_token"]
        bad = client.post("/api/turn", json={
            "session_id": "player-b",
            "combat": {"kind": "VIEW_LOG", "encounter_id": av["encounter_id"]},
        }).json()
        assert bad["status"] == "BLOCKED"
        assert bad["error"]["code"] == "UNAUTHORISED"
        assert bad["combat"] is None
        act(client, av, "HOLD", action_id="player-a-action", session="player-a")
        assert service._sessions["player-b"].engine.version == 0
        assert service._sessions["player-b"].engine.snapshot()["hp"]["orc-01"] == 6
        assert sources[1].cursor == 2


def test_missing_flail_overlay_requires_ruling_without_roll():
    app, service, sources = make_app(
        rule_profile=RuleProfile(fixture_loadout_confirmed=True),
    )
    with TestClient(app) as client:
        initial = start(client)["combat"]
        result = act(client, initial, "Alho attacks Orc 1 with flail",
                     action_id="unapproved-flail")
        assert result["status"] == "NEEDS_RULING"
        assert result["error"]["code"] == "UNSUPPORTED_RULE"
        assert result["combat"]["state_version"] == 0
        assert result["combat"]["next_decision"]["actor_id"] == "alho"
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 6
        assert sources[0].cursor == 2


def test_due_morale_blocks_truthfully_when_unimplemented():
    app, service, sources = make_app(rule_profile=RuleProfile(
        house_rule_overlays=("HR-WEAPON-FLAIL-001",),
        fixture_loadout_confirmed=True, morale_enabled=True,
    ))
    with TestClient(app) as client:
        initial = start(client)["combat"]
        after = act(client, initial, "HOLD", action_id="morale-due")
        assert after["status"] == "NEEDS_RULING"
        assert after["error"]["code"] == "UNSUPPORTED_RULE"
        events = service._sessions["s1"].engine.journal()
        assert any(e.kind == "MORALE_TRIGGER" and
                   e.details.get("status") == "BLOCKED_UNIMPLEMENTED" for e in events)
        assert sources[0].cursor == 4  # No secret 2d6 morale invented.


def test_unsupported_nonattack_action_is_explicit_ruling():
    app, service, sources = make_app()
    with TestClient(app) as client:
        initial = start(client)["combat"]
        for text in ("I switch weapons", "I cast a spell", "I shoot my bow"):
            result = act(client, initial, text, action_id="try-" + str(len(text)))
            assert result["status"] == "NEEDS_RULING"
            assert result["error"]["code"] == "UNSUPPORTED_RULE"
        assert sources[0].cursor == 2
        assert service._sessions["s1"].engine.version == 0


def test_full_two_round_fake_llm_interprets_humans_and_narrates_without_rules_power():
    class FakeLlm:
        def __init__(self):
            self.inputs = []
            self.narrated = []

        def propose(self, *, player_text, actor_id, allowed_targets):
            self.inputs.append((actor_id, player_text, allowed_targets))
            if any(phrase in player_text.lower() for phrase in ("stand ready", "stands ready", "shield up")):
                return "HOLD", None
            if actor_id == "alho" and "second orc" in player_text.lower():
                return "ATTACK_MELEE", "orc-02"
            return "NEEDS_CLARIFICATION", None

        def narrate(self, *, verified_events):
            self.narrated.append(verified_events)
            return "The steel rings against steel."

    policy = FakeLlm()
    app, service, sources = make_app(policy=policy)
    with TestClient(app) as client:
        v0 = start(client)["combat"]
        v1 = act(client, v0, "Alho stands ready", action_id="model1")["combat"]
        assert v1["next_decision"]["actor_id"] == "sho-rembo"
        v2 = act(client, v1, "Sho keeps his shield up", action_id="model2")["combat"]
        assert v2["current_round"] == 2
        final = act(client, v2, "Alho strikes the second orc!", action_id="model3")
        assert final["status"] == "COMPLETED"
        assert final["combat"]["terminal"]
        assert final["combat"]["outcome"] == "PARTY_VICTORY"
        assert [x[0] for x in policy.inputs] == ["alho", "sho-rembo", "alho"]
        assert len(policy.narrated) >= 3
        assert "Narrative (non-authoritative)" in final["message"]
        assert sources[0].cursor == len(WIN_FACES)
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-03"] == 0


def test_original_message_only_stub_remains_unchanged():
    app, _, _ = make_app()
    with TestClient(app) as client:
        normal = client.post("/api/turn", json={
            "message": "I swing my sword at the orc.",
            "session_id": "s1",
        }).json()
        assert normal["status"] == "COMPLETED"
        assert normal["simulated"] and normal["combat"] is None
        assert "no dice were rolled" in normal["message"]


@pytest.mark.parametrize("bad", [
    {"combat": {"kind": "ACTION"}, "message": "HOLD", "session_id": "s"},
    {"combat": {"kind": "VIEW_LOG", "encounter_id": "bad token !"}, "session_id": "s"},
    {"combat": {"kind": "START", "other": "untrusted"}, "session_id": "s"},
    {"combat": {"kind": "START"}, "session_id": "bad\nid"},
    {"combat": {"kind": "START"}, "caller": "Bookkeeper", "session_id": "s"},
])
def test_combat_http_validates_and_rejects_untrusted_fields(bad):
    app, _, _ = make_app()
    with TestClient(app) as client:
        res = client.post("/api/turn", json=bad)
        assert res.status_code == 422
        assert res.json()["status"] == "NEEDS_PLAYER_INPUT"
        assert "traceback" not in res.text.lower()


def test_opt_in_llm_adapter_is_untrusted_and_never_changes_dice_math():
    requests = []
    fake_answers = [
        json.dumps({"kind": "HOLD", "target_id": None}),
        "A careful hush settles over the battlefield.",
    ]

    def fake_post(body, key, timeout):
        assert key == "TEST_ONLY_NOT_A_REAL_KEY"
        requests.append(json.loads(body))
        return {"output": [{
            "type": "message",
            "content": [{"type": "output_text", "text": fake_answers.pop(0)}],
        }]}

    policy = OpenAIResponsesPolicy(
        api_key="TEST_ONLY_NOT_A_REAL_KEY", model="synthetic-model",
        transport=fake_post,
    )
    assert "TEST_ONLY_NOT_A_REAL_KEY" not in repr(policy)
    intent = policy.propose(player_text="I keep my shield raised and wait.",
                            actor_id="alho", allowed_targets=("orc-01",))
    assert intent == ("HOLD", None)
    narrative = policy.narrate(verified_events=("Alho holds position",))
    assert "hush" in narrative
    assert len(requests) == 2
    assert "PRIVATE" not in json.dumps(requests)
    assert "roll" not in json.dumps(requests[0]).lower() or "no" in json.dumps(requests[0]).lower()


def test_injected_live_like_intent_policy_used_but_engine_owns_outcome():
    class UntrustedModel:
        def __init__(self):
            self.proposals = []
            self.narrations = []

        def propose(self, *, player_text, actor_id, allowed_targets):
            self.proposals.append((player_text, actor_id, allowed_targets))
            return "HOLD", None

        def narrate(self, *, verified_events):
            self.narrations.append(verified_events)
            return "The hall seems tense."

    fake = UntrustedModel()
    app, service, sources = make_app(policy=fake)
    with TestClient(app) as client:
        initial = start(client)["combat"]
        response = act(client, initial, "I wait cautiously", action_id="live-like-1")
        assert response["status"] == "NEEDS_PLAYER_INPUT"
        assert "Narrative (non-authoritative)" in response["message"]
        assert fake.proposals[0][0] == "I wait cautiously"
        assert fake.proposals[0][1] == "alho"
        assert len(fake.narrations) >= 1
        assert sources[0].cursor == 4  # 2 side initiative + Evro attack/damage
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 0
