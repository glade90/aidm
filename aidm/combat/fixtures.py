"""AIDM-DES-006.2 original mock fixtures and approved source-labelled 3-v-3.

Usage: fixture = canonical_three_vs_three()
Change Log: 2026-11-20 COSTA — immutable 2x2/3x3/variable-roster fixtures.

Only original and owner-authorised factual inputs are used. Not B1 module
content or verified 1983 Basic game mechanics. All effects are TEST SCRIPTED.
"""
from __future__ import annotations

from .state import (
    AbilityValue, ActorHPChange, ActorPlacement, ApprovedFixtureEffect,
    AreaRef, BattlegroundDefinition, Combatant, CombatSide, Controller,
    EncounterDefinition, EncounterParty, EquipmentRef, FixtureDefinition,
    FixtureOutcome, MeleeEligibility, MonsterDefinitionSnapshot, MonsterGroup,
    OpposingForce, Origin, PositionRef, ScenarioOverride, Visibility, ZoneRelation,
)


_RULES_REF = "base.mentzer1983.unverified-synthetic"
_ORC_REF = "owner.orc.2026-11-20"


def two_by_two(*, loss: bool = False) -> FixtureDefinition:
    """Small original HP regression: two rounds of SCRIPTED victory or defeat."""
    players = (
        Combatant("pc-alpha", "Fictional Alpha", "party", Origin.CHARACTER,
                  "synthetic.pc-alpha", Controller.HUMAN, 7, 7, armor_class_source=9),
        Combatant("pc-beta", "Fictional Beta", "party", Origin.CHARACTER,
                  "synthetic.pc-beta", Controller.HUMAN, 6, 6, armor_class_source=9),
    )
    mobs = (
        Combatant("mob-1", "Fictional Monster One", "opponents", Origin.CREATURE,
                  "synthetic.monster", Controller.SCRIPTED, 3, 3,
                  group_id="group-g", armor_class_source=6, hidden_traits=("SCRIPTED_HIDDEN",),
                  publicly_visible=True),
        Combatant("mob-2", "Fictional Monster Two", "opponents", Origin.CREATURE,
                  "synthetic.monster", Controller.SCRIPTED, 4, 4,
                  group_id="group-g", armor_class_source=6, publicly_visible=True),
    )
    party = EncounterParty("fixture-party", CombatSide("party", "PARTY", players))
    opposing = OpposingForce("fixture-foe-force", CombatSide("opponents", "OPPONENTS", mobs,
                                                            default_controller=Controller.SCRIPTED),
                            (MonsterGroup("group-g", ("mob-1", "mob-2"), "synthetic.monster"),))
    area = BattlegroundDefinition(
        AreaRef("synthetic-abstract-room", ("near-entry", "far-side")),
        (ActorPlacement("pc-alpha", PositionRef("near-entry")),
         ActorPlacement("pc-beta", PositionRef("near-entry")),
         ActorPlacement("mob-1", PositionRef("far-side")),
         ActorPlacement("mob-2", PositionRef("far-side"))),
        (ZoneRelation("near-entry", "far-side", 20, Visibility.UNKNOWN),),
    )
    encounter = EncounterDefinition(
        "synthetic-encounter-2x2", party, (opposing,), area, _RULES_REF,
        house_rule_overlay_refs=("synthetic.mock-script-only",),
        monster_definitions=(MonsterDefinitionSnapshot("synthetic.monster", 6, "synthetic", "synthetic",
                                                      "synthetic", "synthetic", "synthetic", 8),),
    )
    if loss:
        rounds = ((("pc-alpha", 7, 3), ("pc-beta", 6, 2)),
                  (("pc-alpha", 3, 0), ("pc-beta", 2, 0)))
        terminal = FixtureOutcome.PARTY_DEFEAT
    else:
        rounds = ((("pc-beta", 6, 5), ("mob-1", 3, 1)),
                  (("pc-alpha", 7, 4), ("mob-1", 1, 0), ("mob-2", 4, 0)))
        terminal = FixtureOutcome.PARTY_VICTORY
    effects = tuple(
        ApprovedFixtureEffect(f"scripted-{('loss' if loss else 'win')}-round-{i + 1}", i,
                              tuple(ActorHPChange(*entry) for entry in entries), i + 2,
                              terminal if i == 1 else FixtureOutcome.ONGOING)
        for i, entries in enumerate(rounds)
    )
    return FixtureDefinition("synthetic-2x2-loss-v1" if loss else "synthetic-2x2-win-v1", encounter, effects)


def _abilities(strength: int, intelligence: int, wisdom: int, constitution: int,
               dexterity: int, charisma: int) -> tuple[AbilityValue, ...]:
    return tuple(AbilityValue(n, v) for n, v in zip(
        ("STR", "INT", "WIS", "CON", "DEX", "CHA"),
        (strength, intelligence, wisdom, constitution, dexterity, charisma), strict=True))


def canonical_three_vs_three() -> FixtureDefinition:
    """Owner-specified 3 adventurers vs 3 orcs; PURE FIXTURE, no hit rules."""
    party_side_id, foe_side_id, group = "party-3v3", "orcs-side", "orc-group-01"
    players = (
        Combatant("alho", "Alho", party_side_id, Origin.CHARACTER, "owner.character.alho",
                  Controller.HUMAN, 8, 8, class_level_ref="human.fighter.1",
                  ability_scores=_abilities(12, 10, 9, 11, 12, 12),
                  equipped_items=(EquipmentRef("flail", "Flail", "owner.scenario.weapon",
                                               "UNRESOLVED_HOUSE_RULE"),),
                  attack_profiles=("flail.damage.UNRESOLVED",)),
        Combatant("evro", "Evro", party_side_id, Origin.CHARACTER, "owner.character.evro",
                  Controller.AGENT, 8, 8, class_level_ref="human.fighter.1",
                  ability_scores=_abilities(16, 9, 16, 12, 11, 9),
                  scenario_overrides=(ScenarioOverride("STR", 16, 18, "owner.directive.2026-11-20"),),
                  equipped_items=(EquipmentRef("longsword", "Longsword", "owner.scenario.weapon",
                                               "CANDIDATE_UNVERIFIED", "1d8"),
                                  EquipmentRef("plate", "Plate mail", "owner.narrative.provisional", "PROVISIONAL"),
                                  EquipmentRef("ordinary-shield", "Ordinary shield", "owner.narrative.provisional", "PROVISIONAL")),
                  attack_profiles=("longsword.candidate",)),
        Combatant("sho-rembo", "Sho-Rembo", party_side_id, Origin.CHARACTER, "owner.character.sho-rembo",
                  Controller.HUMAN, 9, 9, class_level_ref="halfling.1",
                  ability_scores=_abilities(9, 11, 9, 18, 9, 15),
                  equipped_items=(EquipmentRef("handaxe", "Handaxe", "owner.scenario.weapon",
                                               "CANDIDATE_UNVERIFIED", "1d6"),
                                  EquipmentRef("plate", "Plate mail", "owner.narrative.provisional", "PROVISIONAL"),
                                  EquipmentRef("plus-one-shield", "+1 shield", "owner.narrative", "PROVISIONAL")),
                  attack_profiles=("handaxe.candidate",)),
    )
    orcs = tuple(Combatant(
        f"orc-{i:02d}", f"Orc {i}", foe_side_id, Origin.CREATURE, _ORC_REF,
        Controller.AGENT, hp, hp, group_id=group, armor_class_source=6,
        monster_hd_ref="owner.HD1", save_profile_ref="owner.SaveF1",
        equipped_items=(EquipmentRef("shortsword", "Short sword", "owner.orc.weapon",
                                     "CANDIDATE_UNVERIFIED", "1d6"),),
        attack_profiles=("owner.orc.one-attack",), movement_profile_ref="owner.orc.MV90-30",
        hidden_traits=("UNREVEALED_CREATURE_TRAITS",), publicly_visible=True
    ) for i, hp in enumerate((6, 4, 3), start=1))
    party = EncounterParty("owner-party-fixture", CombatSide(party_side_id, "PARTY", players))
    opposing = OpposingForce("owner-orc-force", CombatSide(foe_side_id, "OPPONENTS", orcs,
                                                         default_controller=Controller.AGENT),
                            (MonsterGroup(group, tuple(o.encounter_actor_id for o in orcs), _ORC_REF, 8),))
    battleground = BattlegroundDefinition(
        AreaRef("synthetic-melee-arena", ("central-melee", "outer-entry")),
        tuple(ActorPlacement(actor.encounter_actor_id, PositionRef("central-melee"))
              for actor in (*players, *orcs)),
        melee_relations=tuple(MeleeEligibility(player.encounter_actor_id, foe.encounter_actor_id, True)
                              for player in players for foe in orcs),
    )
    source_def = MonsterDefinitionSnapshot(_ORC_REF, 6, "1", "1", "1d6 or by weapon",
                                           "90'(30')", "F1", 8)
    encounter = EncounterDefinition("owner-canonical-3v3-synthetic", party, (opposing,), battleground,
                                   _RULES_REF, ("owner.house-overlays.not-selected",), (source_def,))
    return FixtureDefinition("owner-canonical-3v3-fixture-v1", encounter)


def variable_three_vs_four() -> FixtureDefinition:
    """F13–F17 structure: 3 party/4 creatures in 2 groups, 3 explicit zones."""
    raw = canonical_three_vs_three()
    source = raw.encounter
    party = source.party
    foes = list(source.opposing_forces[0].side.members)
    extra = Combatant("orc-04", "Orc 4", "orcs-side", Origin.CREATURE, _ORC_REF,
                      Controller.SCRIPTED, 5, 5, group_id="orc-group-02", armor_class_source=6, publicly_visible=True)
    # Recreate only the group memberships; previous orcs preserve instance IDs.
    from dataclasses import replace
    foes[2] = replace(foes[2], group_id="orc-group-02")
    foe_side = CombatSide("orcs-side", "OPPONENTS", tuple((*foes, extra)), default_controller=Controller.AGENT)
    opposing = OpposingForce("variable-foe-force", foe_side,
                            (MonsterGroup("orc-group-01", ("orc-01", "orc-02"), _ORC_REF, 8),
                             MonsterGroup("orc-group-02", ("orc-03", "orc-04"), _ORC_REF, 8)))
    area = BattlegroundDefinition(AreaRef("three-zone-arena", ("entry", "middle", "back")),
                                  tuple(ActorPlacement(a.encounter_actor_id, PositionRef(
                                      "entry" if a.side_id == "party-3v3" else ("back" if a.group_id == "orc-group-02" else "middle")))
                                        for a in (*party.members, *foe_side.members)))
    encounter = EncounterDefinition("variable-3x4-encounter", party, (opposing,), area,
                                   _RULES_REF, monster_definitions=source.monster_definitions)
    return FixtureDefinition("variable-3x4-fixture", encounter)