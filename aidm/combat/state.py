"""AIDM-DES-006.2: source-labelled, in-memory SCRIPTED encounter state only.

Usage: state = MockEncounterState.start(fixture, trusted_token=controller_token)
       state.apply_scripted_effect(fixture.approved_effects[0], token=controller_token)
Change Log: 2026-11-20 COSTA — typed encounter aggregates and golden snapshots.

NO real combat rules, Bookkeeper, geometry calculations, persistent journal or
player mutation permissions are granted by this module.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import Enum
from threading import RLock
from typing import Any, Sequence


class FixtureErrorCode(str, Enum):
    INVALID_DEFINITION = "INVALID_DEFINITION"
    NOT_IMPLEMENTED = "NOT_IMPLEMENTED"
    UNAUTHORISED = "UNAUTHORISED"
    STALE_VERSION = "STALE_VERSION"
    DUPLICATE_EFFECT = "DUPLICATE_EFFECT"
    INVALID_EFFECT = "INVALID_EFFECT"
    UNKNOWN_ACTOR = "UNKNOWN_ACTOR"
    INVALID_ACTION = "INVALID_ACTION"
    TERMINAL = "TERMINAL"


class FixtureError(ValueError):
    """Safe typed fixture failure; no source rules or private details attached."""

    def __init__(self, code: FixtureErrorCode, message: str) -> None:
        self.code = code
        super().__init__(message)


def _require(condition: bool, message: str, code: FixtureErrorCode = FixtureErrorCode.INVALID_DEFINITION) -> None:
    if not condition:
        raise FixtureError(code, message)


def _label(value: object, label: str) -> None:
    _require(isinstance(value, str) and bool(value.strip()), f"Invalid {label}")


def _unique(items: Sequence[str], label: str) -> None:
    _require(len(set(items)) == len(items), f"Duplicate {label}")


def _int(value: object, lower: int, upper: int, label: str) -> None:
    _require(type(value) is int and lower <= value <= upper, f"Invalid {label}")


class Origin(str, Enum):
    CHARACTER = "CHARACTER"
    CREATURE = "CREATURE"
    NPC = "NPC"


class Controller(str, Enum):
    HUMAN = "HUMAN"
    AGENT = "AGENT"
    SCRIPTED = "SCRIPTED"


class SpatialModel(str, Enum):
    EXPLICIT_RELATIONS = "EXPLICIT_RELATIONS"
    FUTURE_GEOMETRY = "FUTURE_GEOMETRY"


class Visibility(str, Enum):
    CLEAR = "CLEAR"
    BLOCKED = "BLOCKED"
    UNKNOWN = "UNKNOWN"


class FixtureOutcome(str, Enum):
    ONGOING = "ONGOING"
    PARTY_VICTORY = "PARTY_VICTORY"
    PARTY_DEFEAT = "PARTY_DEFEAT"


class ProposalStatus(str, Enum):
    UNVALIDATED = "UNVALIDATED"
    FORWARDED = "FORWARDED"
    REJECTED = "REJECTED"


@dataclass(frozen=True, slots=True)
class AbilityValue:
    name: str
    source_value: int

    def __post_init__(self) -> None:
        _label(self.name, "ability name")
        _int(self.source_value, 1, 100, "source ability")


@dataclass(frozen=True, slots=True)
class ScenarioOverride:
    field_name: str
    source_value: int
    scenario_value: int
    directive_ref: str

    def __post_init__(self) -> None:
        _label(self.field_name, "override field")
        _label(self.directive_ref, "owner directive")
        _int(self.source_value, 1, 100, "original ability")
        _int(self.scenario_value, 1, 100, "scenario ability")


@dataclass(frozen=True, slots=True)
class EquipmentRef:
    item_ref: str
    label: str
    source_ref: str
    verification: str = "UNVERIFIED"
    candidate_roll: str | None = None

    def __post_init__(self) -> None:
        for key in ("item_ref", "label", "source_ref", "verification"):
            _label(getattr(self, key), key)


@dataclass(frozen=True, slots=True)
class Combatant:
    """Shared immutable definition for character, retainer, NPC and creature."""

    encounter_actor_id: str
    display_name: str
    side_id: str
    origin: Origin
    source_ref: str  # CHARACTER -> external character ref; CREATURE -> definition ref
    controller: Controller
    hp_current: int
    hp_max: int
    group_id: str | None = None
    class_level_ref: str | None = None
    monster_hd_ref: str | None = None
    save_profile_ref: str | None = None
    armor_class_source: int | None = None
    ability_scores: tuple[AbilityValue, ...] = ()
    scenario_overrides: tuple[ScenarioOverride, ...] = ()
    equipped_items: tuple[EquipmentRef, ...] = ()
    attack_profiles: tuple[str, ...] = ()
    special_action_refs: tuple[str, ...] = ()
    movement_profile_ref: str | None = None
    status_tags: tuple[str, ...] = ()
    hidden_traits: tuple[str, ...] = ()
    publicly_visible: bool = False  # Fail-closed for undiscovered opponents.

    def __post_init__(self) -> None:
        for key in ("encounter_actor_id", "display_name", "side_id", "source_ref"):
            _label(getattr(self, key), key)
        _require(isinstance(self.origin, Origin) and isinstance(self.controller, Controller), "Invalid origin or controller")
        _int(self.hp_max, 1, 1_000_000, "maximum HP")
        _int(self.hp_current, 0, self.hp_max, "current HP")
        _require(type(self.publicly_visible) is bool, "Invalid player visibility flag")
        if self.group_id is not None:
            _label(self.group_id, "group ID")
        if self.armor_class_source is not None:
            _int(self.armor_class_source, -100, 100, "source AC")
        for field_name in ("ability_scores", "scenario_overrides", "equipped_items", "attack_profiles", "special_action_refs", "status_tags", "hidden_traits"):
            _require(isinstance(getattr(self, field_name), tuple), f"{field_name} must be immutable tuple")
        _unique([x.name for x in self.ability_scores], "ability score")
        _unique([x.field_name for x in self.scenario_overrides], "scenario override")
        for override in self.scenario_overrides:
            source = next((x.source_value for x in self.ability_scores if x.name == override.field_name), None)
            _require(source == override.source_value, "Override must preserve imported source ability")
        for ref in (*self.attack_profiles, *self.special_action_refs, *self.status_tags, *self.hidden_traits):
            _label(ref, "reference/tag")


@dataclass(frozen=True, slots=True)
class CombatSide:
    side_id: str
    label: str
    members: tuple[Combatant, ...]
    default_controller: Controller = Controller.HUMAN

    def __post_init__(self) -> None:
        _label(self.side_id, "side ID")
        _label(self.label, "side label")
        _require(isinstance(self.default_controller, Controller) and isinstance(self.members, tuple) and bool(self.members), "Invalid side members/controller")
        _unique([m.encounter_actor_id for m in self.members], "side actor")
        _require(all(isinstance(m, Combatant) and m.side_id == self.side_id for m in self.members), "Actor side membership mismatch")


@dataclass(frozen=True, slots=True)
class EncounterParty:
    party_id: str
    side: CombatSide

    def __post_init__(self) -> None:
        _label(self.party_id, "party ID")
        _require(isinstance(self.side, CombatSide), "Missing shared combat side")

    @property
    def members(self) -> tuple[Combatant, ...]:
        return self.side.members


@dataclass(frozen=True, slots=True)
class MonsterGroup:
    group_id: str
    member_actor_ids: tuple[str, ...]
    monster_definition_ref: str | None = None
    morale_rating: int | None = None  # source metadata; never evaluated here

    def __post_init__(self) -> None:
        _label(self.group_id, "monster group ID")
        _require(isinstance(self.member_actor_ids, tuple) and bool(self.member_actor_ids), "Invalid monster group members")
        for a in self.member_actor_ids:
            _label(a, "monster member ID")
        _unique(self.member_actor_ids, "group member")
        if self.monster_definition_ref is not None:
            _label(self.monster_definition_ref, "group definition ref")
        if self.morale_rating is not None:
            _int(self.morale_rating, 0, 100, "source morale rating")


@dataclass(frozen=True, slots=True)
class OpposingForce:
    force_id: str
    side: CombatSide
    groups: tuple[MonsterGroup, ...]

    def __post_init__(self) -> None:
        _label(self.force_id, "force ID")
        _require(isinstance(self.side, CombatSide) and isinstance(self.groups, tuple) and bool(self.groups), "Invalid opposing force")
        member_ids = {m.encounter_actor_id for m in self.side.members}
        referenced: list[str] = []
        for group in self.groups:
            _require(isinstance(group, MonsterGroup), "Invalid monster group")
            referenced.extend(group.member_actor_ids)
            for actor in self.side.members:
                if actor.encounter_actor_id in group.member_actor_ids:
                    _require(actor.group_id == group.group_id, "Creature group membership mismatch")
        _unique([g.group_id for g in self.groups], "monster group ID")
        _unique(referenced, "monster group actor membership")
        _require(set(referenced) == member_ids, "Every opposing force actor must be in one group")


@dataclass(frozen=True, slots=True)
class AreaRef:
    area_id: str
    zones: tuple[str, ...]
    spatial_model: SpatialModel = SpatialModel.EXPLICIT_RELATIONS

    def __post_init__(self) -> None:
        _label(self.area_id, "area ID")
        if self.spatial_model is not SpatialModel.EXPLICIT_RELATIONS:
            raise FixtureError(FixtureErrorCode.NOT_IMPLEMENTED, "Spatial model NOT_IMPLEMENTED")
        _require(isinstance(self.zones, tuple) and bool(self.zones), "Area zones required")
        for zone in self.zones:
            _label(zone, "zone ID")
        _unique(self.zones, "zone ID")


@dataclass(frozen=True, slots=True)
class PositionRef:
    zone_id: str

    def __post_init__(self) -> None:
        _label(self.zone_id, "zone ID")


@dataclass(frozen=True, slots=True)
class ActorPlacement:
    actor_id: str
    position: PositionRef

    def __post_init__(self) -> None:
        _label(self.actor_id, "placed actor")
        _require(isinstance(self.position, PositionRef), "Invalid position")


@dataclass(frozen=True, slots=True)
class ZoneRelation:
    origin_zone: str
    target_zone: str
    distance_ft: int | None = None
    visibility: Visibility = Visibility.UNKNOWN

    def __post_init__(self) -> None:
        _label(self.origin_zone, "relation origin")
        _label(self.target_zone, "relation target")
        if self.distance_ft is not None:
            _int(self.distance_ft, 0, 100_000, "authored distance")
        _require(isinstance(self.visibility, Visibility), "Invalid authored visibility")


@dataclass(frozen=True, slots=True)
class MeleeEligibility:
    actor_a: str
    actor_b: str
    authored_eligible: bool  # fixture assertion, NOT derived from range or rules

    def __post_init__(self) -> None:
        _label(self.actor_a, "melee actor")
        _label(self.actor_b, "melee actor")
        _require(self.actor_a != self.actor_b and type(self.authored_eligible) is bool, "Invalid authored melee relation")


@dataclass(frozen=True, slots=True)
class BattlegroundDefinition:
    area: AreaRef
    initial_placements: tuple[ActorPlacement, ...]
    zone_relations: tuple[ZoneRelation, ...] = ()
    melee_relations: tuple[MeleeEligibility, ...] = ()

    def __post_init__(self) -> None:
        _require(isinstance(self.area, AreaRef) and isinstance(self.initial_placements, tuple), "Invalid battleground")
        ids = [p.actor_id for p in self.initial_placements]
        _unique(ids, "actor placement")
        _require(all(p.position.zone_id in self.area.zones for p in self.initial_placements), "Unknown initial zone")
        _require(all(z.origin_zone in self.area.zones and z.target_zone in self.area.zones for z in self.zone_relations), "Unknown relation zone")
        _unique([f"{z.origin_zone}:{z.target_zone}" for z in self.zone_relations], "authored zone relation")
        _unique([":".join(sorted((m.actor_a, m.actor_b))) for m in self.melee_relations], "authored melee pair")

    def relation(self, origin_zone: str, target_zone: str) -> ZoneRelation:
        _require(origin_zone in self.area.zones and target_zone in self.area.zones, "Unknown query zone")
        return next((r for r in self.zone_relations if (r.origin_zone, r.target_zone) == (origin_zone, target_zone)),
                    ZoneRelation(origin_zone, target_zone))

    def melee(self, actor_a: str, actor_b: str) -> bool | None:
        return next((r.authored_eligible for r in self.melee_relations
                     if {r.actor_a, r.actor_b} == {actor_a, actor_b}), None)


@dataclass(frozen=True, slots=True)
class MonsterDefinitionSnapshot:
    """Owner-authored immutable mock reference, NOT a rules engine/profile table."""

    definition_ref: str
    armor_class_source: int
    hit_dice_ref: str
    attacks_ref: str
    damage_ref: str
    movement_ref: str
    save_ref: str
    group_morale_source: int
    provenance: str = "OWNER_2026_11_20_UNVERIFIED"


@dataclass(frozen=True, slots=True)
class EncounterDefinition:
    encounter_id: str
    party: EncounterParty
    opposing_forces: tuple[OpposingForce, ...]
    battleground: BattlegroundDefinition
    rules_profile_ref: str
    house_rule_overlay_refs: tuple[str, ...] = ()
    monster_definitions: tuple[MonsterDefinitionSnapshot, ...] = ()

    def __post_init__(self) -> None:
        _label(self.encounter_id, "encounter ID")
        _label(self.rules_profile_ref, "rules profile ref")
        _require(isinstance(self.party, EncounterParty) and isinstance(self.opposing_forces, tuple) and bool(self.opposing_forces), "Invalid encounter sides")
        _require(isinstance(self.battleground, BattlegroundDefinition), "Missing battleground")
        ids = [s.side_id for s in self.sides]
        _unique(ids, "side ID")
        _unique([force.force_id for force in self.opposing_forces], "opposing force ID")
        _unique([g.group_id for f in self.opposing_forces for g in f.groups], "monster group ID")
        all_members = self.members
        _unique([m.encounter_actor_id for m in all_members], "encounter actor ID")
        placements = self.battleground.initial_placements
        _require({p.actor_id for p in placements} == {m.encounter_actor_id for m in all_members}, "Missing or orphan initial actor placement")
        listed = {m.definition_ref for m in self.monster_definitions}
        _unique([m.definition_ref for m in self.monster_definitions], "monster definition")
        for member in all_members:
            if member.origin is Origin.CREATURE and self.monster_definitions:
                _require(member.source_ref in listed, "Creature definition is not available")
            if member.group_id is not None:
                _require(member.origin is Origin.CREATURE, "Only grouped creatures supported in initial fixture")
        for relation in self.battleground.melee_relations:
            _require(relation.actor_a in {m.encounter_actor_id for m in all_members} and
                     relation.actor_b in {m.encounter_actor_id for m in all_members}, "Unknown authored melee actor")
        for overlay in self.house_rule_overlay_refs:
            _label(overlay, "house rule overlay")

    @property
    def sides(self) -> tuple[CombatSide, ...]:
        return (self.party.side,) + tuple(f.side for f in self.opposing_forces)

    @property
    def members(self) -> tuple[Combatant, ...]:
        return tuple(m for s in self.sides for m in s.members)


@dataclass(frozen=True, slots=True)
class ActorHPChange:
    actor_id: str
    before: int
    after: int


@dataclass(frozen=True, slots=True)
class DeclaredAction:
    action_id: str
    actor_id: str
    text: str
    target_id: str | None = None
    status: ProposalStatus = ProposalStatus.UNVALIDATED
    correlation_id: str | None = None


@dataclass(frozen=True, slots=True)
class ApprovedFixtureEffect:
    effect_id: str
    expected_state_version: int
    hp_changes: tuple[ActorHPChange, ...]
    round_after: int
    outcome_after: FixtureOutcome = FixtureOutcome.ONGOING
    source: str = "SCRIPTED_TEST"
    action_id: str | None = None


@dataclass(frozen=True, slots=True)
class FixtureDefinition:
    fixture_id: str
    encounter: EncounterDefinition
    approved_effects: tuple[ApprovedFixtureEffect, ...] = ()
    schema_version: str = "0.1"
    rules_verified: bool = False
    provenance: str = "SYNTHETIC_TEST"

    def __post_init__(self) -> None:
        _label(self.fixture_id, "fixture ID")
        _require(self.schema_version == "0.1" and self.rules_verified is False and self.provenance == "SYNTHETIC_TEST", "Only synthetic unverified fixture schema 0.1 is implemented")
        _require(isinstance(self.encounter, EncounterDefinition) and isinstance(self.approved_effects, tuple), "Invalid fixture definition")
        _unique([e.effect_id for e in self.approved_effects], "approved effect ID")
        for e in self.approved_effects:
            _label(e.effect_id, "approved effect ID")
            _require(e.source == "SCRIPTED_TEST" and type(e.expected_state_version) is int and e.expected_state_version >= 0, "Invalid approved fixture effect")
            _require(type(e.round_after) is int and e.round_after >= 1 and isinstance(e.outcome_after, FixtureOutcome), "Invalid fixture checkpoint")


@dataclass(frozen=True, slots=True)
class ActorSnapshot:
    actor_id: str
    side_id: str
    group_id: str | None
    source_ref: str
    origin: Origin
    controller: Controller
    hp_current: int
    hp_max: int
    armor_class_source: int | None
    status_tags: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SideSnapshot:
    side_id: str
    label: str
    actor_ids: tuple[str, ...]
    monster_group_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class RecordedRollAssociation:
    action_id: str
    roll_id: str
    die_id: str
    face: int
    sides: int
    source: str
    queue_position: int | None
    correlation_id: str | None

    def __post_init__(self) -> None:
        _label(self.action_id, "roll action ID")
        _label(self.roll_id, "roll ID")
        _label(self.die_id, "selected die ID")
        _int(self.sides, 2, 1_000, "roll sides")
        _int(self.face, 1, self.sides, "raw die face")
        _require(self.source in ("FIXED", "SYSTEM_RANDOM"), "Invalid raw roll source")


@dataclass(frozen=True, slots=True)
class EncounterSnapshot:
    fixture_id: str
    session_id: str
    encounter_id: str
    schema_version: str
    rules_profile_ref: str
    house_rule_overlay_refs: tuple[str, ...]
    rules_verified: bool
    state_version: int
    round_index: int
    checkpoint: str
    outcome: FixtureOutcome
    actors: tuple[ActorSnapshot, ...]
    sides: tuple[SideSnapshot, ...]
    placements: tuple[ActorPlacement, ...]
    applied_effect_ids: tuple[str, ...]
    pending_actions: tuple[DeclaredAction, ...]
    roll_associations: tuple[RecordedRollAssociation, ...]

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> EncounterSnapshot:
        """Roundtrip an immutable serialized snapshot, without source or dice calls."""
        return cls(
            fixture_id=data["fixture_id"], session_id=data["session_id"], encounter_id=data["encounter_id"],
            schema_version=data["schema_version"], rules_profile_ref=data["rules_profile_ref"],
            house_rule_overlay_refs=tuple(data["house_rule_overlay_refs"]), rules_verified=data["rules_verified"],
            state_version=data["state_version"], round_index=data["round_index"], checkpoint=data["checkpoint"],
            outcome=FixtureOutcome(data["outcome"]),
            actors=tuple(ActorSnapshot(**dict(a, origin=Origin(a["origin"]), controller=Controller(a["controller"]),
                                              status_tags=tuple(a["status_tags"]))) for a in data["actors"]),
            sides=tuple(SideSnapshot(**dict(s, actor_ids=tuple(s["actor_ids"]),
                                              monster_group_ids=tuple(s["monster_group_ids"]))) for s in data["sides"]),
            placements=tuple(ActorPlacement(p["actor_id"], PositionRef(p["position"]["zone_id"])) for p in data["placements"]),
            applied_effect_ids=tuple(data["applied_effect_ids"]),
            pending_actions=tuple(DeclaredAction(**dict(a, status=ProposalStatus(a["status"]))) for a in data["pending_actions"]),
            roll_associations=tuple(RecordedRollAssociation(**r) for r in data["roll_associations"]),
        )


class MockEncounterState:
    """Only test-harness capability may write scripted changes; no game authority."""

    def __init__(self, fixture: FixtureDefinition, *, session_id: str, trusted_token: object) -> None:
        _require(isinstance(fixture, FixtureDefinition), "Fixture must be accepted definition")
        _label(session_id, "session ID")
        _require(trusted_token is not None, "Trusted fixture controller is required", FixtureErrorCode.UNAUTHORISED)
        self._fixture = fixture
        self._session_id = session_id
        self._token = trusted_token
        self._lock = RLock()
        self._hp = {a.encounter_actor_id: a.hp_current for a in fixture.encounter.members}
        self._status = {a.encounter_actor_id: a.status_tags for a in fixture.encounter.members}
        self._placement = {p.actor_id: p.position for p in fixture.encounter.battleground.initial_placements}
        self._version = 0
        self._round = 1
        self._outcome = FixtureOutcome.ONGOING
        self._applied: list[str] = []
        self._pending: list[DeclaredAction] = []
        self._rolls: list[RecordedRollAssociation] = []

    @classmethod
    def start(cls, fixture: FixtureDefinition, *, session_id: str, trusted_token: object) -> MockEncounterState:
        return cls(fixture, session_id=session_id, trusted_token=trusted_token)

    def _authorise(self, token: object) -> None:
        if token is not self._token:
            raise FixtureError(FixtureErrorCode.UNAUTHORISED, "Trusted fixture controller required")

    def snapshot(self) -> EncounterSnapshot:
        with self._lock:
            def side_snapshot(side: CombatSide) -> SideSnapshot:
                group_ids = tuple(g.group_id for f in self._fixture.encounter.opposing_forces
                                  if f.side.side_id == side.side_id for g in f.groups)
                return SideSnapshot(side.side_id, side.label,
                                    tuple(m.encounter_actor_id for m in side.members), group_ids)
            actors = tuple(ActorSnapshot(a.encounter_actor_id, a.side_id, a.group_id, a.source_ref,
                                         a.origin, a.controller, self._hp[a.encounter_actor_id], a.hp_max,
                                         a.armor_class_source, self._status[a.encounter_actor_id])
                           for a in self._fixture.encounter.members)
            positions = tuple(ActorPlacement(a.encounter_actor_id, self._placement[a.encounter_actor_id])
                              for a in self._fixture.encounter.members)
            return EncounterSnapshot(
                self._fixture.fixture_id, self._session_id, self._fixture.encounter.encounter_id,
                self._fixture.schema_version, self._fixture.encounter.rules_profile_ref,
                self._fixture.encounter.house_rule_overlay_refs, False, self._version, self._round,
                "INITIAL" if self._version == 0 else ("TERMINAL_FIXTURE" if self._outcome is not FixtureOutcome.ONGOING else "AFTER_SCRIPTED_ROUND"),
                self._outcome, actors, tuple(side_snapshot(side) for side in self._fixture.encounter.sides),
                positions, tuple(self._applied), tuple(self._pending), tuple(self._rolls),
            )

    def record_proposal(self, action: DeclaredAction, *, token: object) -> DeclaredAction:
        with self._lock:
            self._authorise(token)
            _require(isinstance(action, DeclaredAction), "Only typed proposals accepted", FixtureErrorCode.INVALID_ACTION)
            _label(action.action_id, "action ID")
            _label(action.text, "original action text")
            known = {a.encounter_actor_id for a in self._fixture.encounter.members}
            _require(action.actor_id in known and (action.target_id is None or action.target_id in known),
                     "Unknown actor/target", FixtureErrorCode.INVALID_ACTION)
            _require(action.status in (ProposalStatus.UNVALIDATED, ProposalStatus.FORWARDED), "Rejected proposal cannot be accepted", FixtureErrorCode.INVALID_ACTION)
            _require(action.action_id not in {p.action_id for p in self._pending}, "Duplicate proposal", FixtureErrorCode.INVALID_ACTION)
            self._pending.append(action)
            return action

    def attach_raw_roll(self, association: RecordedRollAssociation, *, token: object) -> None:
        with self._lock:
            self._authorise(token)
            _require(isinstance(association, RecordedRollAssociation), "Only typed raw roll associations accepted", FixtureErrorCode.INVALID_ACTION)
            _require(association.action_id in {x.action_id for x in self._pending}, "No declared action for raw roll", FixtureErrorCode.INVALID_ACTION)
            _require(not any(a.roll_id == association.roll_id for a in self._rolls), "Duplicate raw roll ID", FixtureErrorCode.INVALID_ACTION)
            self._rolls.append(association)  # Not an approved effect/event or a version increment.

    def apply_scripted_effect(self, effect: ApprovedFixtureEffect, *, token: object) -> EncounterSnapshot:
        with self._lock:
            self._authorise(token)
            _require(isinstance(effect, ApprovedFixtureEffect), "Only scripted fixture effect accepted", FixtureErrorCode.INVALID_EFFECT)
            if effect.effect_id in self._applied:
                raise FixtureError(FixtureErrorCode.DUPLICATE_EFFECT, "Fixture effect already applied")
            if self._version != effect.expected_state_version:
                raise FixtureError(FixtureErrorCode.STALE_VERSION, "Stale expected state version")
            _require(self._outcome is FixtureOutcome.ONGOING, "Terminal fixture cannot change", FixtureErrorCode.TERMINAL)
            _require(effect in self._fixture.approved_effects and effect.source == "SCRIPTED_TEST",
                     "Effect is not fixture authorised", FixtureErrorCode.INVALID_EFFECT)
            _require(effect.round_after >= self._round and effect.round_after <= self._round + 1,
                     "Unsupported fixture checkpoint", FixtureErrorCode.INVALID_EFFECT)
            if effect.action_id is not None:
                _require(any(p.action_id == effect.action_id and p.status is ProposalStatus.FORWARDED for p in self._pending),
                         "Cannot resolve unvalidated action", FixtureErrorCode.INVALID_ACTION)
            proposed = dict(self._hp)
            changed: set[str] = set()
            caps = {a.encounter_actor_id: a.hp_max for a in self._fixture.encounter.members}
            _require(bool(effect.hp_changes), "Effect must declare explicit state changes", FixtureErrorCode.INVALID_EFFECT)
            for change in effect.hp_changes:
                _require(isinstance(change, ActorHPChange), "Malformed HP change", FixtureErrorCode.INVALID_EFFECT)
                _require(change.actor_id in proposed, "Unknown effect actor", FixtureErrorCode.UNKNOWN_ACTOR)
                _require(change.actor_id not in changed, "Duplicate change for same actor", FixtureErrorCode.INVALID_EFFECT)
                _require(type(change.before) is int and change.before == proposed[change.actor_id],
                         "Effect prior HP mismatch", FixtureErrorCode.INVALID_EFFECT)
                _require(type(change.after) is int and 0 <= change.after <= caps[change.actor_id],
                         "Effect HP out of bounds", FixtureErrorCode.INVALID_EFFECT)
                changed.add(change.actor_id)
                proposed[change.actor_id] = change.after
            # Atomic commit only after every ref/value/version/cursor has passed.
            self._hp = proposed
            self._version += 1
            self._round = effect.round_after
            self._outcome = effect.outcome_after
            self._applied.append(effect.effect_id)
            return self.snapshot()

    def view_for_controller(self, *, token: object) -> dict[str, Any]:
        with self._lock:
            self._authorise(token)
            return asdict(self.snapshot())  # New nested mapping; never a mutable alias.

    def view_for_player(self) -> dict[str, Any]:
        """Explicit public allowlist; no generic serialization of opponent data."""
        snap = self.snapshot()
        party_side_id = self._fixture.encounter.party.side.side_id
        public_actors = []
        shown_ids: set[str] = set()
        for actor in snap.actors:
            definition = next(a for a in self._fixture.encounter.members if a.encounter_actor_id == actor.actor_id)
            if actor.side_id != party_side_id and not definition.publicly_visible:
                continue  # A private foe, its position, and its identity remain hidden.
            shown_ids.add(actor.actor_id)
            if actor.side_id == party_side_id:
                public_actors.append({"actor_id": actor.actor_id, "name": definition.display_name,
                                      "side_id": actor.side_id, "controller": actor.controller.value,
                                      "hp_current": actor.hp_current, "hp_max": actor.hp_max,
                                      "zone_id": next(p.position.zone_id for p in snap.placements if p.actor_id == actor.actor_id)})
            else:
                public_actors.append({"actor_id": actor.actor_id, "name": definition.display_name,
                                      "side_id": actor.side_id, "group_id": actor.group_id,
                                      "zone_id": next(p.position.zone_id for p in snap.placements if p.actor_id == actor.actor_id)})
        public_sides = []
        for side in snap.sides:
            visible_members = [a for a in side.actor_ids if a in shown_ids]
            public_sides.append({"side_id": side.side_id, "actor_ids": visible_members,
                                 "group_ids": list(dict.fromkeys(a["group_id"] for a in public_actors
                                                                   if a["side_id"] == side.side_id and "group_id" in a))})
        return {"session_id": snap.session_id, "encounter_id": snap.encounter_id,
                "state_version": snap.state_version, "round_index": snap.round_index,
                "outcome": snap.outcome.value, "actors": public_actors,
                "sides": public_sides}