"""AIDM-DES-006.4 — deterministic, typed actor condition transition service.

Purpose: Keep independently tracked conditions beside the existing immutable
         DES-006.2 Combatant definitions, without copying/updating actor HP,
         making spell/rules decisions, or creating a second clock.
Usage: registry = EncounterActorIndex(canonical_three_vs_three().encounter.members)
       authority = ConditionEventAuthority()    # trusted Python orchestrators only
       service = ConditionStateService(registry, authority, clock_id='campaign-clock')
       proof = authority.verified('event-1', 'alho', 'APPLY', 'mentzer-or-overlay')
       result = service.apply(ApplyCondition(..., evidence=proof))
Change Log: 2026-11-25 COSTA — first technical generic state-engine slice.

SECURITY: ConditionEventAuthority is a private in-process capability. It must
never be given to an LLM, browser or network-exposed tool. Verified mechanics
are owned by the calling Combat/Rules Orchestrator (DES-006.5), not here.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from enum import Enum
from threading import RLock
from typing import Protocol


class ConditionErrorCode(str, Enum):
    INVALID = "INVALID"
    UNKNOWN_ACTOR = "UNKNOWN_ACTOR"
    UNKNOWN_CONDITION = "UNKNOWN_CONDITION"
    UNAUTHORISED = "UNAUTHORISED"
    STALE_VERSION = "STALE_VERSION"
    DUPLICATE_EVENT = "DUPLICATE_EVENT"
    REPLAY_CONFLICT = "REPLAY_CONFLICT"
    UNSUPPORTED_STACKING = "UNSUPPORTED_STACKING"
    NOT_ACTIVE = "NOT_ACTIVE"
    CLOCK_REPLAY = "CLOCK_REPLAY"
    INVALID_DEADLINE = "INVALID_DEADLINE"
    CORRUPT_SNAPSHOT = "CORRUPT_SNAPSHOT"


class ConditionError(ValueError):
    """Typed, player-safe failure; state is unchanged on rejection."""
    def __init__(self, code: ConditionErrorCode, message: str) -> None:
        self.code = code
        super().__init__(message)


def _id(value: object, name: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 128:
        raise ConditionError(ConditionErrorCode.INVALID, f"Invalid {name}")
    return value


def _seconds(value: object, name: str) -> int:
    if type(value) is not int or value < 0:
        raise ConditionError(ConditionErrorCode.INVALID, f"Invalid {name}")
    return value


class ConditionStatus(str, Enum):
    ACTIVE = "ACTIVE"
    REMOVED = "REMOVED"
    EXPIRED = "EXPIRED"


@dataclass(frozen=True, slots=True)
class ConditionDefinition:
    code: str
    independent_instances: bool = False
    """True only if an explicit rules-policy allows simultaneous same-code instances."""

    def __post_init__(self) -> None:
        _id(self.code, "condition code")
        if type(self.independent_instances) is not bool:
            raise ConditionError(ConditionErrorCode.INVALID, "Invalid stacking policy")


DEFAULT_CONDITIONS = (
    ConditionDefinition("POISONED"),
    ConditionDefinition("NAUSEATED"),
    ConditionDefinition("ASLEEP"),
)


class CombatantRef(Protocol):
    encounter_actor_id: str
    publicly_visible: bool
    # Origin/side/source/HP remain owned by existing DES-006.2 Combatant.


class EncounterActorIndex:
    """Read-only references to existing Combatant objects; no duplicate HP state."""
    def __init__(self, actors: tuple[CombatantRef, ...]) -> None:
        if not isinstance(actors, tuple) or not actors:
            raise ConditionError(ConditionErrorCode.INVALID, "Actors must be a nonempty tuple")
        index: dict[str, CombatantRef] = {}
        for actor in actors:
            name = _id(getattr(actor, "encounter_actor_id", None), "actor ID")
            if name in index or type(getattr(actor, "publicly_visible", None)) is not bool:
                raise ConditionError(ConditionErrorCode.INVALID, "Invalid or duplicated actor reference")
            index[name] = actor
        self._actors = index

    def get(self, actor_id: str) -> CombatantRef:
        _id(actor_id, "actor ID")
        if actor_id not in self._actors:
            raise ConditionError(ConditionErrorCode.UNKNOWN_ACTOR, "Unknown actor")
        return self._actors[actor_id]

    @property
    def actor_ids(self) -> tuple[str, ...]:
        return tuple(self._actors)


@dataclass(frozen=True, slots=True)
class VerifiedConditionEvent:
    source_event_id: str
    target_actor_id: str
    operation: str
    source_rule_ref: str
    _seal: object


class ConditionEventAuthority:
    """Mint evidence only after trusted domain rule validation has succeeded."""
    def __init__(self) -> None:
        self._seal = object()

    def verified(self, source_event_id: str, target_actor_id: str,
                 operation: str, source_rule_ref: str) -> VerifiedConditionEvent:
        for val, name in ((source_event_id, "event"), (target_actor_id, "target"),
                          (source_rule_ref, "source rule")):
            _id(val, name)
        if operation not in ("APPLY", "REMOVE"):
            raise ConditionError(ConditionErrorCode.INVALID, "Invalid operation")
        return VerifiedConditionEvent(source_event_id, target_actor_id,
                                      operation, source_rule_ref, self._seal)


@dataclass(frozen=True, slots=True)
class ConditionCommand:
    action_id: str
    cause_event_id: str
    actor_id: str
    expected_actor_version: int
    correlation_id: str
    evidence: VerifiedConditionEvent


@dataclass(frozen=True, slots=True)
class ApplyCondition:
    command: ConditionCommand
    instance_id: str
    code: str
    source_actor_id: str | None
    ruleset_ref: str
    source_rule_ref: str
    house_overlay_refs: tuple[str, ...] = ()
    applied_at_game_seconds: int | None = None
    expiry_at_game_seconds: int | None = None
    parameters: tuple[tuple[str, str | int | bool], ...] = ()


@dataclass(frozen=True, slots=True)
class RemoveCondition:
    command: ConditionCommand
    instance_id: str
    source_rule_ref: str


@dataclass(frozen=True, slots=True)
class ConditionInstance:
    instance_id: str
    actor_id: str
    code: str
    source_actor_id: str | None
    cause_event_id: str
    ruleset_ref: str
    source_rule_ref: str
    house_overlay_refs: tuple[str, ...]
    applied_at_game_seconds: int | None
    expiry_at_game_seconds: int | None
    parameters: tuple[tuple[str, str | int | bool], ...]
    status: ConditionStatus
    removed_by_event_id: str | None = None


@dataclass(frozen=True, slots=True)
class ActorConditionSnapshot:
    actor_id: str
    condition_version: int
    instances: tuple[ConditionInstance, ...]

    @property
    def active(self) -> tuple[ConditionInstance, ...]:
        return tuple(c for c in self.instances if c.status is ConditionStatus.ACTIVE)


@dataclass(frozen=True, slots=True)
class ConditionReceipt:
    action_id: str
    cause_event_id: str
    actor_id: str
    instance_id: str
    operation: str
    prior_version: int
    new_version: int
    status: ConditionStatus
    correlation_id: str


@dataclass(frozen=True, slots=True)
class ExpiryReceipt:
    clock_receipt_id: str
    actor_id: str
    instance_id: str
    condition_version_before: int
    condition_version_after: int
    expiry_at_game_seconds: int


@dataclass(frozen=True, slots=True)
class ConditionLedgerSnapshot:
    clock_id: str
    actors: tuple[ActorConditionSnapshot, ...]
    receipts: tuple[ConditionReceipt, ...]
    fingerprints: tuple[tuple[str, object], ...]
    source_event_ids: tuple[str, ...]
    processed_clock_receipts: tuple[tuple[str, tuple[object, ...], tuple[ExpiryReceipt, ...]], ...]
    latest_clock_seconds: int
    latest_clock_version: int


class ConditionStateService:
    """Condition-only authority attached to pre-existing Combatant identity refs.

    It is not a second mutable HP/equipment/actor store. A future Bookkeeper
    provider can replace this ledger; live Combat bridge belongs to DES-006.5.
    """

    def __init__(self, actors: EncounterActorIndex, authority: ConditionEventAuthority,
                 *, clock_id: str, definitions: tuple[ConditionDefinition, ...] = DEFAULT_CONDITIONS):
        if not isinstance(actors, EncounterActorIndex):
            raise ConditionError(ConditionErrorCode.INVALID, "Actor registry required")
        if not isinstance(authority, ConditionEventAuthority):
            raise ConditionError(ConditionErrorCode.UNAUTHORISED, "Trusted authority required")
        self.clock_id = _id(clock_id, "campaign clock")
        if not isinstance(definitions, tuple) or not definitions:
            raise ConditionError(ConditionErrorCode.INVALID, "Condition registry required")
        registry: dict[str, ConditionDefinition] = {}
        for definition in definitions:
            if not isinstance(definition, ConditionDefinition) or definition.code in registry:
                raise ConditionError(ConditionErrorCode.INVALID, "Duplicate or invalid condition definition")
            registry[definition.code] = definition
        self._definitions = registry
        self._actors = actors
        self._authority = authority
        self._lock = RLock()
        self._rows = {actor_id: ActorConditionSnapshot(actor_id, 0, ())
                      for actor_id in actors.actor_ids}
        self._receipts: dict[str, ConditionReceipt] = {}
        self._fingerprints: dict[str, object] = {}
        self._source_events: set[str] = set()
        self._clock_receipts: dict[str, tuple[tuple[object, ...], tuple[ExpiryReceipt, ...]]] = {}
        self._latest_seconds = 0
        self._latest_clock_version = 0

    def get_active(self, actor_id: str) -> ActorConditionSnapshot:
        """Trusted controller view; immutable full instance history (no HP)."""
        with self._lock:
            self._actors.get(actor_id)
            return self._rows[actor_id]

    def get_player_safe(self, actor_id: str, *, visible_actor_ids: tuple[str, ...]) -> tuple[str, ...]:
        """No hidden enemy statuses or rules/source/expiry/parameter disclosure."""
        with self._lock:
            actor = self._actors.get(actor_id)
            if not isinstance(visible_actor_ids, tuple) or actor_id not in visible_actor_ids:
                return ()
            # A supplied display allowlist is insufficient to disclose an
            # undiscovered opponent. Party character visibility is independent
            # of the generic monster's public-visibility flag.
            is_character = getattr(getattr(actor, "origin", None), "value", None) == "CHARACTER"
            if not actor.publicly_visible and not is_character:
                return ()
            return tuple(sorted({inst.code for inst in self._rows[actor_id].active}))

    def read_action_receipt(self, action_id: str) -> ConditionReceipt | None:
        _id(action_id, "action ID")
        with self._lock:
            return self._receipts.get(action_id)

    def _validate_command(self, command: ConditionCommand, operation: str,
                          source_rule_ref: str) -> None:
        if not isinstance(command, ConditionCommand) or not isinstance(command.evidence, VerifiedConditionEvent):
            raise ConditionError(ConditionErrorCode.UNAUTHORISED, "Typed trusted event required")
        for value, name in ((command.action_id, "action"),
                            (command.cause_event_id, "source event"),
                            (command.actor_id, "actor"),
                            (command.correlation_id, "correlation"),
                            (source_rule_ref, "rules source")):
            _id(value, name)
        _seconds(command.expected_actor_version, "expected actor version")
        proof = command.evidence
        if (proof._seal is not self._authority._seal or
                proof.source_event_id != command.cause_event_id or
                proof.target_actor_id != command.actor_id or
                proof.operation != operation or proof.source_rule_ref != source_rule_ref):
            raise ConditionError(ConditionErrorCode.UNAUTHORISED, "Unverified source event")
        self._actors.get(command.actor_id)

    def _mutate(self, command: ConditionCommand, operation: str,
                source_rule_ref: str, payload: object, change) -> ConditionReceipt:
        with self._lock:
            self._validate_command(command, operation, source_rule_ref)
            fingerprint = (operation, command, payload)
            previous = self._fingerprints.get(command.action_id)
            if previous is not None:
                if previous != fingerprint:
                    raise ConditionError(ConditionErrorCode.REPLAY_CONFLICT, "Conflicting action replay")
                return self._receipts[command.action_id]
            before = self._rows[command.actor_id]
            if before.condition_version != command.expected_actor_version:
                raise ConditionError(ConditionErrorCode.STALE_VERSION, "Stale actor conditions")
            if command.cause_event_id in self._source_events:
                raise ConditionError(ConditionErrorCode.DUPLICATE_EVENT, "Source event already applied")
            after, target_id, status = change(before)
            receipt = ConditionReceipt(command.action_id, command.cause_event_id,
                                       command.actor_id, target_id, operation,
                                       before.condition_version, after.condition_version,
                                       status, command.correlation_id)
            self._rows[command.actor_id] = after
            self._fingerprints[command.action_id] = fingerprint
            self._source_events.add(command.cause_event_id)
            self._receipts[command.action_id] = receipt
            return receipt

    def apply(self, request: ApplyCondition) -> ConditionReceipt:
        if not isinstance(request, ApplyCondition):
            raise ConditionError(ConditionErrorCode.INVALID, "Typed apply required")
        _id(request.instance_id, "condition instance")
        _id(request.code, "condition code")
        _id(request.ruleset_ref, "ruleset")
        _id(request.source_rule_ref, "source rule")
        if request.source_actor_id is not None:
            self._actors.get(request.source_actor_id)
        if not isinstance(request.house_overlay_refs, tuple) or not isinstance(request.parameters, tuple):
            raise ConditionError(ConditionErrorCode.INVALID, "Immutable tuple values required")
        for ref in request.house_overlay_refs:
            _id(ref, "overlay rule")
        keys: set[str] = set()
        for pair in request.parameters:
            if not isinstance(pair, tuple) or len(pair) != 2:
                raise ConditionError(ConditionErrorCode.INVALID, "Invalid typed parameters")
            key, value = pair
            _id(key, "parameter key")
            if key in keys or type(value) not in (str, int, bool):
                raise ConditionError(ConditionErrorCode.INVALID, "Invalid or duplicate parameter")
            keys.add(key)
        if request.applied_at_game_seconds is not None:
            _seconds(request.applied_at_game_seconds, "applied at")
            if request.applied_at_game_seconds != self._latest_seconds:
                raise ConditionError(ConditionErrorCode.INVALID_DEADLINE,
                                     "Application time must match verified clock projection")
        if request.expiry_at_game_seconds is not None:
            _seconds(request.expiry_at_game_seconds, "expiry")
            if (request.applied_at_game_seconds is None or
                    request.expiry_at_game_seconds <= request.applied_at_game_seconds):
                raise ConditionError(ConditionErrorCode.INVALID_DEADLINE,
                                     "Expiry must follow a verified application time")
        definition = self._definitions.get(request.code)
        if definition is None:
            raise ConditionError(ConditionErrorCode.UNKNOWN_CONDITION, "Condition not registered")

        def change(old: ActorConditionSnapshot):
            if any(inst.instance_id == request.instance_id for row in self._rows.values()
                   for inst in row.instances):
                raise ConditionError(ConditionErrorCode.DUPLICATE_EVENT, "Instance ID already exists")
            if not definition.independent_instances and any(
                    c.code == request.code and c.status is ConditionStatus.ACTIVE
                    for c in old.instances):
                raise ConditionError(ConditionErrorCode.UNSUPPORTED_STACKING,
                                     "Same condition requires explicit stacking policy")
            inst = ConditionInstance(request.instance_id, request.command.actor_id,
                                     request.code, request.source_actor_id,
                                     request.command.cause_event_id, request.ruleset_ref,
                                     request.source_rule_ref, request.house_overlay_refs,
                                     request.applied_at_game_seconds,
                                     request.expiry_at_game_seconds,
                                     request.parameters, ConditionStatus.ACTIVE)
            return (replace(old, condition_version=old.condition_version + 1,
                            instances=old.instances + (inst,)), request.instance_id,
                    ConditionStatus.ACTIVE)

        return self._mutate(request.command, "APPLY", request.source_rule_ref, request, change)

    def remove(self, request: RemoveCondition) -> ConditionReceipt:
        if not isinstance(request, RemoveCondition):
            raise ConditionError(ConditionErrorCode.INVALID, "Typed remove required")
        _id(request.instance_id, "condition instance")
        _id(request.source_rule_ref, "source rule")

        def change(old: ActorConditionSnapshot):
            found = next((inst for inst in old.instances
                          if inst.instance_id == request.instance_id), None)
            if found is None or found.status is not ConditionStatus.ACTIVE:
                raise ConditionError(ConditionErrorCode.NOT_ACTIVE, "Condition is not active")
            updated = tuple(replace(inst, status=ConditionStatus.REMOVED,
                                    removed_by_event_id=request.command.cause_event_id)
                            if inst.instance_id == request.instance_id else inst
                            for inst in old.instances)
            return (replace(old, condition_version=old.condition_version + 1,
                            instances=updated), request.instance_id, ConditionStatus.REMOVED)

        return self._mutate(request.command, "REMOVE", request.source_rule_ref,
                            request, change)

    def get_due(self, now_game_seconds: int) -> tuple[tuple[str, str], ...]:
        """Read-only projection of rule-validated deadlines; no automatic cure."""
        _seconds(now_game_seconds, "game time")
        with self._lock:
            return tuple(sorted((actor_id, c.instance_id) for actor_id, row in self._rows.items()
                                for c in row.active if c.expiry_at_game_seconds is not None
                                and c.expiry_at_game_seconds <= now_game_seconds))

    def process_due(self, clock_receipt: object, *, authority: ConditionEventAuthority) -> tuple[ExpiryReceipt, ...]:
        """Consume injected verified GameClock receipt; integration in DES-006.5.

        In-process trusted caller must supply the ORIGINAL authority object.
        No wall clock, effects, saving throws or independent scheduler.
        """
        from aidm.timekeeping.clock import ClockAdvanceReceipt

        if authority is not self._authority:
            raise ConditionError(ConditionErrorCode.UNAUTHORISED, "Trusted expiry caller required")
        if not isinstance(clock_receipt, ClockAdvanceReceipt):
            raise ConditionError(ConditionErrorCode.UNAUTHORISED, "Actual clock receipt required")
        if (clock_receipt.clock_id != self.clock_id or
                type(clock_receipt.elapsed_before) is not int or
                type(clock_receipt.elapsed_after) is not int or
                clock_receipt.elapsed_before < 0 or
                clock_receipt.elapsed_after < clock_receipt.elapsed_before or
                clock_receipt.delta_seconds != clock_receipt.elapsed_after - clock_receipt.elapsed_before or
                clock_receipt.new_version != clock_receipt.prior_version + 1):
            raise ConditionError(ConditionErrorCode.INVALID, "Invalid clock advance")
        with self._lock:
            fingerprint = (
                clock_receipt.clock_id, clock_receipt.action_id,
                clock_receipt.source_event_id, clock_receipt.kind,
                clock_receipt.elapsed_before, clock_receipt.elapsed_after,
                clock_receipt.delta_seconds, clock_receipt.prior_version,
                clock_receipt.new_version, clock_receipt.rules_profile_ref,
                clock_receipt.correlation_id, clock_receipt.caller_service,
                clock_receipt.encounter_id,
            )
            previous = self._clock_receipts.get(clock_receipt.receipt_id)
            if previous is not None:
                if previous[0] != fingerprint:
                    raise ConditionError(ConditionErrorCode.CLOCK_REPLAY, "Conflicting clock replay")
                return previous[1]
            if (clock_receipt.elapsed_before != self._latest_seconds or
                    clock_receipt.prior_version != self._latest_clock_version):
                raise ConditionError(ConditionErrorCode.CLOCK_REPLAY,
                                     "Stale or skipped clock advance")
            updates: dict[str, ActorConditionSnapshot] = {}
            emitted: list[ExpiryReceipt] = []
            for actor_id, row in self._rows.items():
                due = tuple(c for c in row.active if c.expiry_at_game_seconds is not None
                            and c.expiry_at_game_seconds <= clock_receipt.elapsed_after)
                if not due:
                    continue
                prior_version = row.condition_version
                new_instances = tuple(
                    replace(c, status=ConditionStatus.EXPIRED,
                            removed_by_event_id=f"clock:{clock_receipt.receipt_id}:{c.instance_id}")
                    if c in due else c for c in row.instances)
                for offset, c in enumerate(due):
                    emitted.append(ExpiryReceipt(clock_receipt.receipt_id, actor_id,
                                                 c.instance_id, prior_version + offset,
                                                 prior_version + offset + 1,
                                                 c.expiry_at_game_seconds))
                updates[actor_id] = replace(row, instances=new_instances,
                                            condition_version=prior_version + len(due))
            # Atomic commit after all due transitions have been planned.
            self._rows.update(updates)
            self._latest_seconds = clock_receipt.elapsed_after
            self._latest_clock_version = clock_receipt.new_version
            self._clock_receipts[clock_receipt.receipt_id] = (
                fingerprint, tuple(emitted))
            return tuple(emitted)

    def snapshot(self) -> ConditionLedgerSnapshot:
        with self._lock:
            return ConditionLedgerSnapshot(
                self.clock_id, tuple(self._rows.values()), tuple(self._receipts.values()),
                tuple(self._fingerprints.items()), tuple(sorted(self._source_events)),
                tuple((key, value[0], value[1]) for key, value in self._clock_receipts.items()),
                self._latest_seconds, self._latest_clock_version)

    @classmethod
    def restore(cls, snapshot: ConditionLedgerSnapshot, actors: EncounterActorIndex,
                authority: ConditionEventAuthority,
                *, definitions: tuple[ConditionDefinition, ...] = DEFAULT_CONDITIONS
                ) -> ConditionStateService:
        if not isinstance(snapshot, ConditionLedgerSnapshot):
            raise ConditionError(ConditionErrorCode.CORRUPT_SNAPSHOT, "Invalid ledger snapshot")
        service = cls(actors, authority, clock_id=snapshot.clock_id, definitions=definitions)
        try:
            rows = {r.actor_id: r for r in snapshot.actors}
            receipts = {r.action_id: r for r in snapshot.receipts}
            fingerprints = dict(snapshot.fingerprints)
            source_ids = set(snapshot.source_event_ids)
            seen_clock = {k: (fingerprint, entries) for k, fingerprint, entries
                          in snapshot.processed_clock_receipts}
            if (len(rows) != len(snapshot.actors) or
                    set(rows) != set(actors.actor_ids) or
                    len(receipts) != len(snapshot.receipts) or
                    len(fingerprints) != len(snapshot.fingerprints) or
                    set(receipts) != set(fingerprints) or
                    len(source_ids) != len(snapshot.source_event_ids) or
                    {r.cause_event_id for r in receipts.values()} != source_ids or
                    len(seen_clock) != len(snapshot.processed_clock_receipts) or
                    type(snapshot.latest_clock_seconds) is not int or
                    snapshot.latest_clock_seconds < 0 or
                    type(snapshot.latest_clock_version) is not int or
                    snapshot.latest_clock_version < 0 or
                    (seen_clock and max(fingerprint[8] for fingerprint, _ in seen_clock.values())
                     != snapshot.latest_clock_version) or
                    (not seen_clock and snapshot.latest_clock_version != 0) or
                    (seen_clock and max(fingerprint[5] for fingerprint, _ in seen_clock.values())
                     != snapshot.latest_clock_seconds) or
                    any(row.condition_version != len([r for r in receipts.values()
                                if r.actor_id == row.actor_id]) +
                                sum(e.actor_id == row.actor_id for _, entries in seen_clock.values()
                                    for e in entries)
                        for row in rows.values()) or
                    any(inst.actor_id != row.actor_id for row in rows.values()
                        for inst in row.instances)):
                raise ValueError("Ledger not internally consistent")
        except (TypeError, ValueError, AttributeError):
            raise ConditionError(ConditionErrorCode.CORRUPT_SNAPSHOT,
                                 "Inconsistent condition ledger") from None
        service._rows = rows
        service._receipts = receipts
        service._fingerprints = fingerprints
        service._source_events = source_ids
        service._clock_receipts = seen_clock
        service._latest_seconds = snapshot.latest_clock_seconds
        service._latest_clock_version = snapshot.latest_clock_version
        return service
