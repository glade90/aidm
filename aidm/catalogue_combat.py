"""DES-001.7.9: offline catalogue-to-Combat prototype composition boundary.

The authoritative Encounter service (DES-020) will eventually own this step.
Here the trusted test/bootstrap layer combines an ALREADY RESOLVED, immutable
CombatRosterHandoff with an explicitly authored scene/party template. Neither
CombatEngine nor CombatSessionService opens or even receives a SQL connection.

Usage:
    handoff = build_test_handoff(scenario, catalogue, mechanics_verified_ref="...")
    encounter = prepare_prototype_encounter(handoff, authored_template=fixture.encounter,
                                            mechanics_supported=trusted_rules_checker)
    service = CombatSessionService(prototype_encounter=encounter)

Change Log: 2026-11-26 DAVOS — source-pinned offline Encounter→Combat test bootstrap.
"""
from __future__ import annotations

from dataclasses import replace
import json
from typing import Callable

from aidm.catalogue import CombatMonsterProfile, CombatRosterHandoff, NotPlayable
from aidm.combat.state import (
    CombatSide, EncounterDefinition, MonsterDefinitionSnapshot,
    OpposingForce, Origin,
)


def _fail(message: str) -> None:
    raise NotPlayable(message)


def prepare_prototype_encounter(
    handoff: CombatRosterHandoff,
    *,
    authored_template: EncounterDefinition,
    mechanics_supported: Callable[[CombatMonsterProfile], bool],
) -> EncounterDefinition:
    """Instantiate ONLY a trusted complete roster into a previously authored scene.

    This does not create geometry, grant source approval, interpret special
    attacks, determine surprise, roll HP, equip unspecified weapons or choose a
    party. The caller must have completed test-case, species and mechanics gates
    BEFORE passing the handoff. An explicit trusted rules capability check is
    mandatory even for a basic melee prototype.

    The existing stationary-mêlée CombatEngine is NOT a generic monster-rules
    interpreter; a false capability check must veto unsupported species or
    special abilities rather than silently treating them as ordinary attacks.
    """
    if not isinstance(handoff, CombatRosterHandoff):
        _fail("A trusted resolved combat roster is required")
    if not isinstance(authored_template, EncounterDefinition):
        _fail("An explicit authored encounter template is required")
    if not callable(mechanics_supported):
        _fail("A verified combat rules capability check is required")
    if not handoff.mechanics_verified_ref or not handoff.origin_reference:
        _fail("Source and mechanics approval references required")
    if len(authored_template.opposing_forces) != 1:
        _fail("Prototype supports one authored opposing force")
    if not handoff.actors or not handoff.sources:
        _fail("Empty monster roster")
    try:
        scenario_party = json.loads(handoff.party_roster_json)
        scene_facts = json.loads(handoff.scene_facts_json)
    except (ValueError, TypeError):
        _fail("Invalid resolved scene/party")
    if not isinstance(scenario_party, list) or not isinstance(scene_facts, dict):
        _fail("Invalid resolved scene/party")
    expected_party = {a.encounter_actor_id: a.hp_current
                      for a in authored_template.party.members}
    try:
        supplied_party = {p["actor_id"]: p["hp_start"] for p in scenario_party}
    except (KeyError, TypeError):
        _fail("Incomplete party roster")
    if (len(supplied_party) != len(scenario_party)
            or supplied_party != expected_party
            or any(type(h) is not int or h < 1 for h in supplied_party.values())):
        _fail("Party differs from the approved authored template")
    if scene_facts.get("approved_for_test_bootstrap") is not True:
        _fail("Authored scene not approved for test bootstrap")

    profiles = {p.identity: p for p in handoff.sources}
    if len(profiles) != len(handoff.sources):
        _fail("Duplicate catalogue version in combat handoff")
    for profile in profiles.values():
        if (len(profile.identity) != 3 or not all(profile.identity)
                or type(profile.armor_class) is not int
                or not profile.hit_dice_text or not profile.attack_pattern
                or not profile.damage_pattern or not profile.save_as
                or type(profile.morale) is not int):
            _fail("Incomplete pinned monster mechanics")
        # The current deterministic engine has no generic special-attack
        # executor. Even a mistaken/overbroad callback must not silently
        # treat poison, paralysis, leader bonuses or daylight penalties as
        # vanilla melee. Such sources require the separate rules build.
        if profile.special_attacks_features.strip():
            _fail("Unimplemented monster special feature")
        try:
            supported = mechanics_supported(profile)
        except Exception:
            _fail("Rules capability verification unavailable")
        if supported is not True:
            _fail("Required monster mechanics are not implemented")

    force = authored_template.opposing_forces[0]
    originals = {m.encounter_actor_id: m for m in force.side.members}
    incoming = {a.actor_id: a for a in handoff.actors}
    if len(incoming) != len(handoff.actors) or set(originals) != set(incoming):
        _fail("Authored monster identities do not match source instances")
    by_id = {}
    for actor_id, original in originals.items():
        seed = incoming[actor_id]
        if original.origin is not Origin.CREATURE or seed.starting_hp < 1:
            _fail("Invalid creature instance")
        if seed.role.lower() not in ("ordinary", "standard"):
            _fail("Monster role modifiers need a source-rules implementation")
        profile = profiles.get(seed.source_version)
        if profile is None or seed.species_code != profile.identity[1]:
            _fail("Creature version does not match source profile")
        # The source encounter must explicitly choose a weapon; never infer
        # an item from HD or DamagePattern, even if its rules mention weapons.
        if (not seed.equipment or not original.equipped_items
                or original.equipped_items[0].item_ref != seed.equipment):
            _fail("Authored creature weapon not verified")
        ref = "Rules.Monster:" + ":".join(profile.identity)
        by_id[actor_id] = replace(
            original,
            source_ref=ref,
            hp_current=seed.starting_hp,
            hp_max=seed.starting_hp,
            armor_class_source=profile.armor_class,
            monster_hd_ref=profile.hit_dice_text,
            save_profile_ref=profile.save_as,
            attack_profiles=(profile.attack_pattern,),
            movement_profile_ref=ref + ":movement",
        )

    # Every authored group must contain one versioned species. A mixed group
    # requires a separately designed/validated encounter, not arbitrary
    # constructor side effects or a new morale mechanic.
    groups = []
    for group in force.groups:
        group_sources = {by_id[actor_id].source_ref for actor_id in group.member_actor_ids}
        if len(group_sources) != 1:
            _fail("Mixed species/version within an authored monster group")
        ref = next(iter(group_sources))
        source = next(p for p in profiles.values()
                      if ref == "Rules.Monster:" + ":".join(p.identity))
        groups.append(replace(group, monster_definition_ref=ref, morale_rating=source.morale))

    definitions = tuple(
        MonsterDefinitionSnapshot(
            "Rules.Monster:" + ":".join(p.identity),
            p.armor_class,
            p.hit_dice_text,
            p.attack_pattern,
            p.damage_pattern,
            "Source version pinned; movement not interpreted",
            p.save_as,
            p.morale,
            provenance="Rules.Monster:" + ":".join(p.identity)
                       + ";mechanics:" + handoff.mechanics_verified_ref,
        )
        for p in profiles.values()
    )
    members = tuple(by_id[m.encounter_actor_id] for m in force.side.members)
    new_force = OpposingForce(
        force.force_id,
        CombatSide(force.side.side_id, force.side.label, members,
                   default_controller=force.side.default_controller),
        tuple(groups),
    )
    return replace(authored_template, opposing_forces=(new_force,),
                   monster_definitions=definitions)
