"""AIDM-DES-006.2: F01–F23 reproducible mock-state contract tests.

Usage: python -m pytest aidm/combat/test/test_state.py -q --cov=aidm.combat.state --cov=aidm.combat.fixtures
Change Log: 2026-11-20 COSTA — 2x2 win/loss, source-labelled 3x3, variable roster.
"""
from __future__ import annotations

from dataclasses import FrozenInstanceError, asdict, replace
import json
from concurrent.futures import ThreadPoolExecutor

import pytest

from aidm.combat import dice
from aidm.combat.fixtures import two_by_two, canonical_three_vs_three, variable_three_vs_four
from aidm.combat.state import (
    AbilityValue, ActorHPChange, ActorPlacement, ApprovedFixtureEffect, AreaRef,
    BattlegroundDefinition, Combatant, CombatSide, Controller, DeclaredAction,
    EncounterDefinition, EncounterParty, EncounterSnapshot, EquipmentRef,
    FixtureDefinition, FixtureError, FixtureErrorCode, FixtureOutcome, MeleeEligibility,
    MockEncounterState, MonsterGroup, OpposingForce, Origin, PositionRef, ProposalStatus,
    RecordedRollAssociation, ScenarioOverride, SpatialModel, Visibility, ZoneRelation,
)


def make(fixture=None, session="session-1"):
    token = object()
    state = MockEncounterState.start(fixture or two_by_two(), session_id=session, trusted_token=token)
    return state, token


def hp(snapshot):
    return [a.hp_current for a in snapshot.actors]


def expect_code(expected, thunk):
    with pytest.raises(FixtureError) as exc:
        thunk()
    assert exc.value.code is expected


def test_f01_initial_two_by_two_is_synthetic_and_typed():
    fixture = two_by_two()
    assert fixture.schema_version == "0.1"
    assert fixture.rules_verified is False and fixture.provenance == "SYNTHETIC_TEST"
    assert fixture.encounter.rules_profile_ref and fixture.encounter.house_rule_overlay_refs
    assert fixture.encounter.party.party_id and len(fixture.encounter.party.members) == 2
    assert len(fixture.encounter.sides) == 2
    assert fixture.encounter.battleground.area.zones == ("near-entry", "far-side")
    state, _ = make(fixture)
    snapshot = state.snapshot()
    assert hp(snapshot) == [7, 6, 3, 4]
    assert snapshot.state_version == 0 and snapshot.round_index == 1
    assert snapshot.outcome is FixtureOutcome.ONGOING and snapshot.checkpoint == "INITIAL"
    assert [a.actor_id for a in snapshot.actors] == ["pc-alpha", "pc-beta", "mob-1", "mob-2"]
    assert len({a.side_id for a in snapshot.actors}) == 2
    assert {m.encounter_actor_id for m in fixture.encounter.members} == {p.actor_id for p in snapshot.placements}


def test_f02_independent_sessions_and_immutable_definition():
    fixture = two_by_two()
    a, token_a = make(fixture, "session-A")
    b, token_b = make(fixture, "session-B")
    original = a.snapshot()
    a.apply_scripted_effect(fixture.approved_effects[0], token=token_a)
    assert hp(b.snapshot()) == [7, 6, 3, 4]
    assert hp(original) == hp(b.snapshot())
    assert b.snapshot().session_id == "session-B"
    assert fixture.encounter.members[1].hp_current == 6
    assert fixture.encounter.battleground.initial_placements[0].position.zone_id == "near-entry"
    with pytest.raises(FrozenInstanceError):
        fixture.encounter.party.side = b._fixture.encounter.party.side


def test_f03_first_scripted_round_version_and_initial_snapshot_preserved():
    f = two_by_two()
    state, token = make(f)
    before = state.snapshot()
    after = state.apply_scripted_effect(f.approved_effects[0], token=token)
    assert hp(before) == [7, 6, 3, 4]
    assert hp(after) == [7, 5, 1, 4]
    assert after.state_version == 1 and after.round_index == 2
    assert after.applied_effect_ids == (f.approved_effects[0].effect_id,)
    assert after.outcome is FixtureOutcome.ONGOING


def test_f04_second_scripted_round_party_victory():
    f = two_by_two()
    state, token = make(f)
    state.apply_scripted_effect(f.approved_effects[0], token=token)
    final = state.apply_scripted_effect(f.approved_effects[1], token=token)
    assert hp(final) == [4, 5, 0, 0]
    assert final.state_version == 2 and final.round_index == 3
    assert final.outcome is FixtureOutcome.PARTY_VICTORY
    assert final.checkpoint == "TERMINAL_FIXTURE"
    assert final.applied_effect_ids == tuple(e.effect_id for e in f.approved_effects)


def test_f05_independent_scripted_two_round_party_defeat():
    f = two_by_two(loss=True)
    state, token = make(f)
    middle = state.apply_scripted_effect(f.approved_effects[0], token=token)
    final = state.apply_scripted_effect(f.approved_effects[1], token=token)
    assert hp(middle) == [3, 2, 3, 4]
    assert hp(final) == [0, 0, 3, 4]
    assert final.outcome is FixtureOutcome.PARTY_DEFEAT
    assert state.snapshot().state_version == 2
    assert two_by_two().approved_effects[-1].outcome_after is FixtureOutcome.PARTY_VICTORY


@pytest.mark.parametrize("bad_actor,bad_target", [("alien", None), ("pc-alpha", "alien")])
def test_f06_invalid_action_actor_or_target_is_rejected(bad_actor, bad_target):
    state, token = make()
    original = state.snapshot()
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.record_proposal(
        DeclaredAction("action-1", bad_actor, "attack", target_id=bad_target), token=token))
    assert state.snapshot() == original


def test_f06_unvalidated_or_rejected_action_never_acts_as_effect():
    f = two_by_two()
    state, token = make(f)
    action = DeclaredAction("action-u", "pc-alpha", "I attack", "mob-1", ProposalStatus.UNVALIDATED)
    state.record_proposal(action, token=token)
    bad = replace(f.approved_effects[0], action_id="action-u")
    expect_code(FixtureErrorCode.INVALID_EFFECT, lambda: state.apply_scripted_effect(bad, token=token))
    assert state.snapshot().state_version == 0
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.record_proposal(
        replace(action, action_id="action-bad", status=ProposalStatus.REJECTED), token=token))
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.record_proposal(action, token=token))
    assert state.snapshot().state_version == 0
    assert len(state.snapshot().pending_actions) == 1


def test_f06_known_forwarded_action_still_requires_exact_fixture_authorisation():
    f = two_by_two()
    state, token = make(f)
    state.record_proposal(DeclaredAction("act", "pc-alpha", "test", "mob-1", ProposalStatus.FORWARDED), token=token)
    injected = replace(f.approved_effects[0], action_id="act")
    expect_code(FixtureErrorCode.INVALID_EFFECT, lambda: state.apply_scripted_effect(injected, token=token))
    assert hp(state.snapshot()) == [7, 6, 3, 4]


def test_f07_stale_version_duplicate_and_terminal_guard():
    f = two_by_two()
    state, token = make(f)
    start = state.snapshot()
    expect_code(FixtureErrorCode.STALE_VERSION, lambda: state.apply_scripted_effect(f.approved_effects[1], token=token))
    assert state.snapshot() == start
    state.apply_scripted_effect(f.approved_effects[0], token=token)
    mid = state.snapshot()
    expect_code(FixtureErrorCode.DUPLICATE_EFFECT, lambda: state.apply_scripted_effect(f.approved_effects[0], token=token))
    assert state.snapshot() == mid
    state.apply_scripted_effect(f.approved_effects[1], token=token)
    terminal = state.snapshot()
    expect_code(FixtureErrorCode.TERMINAL, lambda: state.apply_scripted_effect(
        replace(f.approved_effects[1], effect_id="new", expected_state_version=2), token=token))
    assert state.snapshot() == terminal


@pytest.mark.parametrize("value", [-1, 8, True, 2.1])
def test_f08_invalid_character_hp_rejected(value):
    with pytest.raises(FixtureError):
        replace(two_by_two().encounter.party.members[0], hp_current=value)


def test_f08_duplicate_actor_id_side_id_and_missing_placement_rejected():
    f = two_by_two()
    enc = f.encounter
    duplicate = replace(enc.party.members[1], encounter_actor_id="pc-alpha")
    with pytest.raises(FixtureError):
        replace(enc.party.side, members=(enc.party.members[0], duplicate))
    another_party = replace(enc.party, side=replace(enc.party.side, side_id="opponents",
                                                    members=tuple(replace(p, side_id="opponents") for p in enc.party.members)))
    with pytest.raises(FixtureError):
        replace(enc, party=another_party)
    with pytest.raises(FixtureError):
        replace(enc, battleground=replace(enc.battleground, initial_placements=enc.battleground.initial_placements[:-1]))
    with pytest.raises(FixtureError):
        replace(enc.battleground, initial_placements=enc.battleground.initial_placements + (enc.battleground.initial_placements[0],))


def test_f08_unauthorised_controller_token_and_private_view():
    f = two_by_two()
    state, token = make(f)
    outsider = object()
    snapshot = state.snapshot()
    expect_code(FixtureErrorCode.UNAUTHORISED, lambda: state.apply_scripted_effect(f.approved_effects[0], token=outsider))
    expect_code(FixtureErrorCode.UNAUTHORISED, lambda: state.view_for_controller(token=outsider))
    expect_code(FixtureErrorCode.UNAUTHORISED, lambda: state.attach_raw_roll(
        RecordedRollAssociation("act", "roll", "die", 1, 6, "FIXED", 0, None), token=outsider))
    assert state.snapshot() == snapshot


def test_f09_player_view_redacts_opponents_and_does_not_alias_live_state():
    state, token = make()
    private = state.view_for_controller(token=token)
    public = state.view_for_player()
    opponent = next(a for a in public["actors"] if a["actor_id"] == "mob-1")
    actual = next(a for a in private["actors"] if a["actor_id"] == "mob-1")
    assert actual["hp_current"] == 3 and actual["armor_class_source"] == 6
    assert actual["status_tags"] == ()
    assert "hp_current" not in opponent and "hp_max" not in opponent
    assert "armor_class_source" not in opponent and "hidden_traits" not in opponent
    assert "source_ref" not in opponent
    assert public["sides"][1]["group_ids"] == ["group-g"]
    public["actors"][0]["hp_current"] = 999
    private["actors"][0]["hp_current"] = 888
    public["sides"].clear()
    assert state.snapshot().actors[0].hp_current == 7
    assert len(state.view_for_player()["sides"]) == 2


def test_f10_unsupplied_spatial_facts_remain_unknown():
    ground = two_by_two().encounter.battleground
    r = ground.relation("far-side", "near-entry")
    assert r.distance_ft is None and r.visibility is Visibility.UNKNOWN
    assert ground.relation("near-entry", "far-side").distance_ft == 20
    assert ground.relation("near-entry", "far-side").visibility is Visibility.UNKNOWN
    assert ground.melee("pc-alpha", "mob-1") is None
    with pytest.raises(FixtureError):
        ground.relation("near-entry", "out-of-scene")


def test_f11_raw_dice_attached_to_proposal_does_not_resolve_or_commit():
    f = two_by_two()
    state, token = make(f)
    action = DeclaredAction("action-fixed", "pc-alpha", "I try to attack", "mob-1",
                            correlation_id="turn-7")
    state.record_proposal(action, token=token)
    raw = dice.DiceRoller(dice.FixedRollSource([14])).roll(dice.Die("blue-d20", 20, "blue"),
                                                          roll_id="roll-fixed", correlation_id="turn-7")
    assoc = RecordedRollAssociation(action.action_id, raw.roll_id, raw.die_id, raw.face, raw.sides,
                                    raw.source.value, raw.queue_position, raw.correlation_id)
    state.attach_raw_roll(assoc, token=token)
    snap = state.snapshot()
    assert snap.roll_associations == (assoc,)
    assert snap.state_version == 0 and hp(snap) == [7, 6, 3, 4]
    assert snap.pending_actions == (action,)
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.attach_raw_roll(assoc, token=token))
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.attach_raw_roll(
        replace(assoc, roll_id="other", action_id="unknown"), token=token))
    assert "roll_associations" not in state.view_for_player()


def test_f12_snapshot_json_reconstruction_and_full_replay():
    f = two_by_two()
    state, token = make(f)
    snapshots = [state.snapshot()]
    for effect in f.approved_effects:
        snapshots.append(state.apply_scripted_effect(effect, token=token))
    encoded = [json.loads(json.dumps(asdict(s))) for s in snapshots]
    recreated = [EncounterSnapshot.from_dict(s) for s in encoded]
    assert all(a == b for a, b in zip(snapshots, recreated, strict=True))
    second, second_token = make(f)
    identical = [second.snapshot()]
    for effect in f.approved_effects:
        identical.append(second.apply_scripted_effect(effect, token=second_token))
    assert identical == snapshots
    with pytest.raises(FrozenInstanceError):
        recreated[0].actors[0].hp_current = 100


def test_f13_variable_three_by_four_two_groups_three_zones():
    f = variable_three_vs_four()
    assert len(f.encounter.party.members) == 3
    assert len(f.encounter.opposing_forces[0].side.members) == 4
    assert len(f.encounter.opposing_forces[0].groups) == 2
    assert len(f.encounter.battleground.area.zones) == 3
    assert len(f.encounter.sides) == 2
    state, token = make(f)
    assert len(state.snapshot().actors) == 7
    assert len(state.view_for_controller(token=token)["placements"]) == 7


def test_f14_shared_monster_definition_independent_instances_and_sessions():
    f = variable_three_vs_four()
    a = f.encounter.opposing_forces[0].side.members[0]
    b = f.encounter.opposing_forces[0].side.members[1]
    assert a.source_ref == b.source_ref
    assert a.encounter_actor_id != b.encounter_actor_id
    assert a.hp_current != b.hp_current
    x, _ = make(f, "fx")
    y, _ = make(f, "fy")
    assert x.snapshot().actors[3].actor_id != x.snapshot().actors[4].actor_id
    assert x.snapshot() != y.snapshot()  # session IDs differ
    assert f.encounter.monster_definitions[0].definition_ref == a.source_ref


def test_f15_invalid_placements_rejected_before_state_start():
    f = variable_three_vs_four()
    enc = f.encounter
    placements = enc.battleground.initial_placements
    for bad in (
        placements + (placements[0],),
        placements + (ActorPlacement("orphan", PositionRef("middle")),),
        placements[:-1],
        tuple(replace(p, position=PositionRef("void")) if p.actor_id == "orc-04" else p for p in placements),
    ):
        with pytest.raises(FixtureError):
            replace(enc, battleground=replace(enc.battleground, initial_placements=bad))
    assert len({p.position.zone_id for p in placements}) == 3
    assert [p.position.zone_id for p in placements].count("entry") == 3


def test_f16_group_membership_preserved_controller_and_public_projection():
    f = variable_three_vs_four()
    state, _ = make(f)
    snapshot = state.snapshot()
    foe = snapshot.sides[1]
    assert foe.monster_group_ids == ("orc-group-01", "orc-group-02")
    view = state.view_for_player()
    assert view["sides"][1]["group_ids"] == ["orc-group-01", "orc-group-02"]
    assert [a["group_id"] for a in view["actors"] if "group_id" in a] == [
        "orc-group-01", "orc-group-01", "orc-group-02", "orc-group-02"]
    assert all("morale_rating" not in a for a in view["actors"])


def test_f17_future_spatial_model_explicitly_not_implemented():
    with pytest.raises(FixtureError) as exc:
        AreaRef("not-a-grid", ("A",), SpatialModel.FUTURE_GEOMETRY)
    assert exc.value.code is FixtureErrorCode.NOT_IMPLEMENTED
    assert "NOT_IMPLEMENTED" in str(exc.value)
    with pytest.raises(FixtureError):
        AreaRef("unsupported", ("A",), "UNRECOGNISED")


def test_f18_unified_sides_and_controllers_independent_of_party():
    f = canonical_three_vs_three()
    assert all(type(side) is CombatSide for side in f.encounter.sides)
    assert len(f.encounter.sides) == 2
    assert all(type(member) is Combatant for member in f.encounter.members)
    assert [a.controller for a in f.encounter.party.members] == [Controller.HUMAN, Controller.AGENT, Controller.HUMAN]
    assert all(a.controller is Controller.AGENT for a in f.encounter.opposing_forces[0].side.members)
    assert f.encounter.party.side.default_controller is Controller.HUMAN


def test_f19_abilities_and_evro_scenario_override_preserve_source():
    f = canonical_three_vs_three()
    players = {p.encounter_actor_id: p for p in f.encounter.party.members}
    assert {k: x.hp_current for k, x in players.items()} == {"alho": 8, "evro": 8, "sho-rembo": 9}
    assert {k: x.class_level_ref for k, x in players.items()} == {
        "alho": "human.fighter.1", "evro": "human.fighter.1", "sho-rembo": "halfling.1"}
    assert {a.name: a.source_value for a in players["evro"].ability_scores}["STR"] == 16
    assert players["evro"].scenario_overrides[0] == ScenarioOverride(
        "STR", 16, 18, "owner.directive.2026-11-20")
    assert {a.name: a.source_value for a in players["alho"].ability_scores}["STR"] == 12
    assert {a.name: a.source_value for a in players["sho-rembo"].ability_scores}["STR"] == 9
    assert len(players["alho"].ability_scores) == 6
    assert len(players["evro"].ability_scores) == 6
    with pytest.raises(FixtureError):
        replace(players["evro"], scenario_overrides=(ScenarioOverride("STR", 15, 18, "bad"),))


def test_f20_owner_orc_source_template_and_distinct_instances():
    f = canonical_three_vs_three()
    group = f.encounter.opposing_forces[0].groups[0]
    monsters = f.encounter.opposing_forces[0].side.members
    template = f.encounter.monster_definitions[0]
    assert (template.armor_class_source, template.hit_dice_ref, template.attacks_ref,
            template.damage_ref, template.movement_ref, template.save_ref,
            template.group_morale_source) == (6, "1", "1", "1d6 or by weapon", "90'(30')", "F1", 8)
    assert [m.hp_current for m in monsters] == [6, 4, 3]
    assert len({m.encounter_actor_id for m in monsters}) == 3
    assert {m.source_ref for m in monsters} == {template.definition_ref}
    assert all(m.group_id == group.group_id for m in monsters)
    assert group.morale_rating == 8
    assert all(m.equipped_items[0].label == "Short sword" for m in monsters)


def test_f21_equipment_refs_without_invented_effective_armor():
    party = {a.encounter_actor_id: a for a in canonical_three_vs_three().encounter.party.members}
    assert party["alho"].equipped_items[0].item_ref == "flail"
    assert party["alho"].equipped_items[0].candidate_roll is None
    assert party["alho"].equipped_items[0].verification == "UNRESOLVED_HOUSE_RULE"
    assert party["alho"].armor_class_source is None
    assert [i.item_ref for i in party["evro"].equipped_items] == ["longsword", "plate", "ordinary-shield"]
    assert [i.item_ref for i in party["sho-rembo"].equipped_items] == ["handaxe", "plate", "plus-one-shield"]
    assert all(i.verification == "PROVISIONAL" for i in party["evro"].equipped_items[1:])
    assert all(i.verification == "PROVISIONAL" for i in party["sho-rembo"].equipped_items[1:])
    assert all(x.armor_class_source is None for x in party.values())


def test_f22_unmodified_abilities_and_equipment_only_no_rules_math():
    f = canonical_three_vs_three()
    a = f.encounter.party.members[1]
    assert [p.source_value for p in a.ability_scores if p.name == "STR"] == [16]
    assert a.scenario_overrides[0].scenario_value == 18
    assert not hasattr(a, "melee_bonus")
    assert not hasattr(a, "effective_armor_class")
    assert not hasattr(f, "apply_damage")
    assert all(not hasattr(item, "damage_total") for item in a.equipped_items)


def test_f23_six_authored_placements_and_melee_relations_not_geometry():
    f = canonical_three_vs_three()
    bg = f.encounter.battleground
    assert len(bg.initial_placements) == 6
    assert [p.position.zone_id for p in bg.initial_placements] == ["central-melee"] * 6
    assert len(bg.melee_relations) == 9
    assert bg.melee("alho", "orc-01") is True
    assert bg.melee("orc-01", "alho") is True
    assert bg.melee("alho", "evro") is None
    assert bg.relation("central-melee", "central-melee").distance_ft is None
    state, _ = make(f)
    assert state.snapshot().state_version == 0


def test_invalid_fixture_and_effect_validation_cover_rejection_with_no_alias():
    f = two_by_two()
    with pytest.raises(FixtureError):
        replace(f, schema_version="9.9")
    with pytest.raises(FixtureError):
        replace(f, rules_verified=True)
    with pytest.raises(FixtureError):
        replace(f, approved_effects=(f.approved_effects[0], f.approved_effects[0]))
    state, token = make(f)
    original = state.snapshot()
    invalids = (
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("alien", 0, 0),)),
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("pc-alpha", 7, -1),)),
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("pc-alpha", 7, 100),)),
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("pc-beta", 5, 2),)),
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("pc-beta", True, 2),)),
        replace(f.approved_effects[0], hp_changes=()),
        replace(f.approved_effects[0], round_after=5),
        replace(f.approved_effects[0], hp_changes=(ActorHPChange("pc-beta", 6, 5), ActorHPChange("pc-beta", 6, 4))),
        replace(f.approved_effects[0], source="HUMAN"),
    )
    for effect in invalids:
        with pytest.raises(FixtureError):
            state.apply_scripted_effect(effect, token=token)
        assert state.snapshot() == original


def test_invalid_definition_extra_validation_and_snapshot_roundtrip_with_proposal():
    f = canonical_three_vs_three()
    with pytest.raises(FixtureError):
        replace(f.encounter.battleground.area, zones=("central-melee", "central-melee"))
    with pytest.raises(FixtureError):
        replace(f.encounter, rules_profile_ref=" ")
    with pytest.raises(FixtureError):
        replace(f.encounter, house_rule_overlay_refs=("",))
    with pytest.raises(FixtureError):
        replace(f.encounter, monster_definitions=(f.encounter.monster_definitions[0], f.encounter.monster_definitions[0]))
    state, token = make(f)
    state.record_proposal(DeclaredAction("intent", "alho", "I attack", target_id="orc-01",
                                         status=ProposalStatus.UNVALIDATED, correlation_id="trace"), token=token)
    a = RecordedRollAssociation("intent", "roll", "die-red", 12, 20, "FIXED", 0, "trace")
    state.attach_raw_roll(a, token=token)
    snap = state.snapshot()
    assert EncounterSnapshot.from_dict(json.loads(json.dumps(asdict(snap)))) == snap


def test_invalid_relation_or_group_definitions():
    f = variable_three_vs_four()
    bg = f.encounter.battleground
    with pytest.raises(FixtureError):
        replace(bg, zone_relations=(ZoneRelation("entry", "alien", 20),))
    with pytest.raises(FixtureError):
        replace(bg, melee_relations=(MeleeEligibility("alho", "orc-01", True),
                                          MeleeEligibility("orc-01", "alho", True)))
    with pytest.raises(FixtureError):
        replace(f.encounter.opposing_forces[0], groups=(MonsterGroup("dup", ("orc-01", "orc-02")),))
    with pytest.raises(FixtureError):
        replace(f.encounter.party.side, members=(replace(f.encounter.party.members[0], side_id="wrong"),))


def test_guarded_effects_in_parallel_only_one_commit():
    f = two_by_two()
    state, token = make(f)
    def run(_):
        try:
            state.apply_scripted_effect(f.approved_effects[0], token=token)
            return "OK"
        except FixtureError as exc:
            return exc.code.value
    with ThreadPoolExecutor(max_workers=2) as workers:
        outcomes = list(workers.map(run, range(2)))
    assert outcomes.count("OK") == 1
    assert "DUPLICATE_EFFECT" in outcomes
    assert state.snapshot().state_version == 1


def test_player_safe_view_contains_no_hidden_traits_ac_or_orc_hp_in_owner_fixture():
    state, token = make(canonical_three_vs_three())
    owner_private = state.view_for_controller(token=token)
    public = state.view_for_player()
    orc_private = [a for a in owner_private["actors"] if a["actor_id"].startswith("orc-")]
    orc_public = [a for a in public["actors"] if a["actor_id"].startswith("orc-")]
    assert [a["hp_current"] for a in orc_private] == [6, 4, 3]
    for a in orc_public:
        assert not {"hp_current", "hp_max", "armor_class_source", "source_ref", "hidden_traits"}.intersection(a)
    assert "status_tags" not in json.dumps(public)


def test_roll_association_validation_and_unknown_source():
    for bad in (
        ("", "r", "d", 1, 6, "FIXED", 0, None),
        ("a", "", "d", 1, 6, "FIXED", 0, None),
        ("a", "r", "", 1, 6, "FIXED", 0, None),
        ("a", "r", "d", 7, 6, "FIXED", 0, None),
        ("a", "r", "d", 1, 6, "FAKE", 0, None),
    ):
        with pytest.raises(FixtureError):
            RecordedRollAssociation(*bad)


def test_all_mock_fixtures_work_without_external_imports():
    for fixture in (two_by_two(), two_by_two(loss=True), canonical_three_vs_three(), variable_three_vs_four()):
        state, token = make(fixture)
        assert state.snapshot().rules_verified is False
        assert not hasattr(state, "database")
        assert state.view_for_controller(token=token)["schema_version"] == "0.1"


def test_approved_effect_with_action_needs_forwarded_state_and_cannot_infer_rules():
    fixture = two_by_two()
    authorised = replace(fixture.approved_effects[0], action_id="approved-intent")
    amended_fixture = replace(fixture, approved_effects=(authorised, fixture.approved_effects[1]))
    state, token = make(amended_fixture)
    state.record_proposal(DeclaredAction("approved-intent", "pc-alpha", "Propose attack",
                                          "mob-1", ProposalStatus.UNVALIDATED), token=token)
    expect_code(FixtureErrorCode.INVALID_ACTION, lambda: state.apply_scripted_effect(authorised, token=token))
    assert state.snapshot().state_version == 0
    forwarded, token = make(amended_fixture, "forwarded")
    forwarded.record_proposal(DeclaredAction("approved-intent", "pc-alpha", "Propose attack",
                                              "mob-1", ProposalStatus.FORWARDED), token=token)
    updated = forwarded.apply_scripted_effect(authorised, token=token)
    assert updated.state_version == 1 and hp(updated) == [7, 5, 1, 4]
    assert updated.pending_actions[0].status is ProposalStatus.FORWARDED
    assert updated.rules_verified is False


def test_undiscovered_opponent_not_leaked_in_player_roster_group_or_zone():
    f = canonical_three_vs_three()
    original_force = f.encounter.opposing_forces[0]
    hidden_orc = replace(original_force.side.members[-1], publicly_visible=False)
    changed_side = replace(original_force.side, members=original_force.side.members[:-1] + (hidden_orc,))
    changed_force = replace(original_force, side=changed_side)
    changed_encounter = replace(f.encounter, opposing_forces=(changed_force,))
    private_fixture = replace(f, encounter=changed_encounter)
    state, token = make(private_fixture)
    assert len(state.view_for_controller(token=token)["actors"]) == 6
    public = state.view_for_player()
    assert len(public["actors"]) == 5
    assert "orc-03" not in json.dumps(public)
    assert "orc-03" in json.dumps(state.view_for_controller(token=token))
    # The public side lists only revealed opponents, without the hidden member ID.
    assert public["sides"][1]["actor_ids"] == ["orc-01", "orc-02"]