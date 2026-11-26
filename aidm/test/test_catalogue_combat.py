"""DES-001.7.9: SQL catalogue -> version-pinned offline Combat Session integration.

No SQL Server, secrets or network required. Uses exact existing Meta /api/turn
and the synthetic authored 3v3 scene as a test ONLY; not a B1 battle.
"""
from __future__ import annotations

from dataclasses import replace
import json

import pytest
from fastapi.testclient import TestClient

from aidm.catalogue import (
    MonsterCatalogue, MonsterTestScenarios, NotPlayable, build_test_handoff,
)
from aidm.catalogue_combat import prepare_prototype_encounter
from aidm.combat.dice import FixedRollSource
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.session import CombatSessionService
from aidm.combat.test.test_combat_session import FakeLogger, WIN_FACES, act, log, reset, start
from aidm.config import load_config
from aidm.test.test_catalogue import FakeQuery, case_row, monster_row, scenario_row
from aidm.web.app import create_chat_app


class SwitchableQuery(FakeQuery):
    disconnected = False

    def __call__(self, sql, parameters):
        if self.disconnected:
            raise AssertionError("Combat attempted a database call after snapshot was resolved")
        return super().__call__(sql, parameters)


def prepared_pair():
    source = monster_row(
        code="ORC", record="2026-11-21", status="Approved", active=1,
        SpecialAttacksFeatures="",  # no specials silently ignored by this prototype
        SpecialEncounterFeatures="They might parlay; Encounter owns this guidance.",
    )
    fake = SwitchableQuery(monsters=[source], scenarios=[], cases=[])
    def scenario(code, hp):
        roster = [
            {"actor_id": f"orc-{i:02d}", "species": "ORC",
             "role": "ordinary", "hp_start": value, "weapon": "shortsword",
             "species_record_date": "2026-11-21"}
            for i, value in enumerate(hp, 1)
        ]
        return scenario_row(
            code=code, ready=1, status="Ready", MonsterCount=3,
            PartyRosterJson=json.dumps([
                {"actor_id": "alho", "hp_start": 8},
                {"actor_id": "evro", "hp_start": 8},
                {"actor_id": "sho-rembo", "hp_start": 9},
            ]),
            MonsterRosterJson=json.dumps(roster),
            SceneFactsJson=json.dumps({"approved_for_test_bootstrap": True,
                                      "surprise": "author-approved-none",
                                      "geometry": "owner-canonical-stationary-melee"}),
        )
    fake.scenarios = [
        scenario("ORC-T001-A", (6, 4, 3)),
        scenario("ORC-T001-B", (3, 2, 1)),
    ]
    fake.cases = [
        case_row(code="ORC-T001-A", status="Ready"),
        case_row(code="ORC-T001-B", status="Ready"),
    ]
    repo = MonsterTestScenarios(fake)
    catalogue = MonsterCatalogue(fake)
    template = canonical_three_vs_three().encounter

    def approved(profile):
        # This is an EXPLICIT test-only authorisation of the engine's
        # currently implemented stationary HD1 / shortsword melee profile,
        # NOT a claim that the generic engine handles every monster rule.
        return (profile.identity[1] == "ORC" and profile.armor_class == 6
                and profile.hit_dice_text == "1" and profile.attack_pattern == "1"
                and profile.damage_pattern in ("1d6", "1d6 or by weapon")
                and profile.save_as == "F1" and not profile.special_attacks_features)

    results = []
    for code in ("ORC-T001-A", "ORC-T001-B"):
        defined = repo.resolve(code)
        handoff = build_test_handoff(
            defined, catalogue, mechanics_verified_ref="owner.verified.test.melee1")
        encounter = prepare_prototype_encounter(
            handoff, authored_template=template, mechanics_supported=approved)
        results.append((defined, handoff, encounter))
    return fake, tuple(results), template


def test_two_distinct_hp_rosters_keep_same_source_version_and_honor_approved_scene():
    fake, pair, template = prepared_pair()
    a, b = pair
    assert [x.starting_hp for x in a[1].actors] == [6, 4, 3]
    assert [x.starting_hp for x in b[1].actors] == [3, 2, 1]
    assert {seed.source_version for _, handoff, _ in pair for seed in handoff.actors} == {
        ("MentzerBECMI", "ORC", "2026-11-21")
    }
    for defined, handoff, encounter in pair:
        assert encounter.battleground is template.battleground
        assert encounter.party is template.party
        assert {m.source_ref for m in encounter.opposing_forces[0].side.members} == {
            "Rules.Monster:MentzerBECMI:ORC:2026-11-21"
        }
        assert [m.hp_current for m in encounter.opposing_forces[0].side.members] == [
            a.starting_hp for a in handoff.actors
        ]
        assert encounter.monster_definitions[0].provenance.endswith(
            "mechanics:owner.verified.test.melee1"
        )
        assert "parlay" not in repr(encounter.monster_definitions)
        assert "parlay" not in repr(handoff.sources)
        assert "parlay" not in repr(encounter)
    assert len([sql for sql, _ in fake.calls if "[Rules].[Monster]" in sql]) == 2


def test_actual_combat_engine_turn_and_reset_are_100_percent_offline_after_disconnection():
    query, pair, _ = prepared_pair()
    # The provider is deliberately broken AFTER source resolution. Combat
    # must continue via the immutable snapshots, without any stored connector.
    query.disconnected = True

    for (_, handoff, encounter), expected_hp in zip(
            pair, ((6, 4, 3), (3, 2, 1)), strict=True):
        service = CombatSessionService(
            roll_source_factory=lambda: FixedRollSource(WIN_FACES),
            prototype_encounter=encounter,
        )
        settings = load_config(
            environ={"AIDM_MODE": "test"},
            dotenv_path="/unavailable/sql/secret.env",
        )
        app = create_chat_app(
            settings=settings, logger=FakeLogger(),
            combat_session_handler=service,
        )
        with TestClient(app) as client:
            reply = start(client)
            assert reply["status"] == "NEEDS_PLAYER_INPUT"
            view = reply["combat"]
            assert view["fixture_id"] == "owner-canonical-3v3-fixture-v1"
            assert view["fixture_status"] == "TEST_ONLY"
            assert "preloaded" in view["fixture_label"]
            active = service._sessions["s1"].engine
            assert tuple(active.snapshot()["hp"][f"orc-{n:02d}"] for n in range(1, 4)) == expected_hp
            before = active.snapshot()["version"]
            progressed = act(client, view, "HOLD", action_id="offline-1")
            assert progressed["status"] in ("NEEDS_PLAYER_INPUT", "COMPLETED")
            assert active.snapshot()["version"] > before
            assert not any("parlay" in json.dumps(x) for x in active.player_view()["actors"])
            assert log(client, progressed["combat"])["combat"]["fixture_status"] == "TEST_ONLY"
            restored = reset(client, progressed["combat"])
            assert restored["combat"]["encounter_id"] != view["encounter_id"]
            assert tuple(
                service._sessions["s1"].engine.snapshot()["hp"][f"orc-{n:02d}"]
                for n in range(1, 4)
            ) == expected_hp
    # One query transcript from the initial loader; no calls at all after disconnection.
    assert query.disconnected


@pytest.mark.parametrize("mode", ["missing_approval", "unsupported", "rules_exception",
                                  "wrong_party", "wrong_weapon", "missing_actor",
                                  "wrong_version", "unapproved_scene"])
def test_unsafe_preparation_rejected_without_starting_combat(mode):
    fake, pair, template = prepared_pair()
    _, handoff, _ = pair[0]
    kwargs = dict(authored_template=template, mechanics_supported=lambda p: True)
    if mode == "missing_approval":
        kwargs["mechanics_supported"] = None
    elif mode == "unsupported":
        kwargs["mechanics_supported"] = lambda p: False
    elif mode == "rules_exception":
        kwargs["mechanics_supported"] = lambda p: (_ for _ in ()).throw(
            RuntimeError("DATABASE_PASSWORD_DO_NOT_LEAK"))
    elif mode == "wrong_party":
        bad = json.loads(handoff.party_roster_json)
        bad[0]["hp_start"] += 1
        handoff = replace(handoff, party_roster_json=json.dumps(bad))
    elif mode == "wrong_weapon":
        handoff = replace(handoff, actors=(
            replace(handoff.actors[0], equipment="invented_weap"), *handoff.actors[1:]
        ))
    elif mode == "missing_actor":
        handoff = replace(handoff, actors=handoff.actors[:2])
    elif mode == "wrong_version":
        handoff = replace(handoff, actors=(
            replace(handoff.actors[0], source_version=("MentzerBECMI", "ORC", "1999-01-01")),
            *handoff.actors[1:]
        ))
    elif mode == "unapproved_scene":
        handoff = replace(handoff, scene_facts_json=json.dumps(
            {"approved_for_test_bootstrap": False}))
    with pytest.raises(NotPlayable) as err:
        prepare_prototype_encounter(handoff, **kwargs)
    assert "DATABASE_PASSWORD" not in str(err.value)


def test_real_source_specials_are_blocked_until_implemented_and_signed_off():
    fake, pair, template = prepared_pair()
    _, handoff, _ = pair[0]
    with pytest.raises(NotPlayable):
        prepare_prototype_encounter(
            replace(handoff, sources=(replace(
                handoff.sources[0], special_attacks_features="Daylight imposes -1 to hit"),)),
            authored_template=template,
            mechanics_supported=lambda profile: not profile.special_attacks_features,
        )


def test_original_synthetic_3v3_remains_untouched_and_no_b1_ids_enabled():
    service = CombatSessionService()
    assert service._prototype_encounter is None
    canonical = canonical_three_vs_three()
    assert [x.hp_current for x in canonical.encounter.opposing_forces[0].side.members] == [
        6, 4, 3
    ]
    with pytest.raises(ValueError):
        CombatSessionService(prototype_encounter="SELECT * FROM Rules.Monster")
