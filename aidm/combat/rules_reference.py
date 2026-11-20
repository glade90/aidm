"""DES-001.2 bounded prototype reference provider (TD-AIDM-DATA-001).

Only source-backed low-level melee inputs needed by the owner 3v3 scenario are
represented. Not a transcribed rules table, full ruleset, or persistent DB.
Swap ReferenceProvider for a governed repository in a later Story.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .state import Combatant, Origin

FLAIL_RULE = "HR-WEAPON-FLAIL-001"
BASE_RULES = "mentzer-basic-1983"


class UnsupportedRule(ValueError):
    """Necessary game rule, equipment fact or verified profile is unavailable."""


@dataclass(frozen=True, slots=True)
class WeaponRule:
    weapon_id: str
    sides: int
    rule_id: str
    rule_version: str
    origin: str


@dataclass(frozen=True, slots=True)
class ModifierContribution:
    source_id: str
    operation: str
    amount: int
    rule_id: str


@dataclass(frozen=True, slots=True)
class RuleProfile:
    """A versioned MELEE fixture subset, not full Mentzer-compliant combat."""

    profile_id: str = "prototype.mentzer-basic-1983.melee.v1"
    base_rules: str = BASE_RULES
    house_rule_overlays: tuple[str, ...] = ()
    morale_enabled: bool = False
    missile_enabled: bool = False
    magic_enabled: bool = False
    stationary_fixture: bool = True
    # Provisional equipment is used only when the owner explicitly authorises
    # the fixture loadout, never as a correction to persistent character data.
    fixture_loadout_confirmed: bool = False

    def __post_init__(self) -> None:
        if self.base_rules != BASE_RULES or not self.profile_id or self.profile_id.startswith(" "):
            raise UnsupportedRule("Unsupported rules profile")
        if len(self.house_rule_overlays) != len(set(self.house_rule_overlays)):
            raise UnsupportedRule("Duplicate house-rule overlay")
        if any(type(v) is not bool for v in (self.morale_enabled, self.missile_enabled,
                                             self.magic_enabled, self.stationary_fixture,
                                             self.fixture_loadout_confirmed)):
            raise UnsupportedRule("Invalid rule flag")


class ReferenceProvider(Protocol):
    def weapon(self, weapon_id: str, profile: RuleProfile) -> WeaponRule: ...
    def attack_target(self, actor: Combatant, defender_ac: int) -> tuple[int, str]: ...
    def effective_ac(self, defender: Combatant, profile: RuleProfile) -> tuple[int, tuple[ModifierContribution, ...]]: ...
    def strength_modifier(self, actor: Combatant, operation: str) -> ModifierContribution: ...


class PrototypeReferenceProvider:
    """One isolated replacement seam for approved source-labelled literals.

    This limited 1st-level/1-HD target relation is calibrated to the 1983
    Mentzer Basic low-level hit chart (player sheet/printed p.36):
    level-1 CHARACTER against AC9 needs 11, while up-to-1HD MONSTER needs 10;
    each lower descending AC adds one to the required hit roll.
    Other levels, bonuses, negative AC, special protections, other profiles
    and saves are deliberately unsupported rather than extrapolated.
    """

    _weapons = {
        "longsword": WeaponRule("longsword", 8, "BASIC83-WEAPON-VARIABLE", "1983", "BASE_RULES"),
        "handaxe": WeaponRule("handaxe", 6, "BASIC83-WEAPON-VARIABLE", "1983", "BASE_RULES"),
        "shortsword": WeaponRule("shortsword", 6, "BASIC83-WEAPON-VARIABLE", "1983", "BASE_RULES"),
    }
    _supported_classes = frozenset(("human.fighter.1", "halfling.1"))
    _supported_hd = frozenset(("owner.HD1",))

    def weapon(self, weapon_id: str, profile: RuleProfile) -> WeaponRule:
        if weapon_id == "flail":
            if FLAIL_RULE not in profile.house_rule_overlays:
                raise UnsupportedRule("Flail requires approved HR-WEAPON-FLAIL-001 overlay")
            return WeaponRule("flail", 6, FLAIL_RULE, "1.0", "OWNER_APPROVED_HOUSE_RULE")
        try:
            return self._weapons[weapon_id]
        except KeyError:
            raise UnsupportedRule("Weapon profile not implemented") from None

    def strength_modifier(self, actor: Combatant, operation: str) -> ModifierContribution:
        if operation not in ("MELEE_TO_HIT", "MELEE_DAMAGE"):
            raise UnsupportedRule("Unsupported ability modifier operation")
        values = {x.name: x.source_value for x in actor.ability_scores}
        for override in actor.scenario_overrides:
            if override.field_name == "STR":
                values["STR"] = override.scenario_value
        if actor.origin is Origin.CREATURE:
            return ModifierContribution(actor.source_ref, operation, 0, "MONSTER_NO_CHARACTER_STR")
        strength = values.get("STR")
        if type(strength) is not int or not 3 <= strength <= 18:
            raise UnsupportedRule("Unverified or missing Strength value")
        # 1983 Basic ability adjustment reference. First-slice only.
        amount = -3 if strength == 3 else -2 if strength <= 5 else -1 if strength <= 8 else 0 if strength <= 12 else 1 if strength <= 15 else 2 if strength <= 17 else 3
        return ModifierContribution("SCENARIO_OVERRIDE" if any(x.field_name == "STR" for x in actor.scenario_overrides)
                                    else actor.source_ref, operation, amount, "BASIC83-STR-MELEE")

    def effective_ac(self, defender: Combatant, profile: RuleProfile) -> tuple[int, tuple[ModifierContribution, ...]]:
        if defender.armor_class_source is not None:
            return defender.armor_class_source, (ModifierContribution(defender.source_ref, "ARMOR_CLASS", 0, "OWNER_SOURCE_AC"),)
        items = {x.item_ref: x for x in defender.equipped_items}
        if "plate" not in items or not profile.fixture_loadout_confirmed:
            raise UnsupportedRule("Effective defender AC requires verified or fixture-authorised loadout")
        shield_ids = {"ordinary-shield", "plus-one-shield"}.intersection(items)
        if len(shield_ids) > 1:
            raise UnsupportedRule("Ambiguous mutually-exclusive equipped shields")
        entries = [ModifierContribution("plate", "ARMOR_CLASS", 3, "BASIC83-PLATE-BASE-AC")]
        if "ordinary-shield" in shield_ids:
            entries.append(ModifierContribution("ordinary-shield", "ARMOR_CLASS", -1, "BASIC83-SHIELD"))
        if "plus-one-shield" in shield_ids:
            entries.append(ModifierContribution("plus-one-shield", "ARMOR_CLASS", -1, "BASIC83-SHIELD"))
            entries.append(ModifierContribution("plus-one-shield:enchanted", "ARMOR_CLASS", -1, "OWNER-MAGIC-SHIELD-PLUS-ONE"))
        ac = sum(x.amount for x in entries)
        return ac, tuple(entries)

    def attack_target(self, actor: Combatant, defender_ac: int) -> tuple[int, str]:
        if type(defender_ac) is not int or not 0 <= defender_ac <= 9:
            raise UnsupportedRule("This source-verified first slice supports defender AC 0..9 only")
        if actor.origin is Origin.CREATURE:
            if actor.monster_hd_ref not in self._supported_hd:
                raise UnsupportedRule("Unsupported monster hit-dice attack band")
            rule_id = "BASIC83-MONSTER-HD1-ATTACK"
            base_at_ac9 = 10
        elif actor.class_level_ref in self._supported_classes:
            rule_id = "BASIC83-CHARACTER-LEVEL1-ATTACK"
            base_at_ac9 = 11
        else:
            raise UnsupportedRule("Unsupported character class/level attack band")
        return base_at_ac9 + (9 - defender_ac), rule_id