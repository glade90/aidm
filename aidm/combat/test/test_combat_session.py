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


def reset(client, view, *, session="s1", encounter=None):
    response = client.post("/api/turn", json={
        "session_id": session, "correlation_id": f"reset-{session}-{view['state_version']}",
        "combat": {
            "kind": "RESET",
            "encounter_id": view["encounter_id"] if encounter is None else encounter,
            "log_since_sequence": 0,
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


def test_reset_creates_new_canonical_engine_while_preserving_session_identity():
    app, service, sources = make_app()
    with TestClient(app) as client:
        before = start(client)
        old = before["combat"]
        old_engine = service._sessions["s1"].engine
        old_snapshot = old_engine.snapshot()
        assert old["state_version"] == 0
        assert len(sources) == 1
        fresh = reset(client, old)
        assert fresh["status"] == "NEEDS_PLAYER_INPUT"
        assert fresh["simulated"] is False
        assert "Combat reset" in fresh["message"]
        assert fresh["session_id"] == before["session_id"] == "s1"
        newer = fresh["combat"]
        assert newer["encounter_id"] != old["encounter_id"]
        assert newer["state_version"] == 0
        assert newer["current_round"] == 1
        assert newer["log_next_cursor"] > 0
        assert newer["next_decision"]["actor_id"] == "alho"
        assert newer["next_decision"]["decision_token"] != old["next_decision"]["decision_token"]
        assert newer["new_log_entries"][0]["kind"] == "ROUND_STARTED"
        assert all(entry["round"] == 1 for entry in newer["new_log_entries"])
        assert {a["actor_id"]: a["hp_current"] for a in newer["party_status"]} == {
            "alho": 8, "evro": 8, "sho-rembo": 9,
        }
        assert len(sources) == 2
        assert sources[0] is not sources[1]
        assert sources[0].cursor == sources[1].cursor == 2
        assert service._sessions["s1"].engine is not old_engine
        assert old_engine.snapshot() == old_snapshot
        # START is idempotent; reset is the only way to replace this encounter.
        same = start(client)["combat"]
        assert same["encounter_id"] == newer["encounter_id"]
        assert len(sources) == 2
        action = act(client, newer, "HOLD", action_id="fresh-action")
        assert action["status"] == "NEEDS_PLAYER_INPUT"
        assert action["combat"]["state_version"] > newer["state_version"]
        assert sources[0].cursor == 2
        assert service._sessions["s1"].engine is not old_engine


def test_reset_rejects_old_or_foreign_encounter_without_changing_any_state():
    app, service, sources = make_app()
    with TestClient(app) as client:
        before = start(client)["combat"]
        unrelated = start(client, session="s2")["combat"]
        denied = reset(client, before, encounter=unrelated["encounter_id"])
        assert denied["status"] == "BLOCKED"
        assert denied["combat"] is None
        assert service._sessions["s1"].engine.version == 0
        assert len(sources) == 2

        first = reset(client, before)
        assert first["status"] == "NEEDS_PLAYER_INPUT"
        new = first["combat"]
        assert len(sources) == 3
        repeated = reset(client, before)
        assert repeated["status"] == "BLOCKED"
        assert repeated["combat"] is None
        assert len(sources) == 3
        assert service._sessions["s1"].encounter_id == new["encounter_id"]
        assert service._sessions["s2"].encounter_id == unrelated["encounter_id"]
        stale_action = act(client, before, "HOLD", action_id="stale-after-reset")
        assert stale_action["status"] == "BLOCKED"
        assert stale_action["combat"] is None
        assert service._sessions["s1"].engine.version == 0
        assert len(sources) == 3
        assert sources[2].cursor == 2
        live_log = log(client, new)["combat"]
        assert live_log["encounter_id"] == new["encounter_id"]


def test_reset_works_after_terminal_without_replaying_previous_outcome():
    app, service, sources = make_app()
    with TestClient(app) as client:
        first = start(client)["combat"]
        v1 = act(client, first, "HOLD", action_id="terminal-1")["combat"]
        v2 = act(client, v1, "HOLD", action_id="terminal-2")["combat"]
        completed = act(client, v2, "Orc 2", action_id="terminal-3")["combat"]
        assert completed["terminal"] is True
        assert completed["outcome"] == "PARTY_VICTORY"
        reset_result = reset(client, completed)
        assert reset_result["status"] == "NEEDS_PLAYER_INPUT"
        v = reset_result["combat"]
        assert v["terminal"] is False
        assert v["outcome"] is None
        assert v["surviving_party_summary"] is None
        assert v["state_version"] == 0
        assert v["encounter_id"] != completed["encounter_id"]
        assert len(sources) == 2
        assert all(e["round"] == 1 for e in v["new_log_entries"])
        assert all(e["kind"] != "ENCOUNTER_TERMINAL" for e in v["new_log_entries"])


def test_real_start_only_path_preserves_meta_contract_and_human_prompt():
    app, service, sources = make_app()
    with TestClient(app) as client:
        started = start(client)
        assert started["status"] == "NEEDS_PLAYER_INPUT"
        assert started["simulated"] is False and started["tool_outcome"] is None
        assert started["combat"]["intent_mode"] == "OFFLINE_SCRIPTED"
        assert started["session_id"] == "s1"
        v = started["combat"]
        assert v["state_version"] == 0 and v["current_round"] == 1
        assert v["awaiting_player"] and not v["terminal"] and v["outcome"] is None
        assert v["next_decision"]["actor_id"] == "alho"
        assert {"orc-01", "orc-02", "orc-03"} == set(v["next_decision"]["allowed_targets"])
        assert "Alho" in v["next_decision"]["prompt"]
        assert "enc-" in v["encounter_id"]
        assert sources[0].cursor == 2  # raw initiative faces only
        assert any(x["kind"] == "SIDE_INITIATIVE" and x["cue"] == "INITIATIVE"
                   for x in v["new_log_entries"])
        assert any(x["kind"] == "ROUND_STARTED" and x["cue"] == "ROUND"
                   for x in v["new_log_entries"])
        assert client.get("/status").json()["capabilities"] == ["combat", "combat_session", "dm"]
        assert client.get("/chat").status_code == 200
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 6


@pytest.mark.parametrize("faces, expected_text", [
    ((6, 2), "Round 1 initiative: Party 6, Orcs 2 — Party wins initiative and acts first"),
    ((2, 6, 1, 1, 1),
     "Round 1 initiative: Party 2, Orcs 6 — Orcs win initiative and act first"),
    ((6, 6), "Round 1 initiative: Party 6, Orcs 6 — Initiative tied — both sides act simultaneously"),
])
def test_each_initiative_roll_names_source_verified_winner_or_tie(faces, expected_text):
    app, service, sources = make_app(faces=faces)
    with TestClient(app) as client:
        initial = start(client)
        assert initial["status"] == "NEEDS_PLAYER_INPUT"
        assert expected_text in initial["message"]
        assert "\n🎲 " in initial["message"]
        assert "🔄 Round 1 begins." in initial["message"]
        assert "\n" in initial["message"]
        events = initial["combat"]["new_log_entries"]
        initiative = [event for event in events if event["kind"] == "SIDE_INITIATIVE"]
        assert len(initiative) == 1
        assert initiative[0]["text"] == expected_text
        assert initiative[0]["cue"] == "INITIATIVE"
        assert initiative[0]["round"] == 1
        assert sources[0].cursor == len(faces)
        assert "faces_by_side" not in json.dumps(initial)
        assert "defender_ac" not in json.dumps(initial)


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
        assert evro[0]["cue"] == "FALL"  # Source-backed HP fell to zero.
        assert "💀" in a1["message"]
        assert "✋" in a1["message"]  # Alho held.
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
        assert "Round 2 initiative: Party 6, Orcs 2" in a2["message"]
        assert "Party wins initiative and acts first" in a2["message"]
        assert "\n🎲 " in a2["message"]
        assert "\n" in a2["message"]
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
        assert any(e["kind"] == "ENCOUNTER_TERMINAL" and e["cue"] == "VICTORY"
                   for e in logs)
        assert "🏆" in done["message"]
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


@pytest.mark.parametrize("text, expected_target", [
    ("Orc 1", "orc-01"),
    ("1", "orc-01"),
    ("Orc 2", "orc-02"),
    ("2", "orc-02"),
    ("Orc 3", "orc-03"),
    ("3", "orc-03"),
    ("orc-01", "orc-01"),
    (" ORC 2 ", "orc-02"),
])
def test_offline_target_shorthand_only_uses_pending_visible_target(text, expected_target):
    policy = ScriptedIntentPolicy()
    action, target = policy.propose(
        player_text=text, actor_id="alho",
        allowed_targets=("orc-01", "orc-02", "orc-03"),
    )
    assert action == "ATTACK_MELEE"
    assert target == expected_target


@pytest.mark.parametrize("text", [
    "Orc 4", "4", "99", "Orc 99", "Orc 1 or Orc 2", "1 and 2",
    "all the orcs", "orc",
])
def test_offline_shorthand_ambiguous_or_unlisted_target_fails_closed(text):
    action, target = ScriptedIntentPolicy().propose(
        player_text=text, actor_id="alho",
        allowed_targets=("orc-01", "orc-02", "orc-03"),
    )
    assert (action, target) == ("NEEDS_CLARIFICATION", None)


def test_shorthand_is_a_real_combat_action_and_dm_describes_outcome():
    app, service, sources = make_app()
    with TestClient(app) as client:
        first = start(client)["combat"]
        answer = act(client, first, "Orc 1", action_id="short-answer-1")
        assert answer["status"] == "NEEDS_PLAYER_INPUT"
        assert answer["combat"]["next_decision"]["actor_id"] == "sho-rembo"
        assert answer["combat"]["state_version"] == 2  # Alho then Evro
        assert sources[0].cursor == 4  # 2 initiative + two misses
        assert "Alho misses Orc 1" in answer["message"]
        assert "Evro misses Orc 1" in answer["message"]
        assert "Combat action accepted" not in answer["message"]
        assert "Sho-Rembo" in answer["message"]


def test_initiative_can_incapacitate_evro_before_his_action_and_dm_reports_it():
    # Mirrors the real PEQUOD browser report: Orc 1 does six damage, Orc 2
    # misses, Orc 3 does three; Evro began with eight HP and cannot attack.
    faces = (2, 6, 19, 6, 11, 17, 3)
    app, service, sources = make_app(faces=faces)
    with TestClient(app) as client:
        started = start(client)
        assert started["status"] == "NEEDS_PLAYER_INPUT"
        view = started["combat"]
        assert view["next_decision"]["actor_id"] == "alho"
        assert service._sessions["s1"].engine.snapshot()["hp"]["evro"] == 0
        evro = next(x for x in view["party_status"] if x["actor_id"] == "evro")
        assert (evro["hp_current"], evro["hp_max"]) == (0, 8)
        assert "Orc 1 hits Evro for 6 damage" in started["message"]
        assert "Orc 3 hits Evro for 3 damage" in started["message"]
        assert "Evro falls" in started["message"]
        assert "💀" in started["message"]
        assert any(e["cue"] == "FALL" and "Evro falls" in e["text"]
                   for e in view["new_log_entries"])
        assert any("Evro falls" in e["text"]
                   for e in view["new_log_entries"])
        assert not any(e.actor_id == "evro" and e.kind == "MELEE_RESOLVED"
                       for e in service._sessions["s1"].engine.journal())
        assert sources[0].cursor == len(faces)
        assert "defender_ac" not in json.dumps(started)
        assert "hp_before" not in json.dumps(started)


def test_invalid_short_target_explains_error_without_consuming_die():
    app, service, sources = make_app()
    with TestClient(app) as client:
        first = start(client)["combat"]
        bad = act(client, first, "Orc 99", action_id="invalid-short")
        assert bad["status"] == "NEEDS_PLAYER_INPUT"
        assert "couldn't identify a single legal target" in bad["message"]
        assert "Orc 1" in bad["message"]
        assert bad["combat"]["state_version"] == 0
        assert sources[0].cursor == 2
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 6


def test_visible_orc_falls_at_zero_hp_and_dm_announces_knockout():
    # Owner's actual browser sequence: Alho 4 damage then Evro 4 damage
    # against an Orc initially at 6 HP. Never silently remove the orc.
    app, service, sources = make_app(faces=(6, 2, 19, 4, 12, 1))
    with TestClient(app) as client:
        initial = start(client)["combat"]
        response = act(client, initial, "Attack Orc 1", action_id="fell-orc-1")
        view = response["combat"]
        assert response["status"] == "NEEDS_PLAYER_INPUT"
        assert "Alho hits Orc 1 for 4 damage" in response["message"]
        assert "Evro hits Orc 1 for 4 damage" in response["message"]
        assert "Orc 1 falls" in response["message"]
        assert "💀" in response["message"]
        actual_hits = [e for e in view["new_log_entries"] if e["kind"] == "MELEE_RESOLVED"]
        assert [e["cue"] for e in actual_hits] == ["HIT", "FALL"]
        assert "⚔️" in response["message"]
        assert any("Orc 1 falls" in e["text"]
                   for e in view["new_log_entries"] if e["kind"] == "MELEE_RESOLVED")
        assert "orc-01" not in view["next_decision"]["allowed_targets"]
        assert "Orc 1" not in view["next_decision"]["prompt"]
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 0
        assert next(a for a in service._sessions["s1"].engine.player_view()["actors"]
                    if a["actor_id"] == "orc-01")["defeated"] is True
        assert sources[0].cursor == 6
        assert "hp_after" not in json.dumps(response)
        assert "defender_ac" not in json.dumps(response)


def test_player_can_ask_if_orc_is_down_without_consuming_turn_or_dice():
    app, service, sources = make_app()
    with TestClient(app) as client:
        first = start(client)["combat"]
        # Evro's 12+3 hit and 5+3 damage eliminates Orc 1 while
        # Sho-Rembo is waiting to act. Orc 2 and 3 remain visible.
        second = act(client, first, "HOLD", action_id="setup-kill")
        assert "Orc 1 falls" in second["message"]
        view = second["combat"]
        assert view["next_decision"]["actor_id"] == "sho-rembo"
        before = service._sessions["s1"].engine.snapshot()
        count = len(service._sessions["s1"].engine.journal())
        cursor = sources[0].cursor

        answered = act(client, view, "IS orc 1 dead?", action_id="ask-status")
        assert answered["status"] == "NEEDS_PLAYER_INPUT"
        assert "Orc 1 is down and out of the fight" in answered["message"]
        assert "Sho-Rembo" in answered["message"]
        assert answered["combat"]["next_decision"] == view["next_decision"]
        assert answered["combat"]["state_version"] == view["state_version"]
        assert sources[0].cursor == cursor
        assert service._sessions["s1"].engine.snapshot() == before
        assert len(service._sessions["s1"].engine.journal()) == count
        assert not any(x in json.dumps(answered)
                       for x in ("hp_before", "hp_after", "defender_ac", "hidden_traits"))

        still = act(client, view, "Is Orc 2 still alive?", action_id="ask-live")
        assert "Orc 2 is still in the fight" in still["message"]
        assert service._sessions["s1"].engine.snapshot() == before
        assert sources[0].cursor == cursor

        dead_target = act(client, view, "Orc 1", action_id="attack-defeated")
        assert dead_target["status"] == "NEEDS_PLAYER_INPUT"
        assert "Orc 1 is already down" in dead_target["message"]
        assert "Orc 2" in dead_target["message"]
        assert "Orc 1" not in dead_target["combat"]["next_decision"]["prompt"]
        assert service._sessions["s1"].engine.snapshot() == before
        assert sources[0].cursor == cursor


def test_status_question_never_invokes_even_an_injected_llm():
    class SpyLlm:
        mode = "LIVE_LLM"

        def __init__(self):
            self.proposals = 0
            self.narrations = 0

        def propose(self, *, player_text, actor_id, allowed_targets):
            self.proposals += 1
            return "HOLD", None

        def narrate(self, *, verified_events):
            self.narrations += 1
            return None

    policy = SpyLlm()
    app, service, sources = make_app(policy=policy)
    with TestClient(app) as client:
        first = start(client)
        assert first["combat"]["intent_mode"] == "LIVE_LLM"
        prior_proposals, prior_narrations = policy.proposals, policy.narrations
        before = service._sessions["s1"].engine.snapshot()
        cursor = sources[0].cursor
        answer = act(client, first["combat"], "Is Orc 1 dead?", action_id="query-no-llm")
        assert "Orc 1 is still in the fight" in answer["message"]
        assert (policy.proposals, policy.narrations) == (prior_proposals, prior_narrations)
        assert service._sessions["s1"].engine.snapshot() == before
        assert sources[0].cursor == cursor


def test_tied_initiative_miss_does_not_take_credit_for_simultaneous_defeat():
    # Owner browser defect: when initiative ties, the CombatEngine commits
    # aggregate HP to every resolved attack event for a target. A missed blow
    # can therefore have hp_before=6, hp_after=0 in the internal journal,
    # but must NEVER be projected as 'Alho misses. Orc 1 falls'.
    # Tie: 6=6. Alho rolls 2 (miss); Evro rolls 12 and 5, dealing 8
    # to Orc 1 (6 HP). Other orcs miss on faces 1. Round 2 party wins
    # initiative 6>2, leaving a new human pending decision.
    faces = (6, 6, 2, 12, 5, 1, 1, 1, 6, 2)
    app, service, sources = make_app(faces=faces)
    with TestClient(app) as client:
        first = start(client)["combat"]
        assert first["next_decision"]["actor_id"] == "alho"
        after_alho = act(client, first, "Orc 1", action_id="tie-alho")
        assert after_alho["status"] == "NEEDS_PLAYER_INPUT"
        assert after_alho["combat"]["next_decision"]["actor_id"] == "sho-rembo"
        after_sho = act(client, after_alho["combat"], "HOLD", action_id="tie-sho")
        assert after_sho["status"] == "NEEDS_PLAYER_INPUT"
        view = after_sho["combat"]

        resolved = [x for x in view["new_log_entries"] if x["kind"] == "MELEE_RESOLVED"]
        miss = next(x for x in resolved if x["text"].startswith("Alho misses"))
        assert miss["cue"] == "MISS"
        assert "falls" not in miss["text"]
        assert miss["roll"]["hit"] is False
        assert miss["roll"]["damage_total"] == 0
        evro = next(x for x in resolved if x["text"].startswith("Evro hits"))
        assert evro["cue"] == "HIT"
        assert evro["roll"]["damage_total"] == 8
        assert "falls" not in evro["text"]

        commits = [x for x in view["new_log_entries"]
                   if x["kind"] == "SIMULTANEOUS_EXCHANGE_COMMITTED"]
        assert len(commits) == 1
        assert commits[0]["cue"] == "FALL"
        assert "Orc 1 falls" in commits[0]["text"]
        assert "Alho misses Orc 1" in after_sho["message"]
        assert "💨" in after_sho["message"]
        assert "Orc 1 falls" in after_sho["message"]
        assert "💀" in after_sho["message"]
        assert "Alho misses Orc 1. Orc 1 falls" not in after_sho["message"]
        assert sum("Orc 1 falls" in e["text"]
                   for e in view["new_log_entries"]) == 1
        assert service._sessions["s1"].engine.snapshot()["hp"]["orc-01"] == 0
        assert "orc-01" not in view["next_decision"]["allowed_targets"]
        assert sources[0].cursor == len(faces)
        response_text = json.dumps(after_sho)
        assert "hp_before" not in response_text
        assert "hp_after" not in response_text
        assert "defender_ac" not in response_text

        # The full audit projection agrees, and VIEW_LOG is truly read-only.
        before = service._sessions["s1"].engine.snapshot()
        audit = log(client, view)["combat"]["new_log_entries"]
        assert sum("Orc 1 falls" in e["text"] for e in audit) == 1
        assert next(x for x in audit if x["text"].startswith("Alho misses"))["cue"] == "MISS"
        assert service._sessions["s1"].engine.snapshot() == before
        assert sources[0].cursor == len(faces)


def test_safe_combat_event_cue_schema_rejects_unrecognised_hints():
    from pydantic import ValidationError
    from aidm.meta.turn import CombatLogView

    event = {
        "seq": 1, "round": 1, "phase": "MELEE",
        "kind": "MELEE_RESOLVED", "text": "Orc 1 falls",
    }
    assert CombatLogView.model_validate({**event, "cue": "FALL"}).cue == "FALL"
    with pytest.raises(ValidationError):
        CombatLogView.model_validate({**event, "cue": "SECRET_RULE"})
    with pytest.raises(ValidationError):
        CombatLogView.model_validate({**event, "cue": "<script>alert(1)</script>"})


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
