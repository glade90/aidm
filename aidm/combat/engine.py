"""AIDM-DES-001.2 deterministic prototype combat controller, no LLM/DB.

COSTA implementation against BON AIDM-CMB-SEQ-001 §§7-14 WORKING DESIGN:
formal design/UAT and ALEK Sprint rebaseline remain independent gates.
Supported: owner-configured 2-side, level-1/HD1 stationary melee fixture.
All other phases are logged truthfully disabled or blocked, never faked.
"""
from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass, replace
from enum import Enum
import json
from pathlib import Path
import re
from threading import RLock
from types import MappingProxyType
from typing import Any, Mapping

from .dice import (Die, DiceRoller, RawDieResult, FixedRollsExhausted,
                   FixedRollOutOfRange, InvalidRollSource)
from .rules_reference import (
    FLAIL_RULE, ModifierContribution, PrototypeReferenceProvider,
    ReferenceProvider, RuleProfile, UnsupportedRule,
)
from .state import Combatant, Controller, EncounterDefinition, FixtureDefinition


class CombatError(ValueError):
    """Non-mutating unsafe/invalid combat request; never leaks private details."""


class CombatStatus(str, Enum):
    READY = "READY"
    NEEDS_PLAYER_INPUT = "NEEDS_PLAYER_INPUT"
    NEEDS_AGENT_INPUT = "NEEDS_AGENT_INPUT"
    NEEDS_RULING = "NEEDS_RULING"
    TERMINAL = "TERMINAL"


class SurpriseKind(str, Enum):
    NONE = "NONE"
    SURPRISING_SIDE = "SURPRISING_SIDE"


class Phase(str, Enum):
    PRE_INITIATIVE = "PRE_INITIATIVE"
    INITIATIVE = "INITIATIVE"
    MORALE = "MONSTER_NPC_MORALE"
    MOVEMENT = "MOVEMENT"
    MISSILE = "MISSILE"
    MAGIC = "MAGIC"
    MELEE = "MELEE"
    DM_END = "DM_SPECIAL_END"


@dataclass(frozen=True, slots=True)
class SurpriseResult:
    kind: SurpriseKind
    encounter_id: str
    resolved_by: str
    source_event_id: str
    rules_profile_ref: str
    surprising_side_id: str | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.kind, SurpriseKind) or self.resolved_by != "ENCOUNTER_AGENT":
            raise CombatError("Trusted, resolved Encounter Agent surprise result required")
        if not all(isinstance(x, str) and x.strip() for x in
                   (self.encounter_id, self.source_event_id, self.rules_profile_ref)):
            raise CombatError("Missing surprise provenance")
        if (self.kind is SurpriseKind.NONE and self.surprising_side_id is not None) or (self.kind is SurpriseKind.SURPRISING_SIDE and not self.surprising_side_id):
            raise CombatError("Contradictory surprise result")


@dataclass(frozen=True, slots=True)
class DiceKit:
    """Explicit selected dice, copied into immutable fixture mappings."""
    initiative: Mapping[str, Die]
    attack: Mapping[str, Die]
    damage: Mapping[str, Die]

    def __post_init__(self) -> None:
        for field in ("initiative", "attack", "damage"):
            selected = getattr(self, field)
            if not isinstance(selected, Mapping) or any(
                not isinstance(key, str) or not isinstance(die, Die)
                for key, die in selected.items()
            ):
                raise CombatError("Dice kit requires explicit selected Die objects")
            object.__setattr__(self, field, MappingProxyType(dict(selected)))


@dataclass(frozen=True, slots=True)
class Decision:
    session_id: str
    encounter_id: str
    actor_id: str
    side_id: str
    round_index: int
    version: int
    token: str
    allowed_targets: tuple[str, ...]
    status: CombatStatus


@dataclass(frozen=True, slots=True)
class CombatCommand:
    command_id: str
    session_id: str
    actor_id: str
    expected_version: int
    decision_token: str
    kind: str
    target_id: str | None = None


@dataclass(frozen=True, slots=True)
class CombatEvent:
    seq: int
    encounter_id: str
    session_id: str
    round_index: int
    phase: str
    kind: str
    side_id: str | None
    actor_id: str | None
    state_version_before: int
    state_version_after: int
    details: dict[str, Any]
    public_message: str | None


class CombatEngine:
    """Single in-memory working state, synchronous test-harness command boundary.

    Not a replacement for the future authoritative Bookkeeper. Caller is a
    trusted orchestrator, not an untrusted direct HTTP/player write endpoint.
    The owner accepted separate permanent event/Bookkeeper implementations.
    """

    def __init__(self, definition: EncounterDefinition | FixtureDefinition, *,
                 surprise: SurpriseResult, roller: DiceRoller, dice: DiceKit,
                 profile: RuleProfile, session_id: str,
                 provider: ReferenceProvider | None = None) -> None:
        if not isinstance(surprise, SurpriseResult):
            raise CombatError("Resolved surprise input is required")
        definition = definition.encounter if isinstance(definition, FixtureDefinition) else definition
        if not isinstance(definition, EncounterDefinition) or len(definition.sides) != 2:
            raise CombatError("This first combat slice requires exactly two validated sides")
        if surprise.encounter_id != definition.encounter_id or surprise.rules_profile_ref != profile.profile_id:
            raise CombatError("Surprise/encounter/rules-profile mismatch")
        side_ids = tuple(s.side_id for s in definition.sides)
        if surprise.kind is SurpriseKind.SURPRISING_SIDE and surprise.surprising_side_id not in side_ids:
            raise CombatError("Unknown surprising side")
        if not isinstance(roller, DiceRoller) or not isinstance(dice, DiceKit) or not isinstance(profile, RuleProfile):
            raise CombatError("Explicit injected roller, dice kit and rules profile required")
        if not isinstance(session_id, str) or re.fullmatch(r"[A-Za-z0-9][\w.:-]{0,127}", session_id) is None:
            raise CombatError("Invalid combat session ID")
        for side in definition.sides:
            if side.side_id not in dice.initiative or dice.initiative[side.side_id].sides != 6:
                raise CombatError("Every side needs a selected d6")
        for actor in definition.members:
            if actor.encounter_actor_id not in dice.attack or dice.attack[actor.encounter_actor_id].sides != 20:
                raise CombatError("Every actor needs a selected d20")
            if actor.encounter_actor_id not in dice.damage or not isinstance(dice.damage[actor.encounter_actor_id], Die):
                raise CombatError("Every actor needs an explicit selected damage die")
        self.definition = definition
        self.surprise = surprise
        self.roller = roller
        self.dice = dice
        self.profile = profile
        self.session_id = session_id
        self.provider = provider if provider is not None else PrototypeReferenceProvider()
        self._actors = {a.encounter_actor_id: a for a in definition.members}
        self._side_ids = side_ids
        self._party = definition.party.side.side_id
        self._hp = {a.encounter_actor_id: a.hp_current for a in definition.members}
        self._version = 0
        self._round = 1
        self._events: list[CombatEvent] = []
        self._pending: Decision | None = None
        self._queue: list[str] = []
        self._queue_index = 0
        self._side_order: list[str] = []
        self._side_index = 0
        self._processed_ids: set[str] = set()
        self._outcome: str | None = None
        self._blocked_reason: str | None = None
        self._opening = surprise.kind is SurpriseKind.SURPRISING_SIDE
        self._round_started = False
        self._simultaneous = False
        self._simultaneous_effects: list[dict[str, Any]] = []
        self._morale_triggers: set[tuple[str, str]] = set()
        self._lock = RLock()
        self._append(Phase.PRE_INITIATIVE, "SURPRISE_INPUT_ACCEPTED", None, None,
                     {"kind": surprise.kind.value, "source_event_id": surprise.source_event_id,
                      "resolved_by": surprise.resolved_by, "surprising_side_id": surprise.surprising_side_id,
                      "rules_profile_ref": profile.profile_id,
                      "house_rule_overlays": list(profile.house_rule_overlays)})

    @property
    def version(self) -> int:
        return self._version

    @property
    def round_index(self) -> int:
        return self._round

    @property
    def outcome(self) -> str | None:
        return self._outcome

    def _append(self, phase: Phase, kind: str, side: str | None, actor: str | None,
                details: dict[str, Any], public_message: str | None = None,
                *, before: int | None = None) -> None:
        self._events.append(CombatEvent(len(self._events) + 1, self.definition.encounter_id,
                                        self.session_id, self._round, phase.value, kind,
                                        side, actor, self._version if before is None else before,
                                        self._version, deepcopy(details), public_message))

    def journal(self) -> tuple[CombatEvent, ...]:
        """Defensive immutable-order copy; event details are not writable aliases."""
        with self._lock:
            return tuple(deepcopy(self._events))

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {"encounter_id": self.definition.encounter_id, "session_id": self.session_id,
                    "version": self._version, "round_index": self._round,
                    "hp": dict(self._hp), "outcome": self._outcome,
                    "simultaneous_exchange_pending": self._simultaneous,
                    "pending_actor": self._pending.actor_id if self._pending else None,
                    "status": self.status().value,
                    "rules_profile_ref": self.profile.profile_id,
                    "house_rule_overlays": list(self.profile.house_rule_overlays)}

    def status(self) -> CombatStatus:
        if self._outcome is not None:
            return CombatStatus.TERMINAL
        if self._blocked_reason is not None:
            return CombatStatus.NEEDS_RULING
        if self._pending is not None:
            return self._pending.status
        # An initial caller must drive next_decision(); no automatic writes.
        return CombatStatus.READY

    def _phase(self, side: str, phase: Phase) -> None:
        if phase in (Phase.MISSILE, Phase.MAGIC) and getattr(self.profile, phase.value.lower() + "_enabled", False):
            self._blocked_reason = f"{phase.value} enabled but its mechanics are not implemented"
            self._append(phase, "PHASE_CHECKPOINT", side, None,
                         {"status": "BLOCKED_UNIMPLEMENTED", "reason": self._blocked_reason})
            return
        if phase is Phase.MORALE:
            label = "SCENARIO_RULE_DISABLED" if not self.profile.morale_enabled else "NOT_DUE"
        elif phase in (Phase.MISSILE, Phase.MAGIC):
            label = "SCENARIO_RULE_DISABLED"
        elif phase is Phase.MOVEMENT:
            label = "STATIONARY_SCENARIO" if self.profile.stationary_fixture else "BLOCKED_UNIMPLEMENTED"
            if not self.profile.stationary_fixture:
                self._blocked_reason = "Movement rules not implemented"
        else:
            label = "READY_MELEE"
        self._append(phase, "PHASE_CHECKPOINT", side, None, {"status": label})

    def _setup_round(self) -> None:
        if self._round_started:
            return
        self._append(Phase.PRE_INITIATIVE, "ROUND_STARTED", None, None,
                     {"surprise_opening": self._opening, "declarations": "NONE_IN_STATIONARY_FIXTURE"},
                     f"Round {self._round} begins")
        if self._opening:
            order = [self.surprise.surprising_side_id]
            self._append(Phase.PRE_INITIATIVE, "SURPRISE_OPENING_ROUND_STARTED", order[0], None,
                         {"ordinary_initiative_consumed": False})
        else:
            sides = self.definition.sides
            # Two-sided mixed dice operation is atomic for fixed preflight.
            try:
                drawn = self.roller.roll_many([self.dice.initiative[s.side_id] for s in sides],
                                              roll_group_id=f"{self.session_id}.r{self._round}.initiative")
            except (FixedRollsExhausted, FixedRollOutOfRange, InvalidRollSource):
                self._blocked_reason = "Side-initiative dice are unavailable or invalid"
                self._append(Phase.INITIATIVE, "INITIATIVE_SOURCE_UNAVAILABLE", None, None,
                             {"status": "BLOCKED", "reason": self._blocked_reason})
                self._round_started = True
                return
            raw = tuple(replace(r, roll_id=f"{self.session_id}:r{self._round}:init:{side.side_id}")
                        for side, r in zip(sides, drawn))
            values = {s.side_id: r.face for s, r in zip(sides, raw)}
            self._append(Phase.INITIATIVE, "SIDE_INITIATIVE", None, None,
                         {"rolls": [self._raw(r) for r in raw], "faces_by_side": values,
                          "rule_id": "CMB-INIT-MENTZER-1983"},
                         f"Round {self._round}: side initiative rolled")
            if raw[0].face == raw[1].face:
                # Intents/rolls are acquired in stable side order for a reproducible
                # UI cursor, but NO damage or incapacitation takes effect until
                # BOTH sides have completed the simultaneous exchange.
                self._simultaneous = True
                order = [s.side_id for s in sides]
                self._append(Phase.INITIATIVE, "SIMULTANEOUS_EXCHANGE_STARTED", None, None,
                             {"simultaneous": True, "sides": order,
                              "rule_id": "CMB-INIT-MENTZER-1983", "no_side_wins": True})
            else:
                order = [sides[0].side_id, sides[1].side_id] if raw[0].face > raw[1].face else [sides[1].side_id, sides[0].side_id]
        self._side_order = order
        self._side_index = 0
        self._round_started = True

    def _begin_side_turn(self) -> bool:
        if self._side_index >= len(self._side_order):
            return False
        side_id = self._side_order[self._side_index]
        self._side_index += 1
        for phase in (Phase.MORALE, Phase.MOVEMENT, Phase.MISSILE, Phase.MAGIC, Phase.MELEE):
            self._phase(side_id, phase)
            if self._blocked_reason:
                return False
        side = next(s for s in self.definition.sides if s.side_id == side_id)
        self._queue = [a.encounter_actor_id for a in side.members]
        self._queue_index = 0
        return True

    @staticmethod
    def _raw(roll: RawDieResult) -> dict[str, Any]:
        return {"roll_id": roll.roll_id, "die_id": roll.die_id, "sides": roll.sides,
                "face": roll.face, "source": roll.source.value,
                "queue_position": roll.queue_position, "correlation_id": roll.correlation_id}

    def _check_outcome(self) -> None:
        party_alive = any(self._hp[a.encounter_actor_id] > 0 for a in self.definition.party.members)
        foes_alive = any(self._hp[a.encounter_actor_id] > 0 for s in self.definition.sides[1:]
                         for a in s.members)
        if not foes_alive or not party_alive:
            self._outcome = "PARTY_VICTORY" if party_alive else "PARTY_DEFEAT" if foes_alive else "UNRESOLVED_MUTUAL_DEFEAT"
            self._append(Phase.DM_END, "ENCOUNTER_TERMINAL", None, None,
                         {"outcome": self._outcome, "rule_id": "FIXTURE_END_ALL_INCAPACITATED"},
                         f"Combat ends: {self._outcome}")

    def _next_round(self) -> None:
        self._append(Phase.DM_END, "ROUND_COMPLETED", None, None,
                     {"status": "NO_UNVERIFIED_SPECIAL_OUTCOME"}, f"Round {self._round} ends")
        if self._opening:
            self._append(Phase.PRE_INITIATIVE, "SURPRISE_OPENING_ROUND_COMPLETED",
                         self.surprise.surprising_side_id, None, {"consumed_once": True})
        self._opening = False
        self._round += 1
        self._round_started = False
        self._queue = []
        self._queue_index = 0
        self._side_order = []
        self._side_index = 0
        self._simultaneous = False
        self._simultaneous_effects = []

    def _resolve_simultaneous(self) -> None:
        """Apply all valid tied-side actions against a single pre-effect HP state.

        Stable decision acquisition order is NOT a combat initiative order.
        A combatant alive when the exchange began gets its eligible attack even
        if the other side's staged attack would incapacitate it. All HP deltas
        commit together after both sides have supplied their commands.
        """
        if not self._simultaneous:
            return
        effects = self._simultaneous_effects
        start_hp = dict(self._hp)
        totals: dict[str, int] = {}
        for effect in effects:
            if effect["kind"] == "ATTACK_MELEE":
                target = effect["target_id"]
                totals[target] = totals.get(target, 0) + effect["damage"]
        after_hp = dict(start_hp)
        for target, damage in totals.items():
            after_hp[target] = max(0, start_hp[target] - damage)
        before_version = self._version
        self._version += 1
        self._hp = after_hp
        for effect in effects:
            actor_id = effect["actor_id"]
            actor = self._actors[actor_id]
            if effect["kind"] == "ATTACK_MELEE":
                target = effect["target_id"]
                details = dict(effect["details"])
                details.update(hp_before=start_hp[target], hp_after=after_hp[target],
                               simultaneous=True, aggregate_damage=totals[target],
                               resolution="ONE_SIMULTANEOUS_HP_COMMIT")
                self._append(Phase.MELEE, "MELEE_RESOLVED", actor.side_id, actor_id,
                             details, effect["public_message"], before=before_version)
            else:
                self._append(Phase.MELEE, "ACTION_HELD", actor.side_id, actor_id,
                             {"command_id": effect["command_id"], "status": "NO_ATTACK",
                              "simultaneous": True}, effect["public_message"],
                             before=before_version)
        self._append(Phase.MELEE, "SIMULTANEOUS_EXCHANGE_COMMITTED", None, None,
                     {"simultaneous": True, "action_count": len(effects),
                      "state_version_before": before_version,
                      "state_version_after": self._version,
                      "hp_deltas": {target: after_hp[target] - start_hp[target]
                                    for target in sorted(totals)},
                      "all_eligible_actions_resolved": True},
                     f"Round {self._round} simultaneous exchange resolves",
                     before=before_version)
        self._simultaneous = False
        self._simultaneous_effects = []
        for actor_id in self._actors:
            if start_hp[actor_id] > 0 and after_hp[actor_id] == 0:
                self._morale_after_death(actor_id)
        # The caller checks the terminal outcome exactly once after this batch.

    def next_decision(self) -> Decision | None:
        """Stop at exact actor turn; caller supplies human or agent intent.

        This method never selects an action, rolls attack/damage, or changes HP.
        """
        with self._lock:
            if self._outcome or self._blocked_reason:
                return None
            if self._pending:
                return self._pending
            self._check_outcome()
            if self._outcome:
                return None
            while True:
                if not self._round_started:
                    self._setup_round()
                    if self._blocked_reason:
                        return None
                if self._queue_index >= len(self._queue):
                    if not self._begin_side_turn():
                        if self._blocked_reason:
                            return None
                        if self._simultaneous:
                            self._resolve_simultaneous()
                            if self._blocked_reason:
                                return None
                        self._check_outcome()
                        if self._outcome:
                            return None
                        self._next_round()
                        continue
                while self._queue_index < len(self._queue):
                    actor_id = self._queue[self._queue_index]
                    self._queue_index += 1
                    if self._hp[actor_id] <= 0:
                        self._append(Phase.MELEE, "INCAPACITATED_SKIP", self._actors[actor_id].side_id,
                                     actor_id, {"reason": "HP_ZERO"})
                        continue
                    actor = self._actors[actor_id]
                    eligible = tuple(target.encounter_actor_id for target in self.definition.members
                                     if target.side_id != actor.side_id and self._hp[target.encounter_actor_id] > 0
                                     and (actor.controller is not Controller.HUMAN or target.publicly_visible)
                                     and self.definition.battleground.melee(actor_id, target.encounter_actor_id) is True)
                    status = (CombatStatus.NEEDS_PLAYER_INPUT if actor.controller is Controller.HUMAN
                              else CombatStatus.NEEDS_AGENT_INPUT)
                    token = f"{self.session_id}:r{self._round}:v{self._version}:s{len(self._events)}:{actor_id}"
                    self._pending = Decision(self.session_id, self.definition.encounter_id,
                                             actor_id, actor.side_id, self._round, self._version,
                                             token, eligible, status)
                    self._append(Phase.MELEE, "INTENT_REQUIRED", actor.side_id, actor_id,
                                 {"controller": actor.controller.value, "status": status.value,
                                  "target_ids": eligible})
                    return self._pending
                # Side just finished; next loop enters the next side (or round).

    def _morale_after_death(self, newly_dead: str) -> None:
        # Two independent possible triggers per monster group. This first slice
        # never invents a 2d6 morale result; due+enabled blocks progression.
        for force in self.definition.opposing_forces:
            for group in force.groups:
                n_unavailable = sum(self._hp[a] <= 0 for a in group.member_actor_ids)
                triggers = []
                if newly_dead:
                    triggers.append("FIRST_DEATH_EITHER_SIDE")
                if 2 * n_unavailable >= len(group.member_actor_ids):
                    triggers.append("HALF_UNAVAILABLE")
                for trigger in triggers:
                    key = group.group_id, trigger
                    if key in self._morale_triggers:
                        continue
                    self._morale_triggers.add(key)
                    status = "BLOCKED_UNIMPLEMENTED" if self.profile.morale_enabled else "SCENARIO_RULE_DISABLED"
                    self._append(Phase.MORALE, "MORALE_TRIGGER", force.side.side_id, None,
                                 {"group_id": group.group_id, "trigger_id": trigger,
                                  "status": status, "no_roll_performed": True})
                    if self.profile.morale_enabled:
                        self._blocked_reason = "Due group morale resolution not implemented"

    def submit(self, command: CombatCommand) -> dict[str, Any]:
        with self._lock:
            pending = self._pending
            if not isinstance(command, CombatCommand) or pending is None or self._blocked_reason or self._outcome:
                raise CombatError("No valid pending combat decision")
            if not isinstance(command.command_id, str) or re.fullmatch(r"[A-Za-z0-9][\w.:-]{0,127}", command.command_id) is None:
                raise CombatError("Invalid command identifier")
            if type(command.expected_version) is not int:
                raise CombatError("Invalid expected state version")
            if command.command_id in self._processed_ids:
                raise CombatError("Duplicate command")
            if command.session_id != self.session_id or command.expected_version != self._version:
                raise CombatError("Foreign session or stale state version")
            if command.decision_token != pending.token or command.actor_id != pending.actor_id:
                raise CombatError("Wrong actor or stale decision token")
            if command.kind not in ("ATTACK_MELEE", "HOLD"):
                raise CombatError("Unsupported/ambiguous combat action; no rule effect")
            actor = self._actors[command.actor_id]
            if command.kind == "HOLD":
                if command.target_id is not None:
                    raise CombatError("Hold has no target")
                before = self._version
                self._version += 1
                self._processed_ids.add(command.command_id)
                self._pending = None
                if self._simultaneous:
                    self._simultaneous_effects.append({
                        "kind": "HOLD", "actor_id": actor.encounter_actor_id,
                        "command_id": command.command_id,
                        "public_message": f"{actor.display_name} holds position",
                    })
                    self._append(Phase.MELEE, "SIMULTANEOUS_ACTION_STAGED", actor.side_id,
                                 actor.encounter_actor_id,
                                 {"command_id": command.command_id, "kind": "HOLD",
                                  "pending_round_resolution": True}, before=before)
                else:
                    self._append(Phase.MELEE, "ACTION_HELD", actor.side_id, actor.encounter_actor_id,
                                 {"command_id": command.command_id, "status": "NO_ATTACK"},
                                 f"{actor.display_name} holds position", before=before)
                return {"kind": "HOLD", "version": self._version}
            if command.target_id not in pending.allowed_targets:
                raise CombatError("Invalid, unavailable or non-engaged target")
            target = self._actors[command.target_id]
            if self._hp[actor.encounter_actor_id] <= 0 or self._hp[target.encounter_actor_id] <= 0:
                raise CombatError("Attacker or target is incapacitated")
            # Full legality of numeric lookups is verified BEFORE any dice are
            # consumed. Fixed queue failures also leave state and ledger alone.
            if not actor.equipped_items:
                raise CombatError("No equipped weapon")
            weapon_ref = actor.equipped_items[0].item_ref
            try:
                weapon = self.provider.weapon(weapon_ref, self.profile)
                defender_ac, ac_items = self.provider.effective_ac(target, self.profile)
                required, table_ref = self.provider.attack_target(actor, defender_ac)
                hit_bonus = self.provider.strength_modifier(actor, "MELEE_TO_HIT")
                damage_bonus = self.provider.strength_modifier(actor, "MELEE_DAMAGE")
            except UnsupportedRule as exc:
                raise CombatError(str(exc)) from None
            d20 = self.dice.attack[actor.encounter_actor_id]
            damage_die = self.dice.damage[actor.encounter_actor_id]
            if damage_die.sides != weapon.sides:
                raise CombatError("Selected damage die does not match source-approved weapon")
            # For fixed queue the d20 is consumed first, and the damage die is
            # requested ONLY after an actual hit, never on miss.
            raw_hit = self.roller.roll(d20, roll_id=f"{self.session_id}:r{self._round}:hit:{command.command_id}",
                                       correlation_id=command.command_id)
            modified = raw_hit.face + hit_bonus.amount
            hit = modified >= required
            raw_damage: RawDieResult | None = None
            damage = 0
            if hit:
                # If this source is exhausted, no HP, version or event changes.
                raw_damage = self.roller.roll(damage_die, roll_id=f"{self.session_id}:r{self._round}:damage:{command.command_id}",
                                              correlation_id=command.command_id)
                damage = max(0, raw_damage.face + damage_bonus.amount)
            before = self._version
            hp_before = self._hp[target.encounter_actor_id]
            hp_after = max(0, hp_before - damage)
            if not self._simultaneous:
                self._hp[target.encounter_actor_id] = hp_after
            self._version += 1
            self._processed_ids.add(command.command_id)
            self._pending = None
            details = {
                "command_id": command.command_id, "target_id": target.encounter_actor_id,
                "weapon_id": weapon_ref, "weapon_rule_ref": weapon.rule_id,
                "weapon_rule_version": weapon.rule_version, "weapon_origin": weapon.origin,
                "hit_table_rule_ref": table_ref, "defender_ac": defender_ac,
                "ac_components": [asdict(x) for x in ac_items],
                "hit_roll": self._raw(raw_hit), "hit_modifier": asdict(hit_bonus),
                "modified_hit": modified, "needed_hit": required, "hit": hit,
                "damage_roll": self._raw(raw_damage) if raw_damage else None,
                "damage_modifier": asdict(damage_bonus) if hit else None,
                "damage": damage, "hp_before": hp_before, "hp_after": hp_after,
                "rules_profile_ref": self.profile.profile_id,
                "house_rule_overlays": list(self.profile.house_rule_overlays),
            }
            msg = f"{actor.display_name} {'hits' if hit else 'misses'} {target.display_name}"
            if hit:
                msg += f" for {damage} damage"
            # An undiscovered opponent's identity/action is private until the
            # encounter knowledge owner reveals it; no public backdoor through
            # the otherwise complete trusted controller journal.
            if actor.side_id != self._party and not actor.publicly_visible:
                msg = None
            if target.side_id != self._party and not target.publicly_visible:
                msg = None
            if self._simultaneous:
                # Raw dice and rules arithmetic are complete; HP is held for
                # the simultaneous batch. Never tell the caller a final HP
                # state or winner before every eligible combatant can respond.
                self._simultaneous_effects.append({
                    "kind": "ATTACK_MELEE", "command_id": command.command_id,
                    "actor_id": actor.encounter_actor_id,
                    "target_id": target.encounter_actor_id, "damage": damage,
                    "details": details, "public_message": msg,
                })
                self._append(Phase.MELEE, "SIMULTANEOUS_ACTION_STAGED", actor.side_id,
                             actor.encounter_actor_id,
                             {"command_id": command.command_id, "kind": "ATTACK_MELEE",
                              "target_id": target.encounter_actor_id,
                              "pending_round_resolution": True}, before=before)
                return {"kind": "ATTACK_MELEE", "hit": hit, "damage": damage,
                        "target_id": target.encounter_actor_id, "version": self._version,
                        "outcome": None, "pending_simultaneous_resolution": True}
            self._append(Phase.MELEE, "MELEE_RESOLVED", actor.side_id,
                         actor.encounter_actor_id, details, msg, before=before)
            if hp_before > 0 and hp_after == 0:
                self._morale_after_death(target.encounter_actor_id)
            self._check_outcome()
            return {"kind": "ATTACK_MELEE", "hit": hit, "damage": damage,
                    "target_id": target.encounter_actor_id, "version": self._version,
                    "outcome": self._outcome}

    def public_transcript(self) -> tuple[str, ...]:
        with self._lock:
            return tuple(e.public_message for e in self._events if e.public_message)

    def player_view(self) -> dict[str, Any]:
        """Allowlist only; hidden monster HP, AC, traits and tactics omitted."""
        with self._lock:
            shown = []
            for actor in self.definition.members:
                if actor.side_id != self._party and not actor.publicly_visible:
                    continue
                obj = {"actor_id": actor.encounter_actor_id,
                       "name": actor.display_name, "side_id": actor.side_id}
                if actor.side_id == self._party:
                    obj["hp_current"] = self._hp[actor.encounter_actor_id]
                    obj["hp_max"] = actor.hp_max
                else:
                    obj["defeated"] = self._hp[actor.encounter_actor_id] == 0
                shown.append(obj)
            return {"encounter_id": self.definition.encounter_id,
                    "session_id": self.session_id, "version": self._version,
                    "round_index": self._round, "outcome": self._outcome,
                    "simultaneous_exchange_pending": self._simultaneous,
                    "actors": shown, "transcript": list(self.public_transcript()),
                    "status": self.status().value}

    def export_jsonl(self, root: Path, *, name: str) -> Path:
        """Produce a deterministic local JSONL journal under a Git-ignored reports root.

        The explicit root is a trusted host-supplied repo path, never a value
        from player text. The basename cannot contain path separators/traversal.
        """
        if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", name) is None:
            raise CombatError("Unsafe export artifact name")
        with self._lock:
            folder = Path(root).resolve() / "reports" / "combat-logs"
            folder.mkdir(parents=True, exist_ok=True)
            dest = folder / f"{name}.jsonl"
            if dest.exists():
                raise CombatError("Audit artifact already exists; refusing overwrite")
            # No restricted B1 source text/prompt bodies are stored here.
            lines = "".join(json.dumps(asdict(event), sort_keys=True, separators=(",", ":")) + "\n"
                            for event in self._events)
            dest.write_text(lines, encoding="utf-8", newline="\n")
            return dest


def canonical_dice_kit(definition: EncounterDefinition) -> DiceKit:
    """Explicit named *synthetic test dice* for the owner 3v3 fixture only."""
    if definition.encounter_id != "owner-canonical-3v3-synthetic":
        raise CombatError("Fixture-selected dice kit must be explicit for other encounters")
    profile = PrototypeReferenceProvider()
    approved = RuleProfile(house_rule_overlays=(FLAIL_RULE,))
    initiative = {s.side_id: Die(f"fixture-{s.side_id}-initiative-d6", 6, "white") for s in definition.sides}
    attack = {a.encounter_actor_id: Die(f"fixture-{a.encounter_actor_id}-attack-d20", 20, "gold") for a in definition.members}
    damage = {a.encounter_actor_id: Die(f"fixture-{a.encounter_actor_id}-damage-d{profile.weapon(a.equipped_items[0].item_ref, approved).sides}",
                                        profile.weapon(a.equipped_items[0].item_ref, approved).sides, "red") for a in definition.members}
    return DiceKit(initiative, attack, damage)