"""AIDM-DES-017.2.1 — authoritative in-memory campaign GameClock.

Purpose: Account for verified game-time events exactly once. The Clock never
         decides whether combat/exploration completed or changes actor state.
Usage: issuer = ClockEventAuthority()  # keep with trusted server-side services
       clock = GameClock.create_clock('campaign-1', MENTZER_BASIC_1983, issuer)
       proof = issuer.completed_round(clock.clock_id, 'engine-r1', 'battle-1', 1)
       receipt = clock.complete_combat_round(ClockRoundCompleted(
           ClockCommand(clock.clock_id, 'COMBAT', 'action-1', 'engine-r1',
                        0, MENTZER_BASIC_1983.ref, 'correlation-1'),
           'battle-1', 1, proof))
Change Log: 2026-11-25 COSTA — first technical GameClock increment.

In-process trusted-service boundary only; never expose ClockEventAuthority to
browser/LLM/untrusted plugins. No SQL, wallclock, calendar, timed effects or
automatic attachment to CombatEngine in this increment.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from threading import RLock
from uuid import uuid4


class ClockErrorCode(str, Enum):
    INVALID = "INVALID"
    UNAUTHORISED = "UNAUTHORISED"
    WRONG_CLOCK = "WRONG_CLOCK"
    STALE_VERSION = "STALE_VERSION"
    REPLAY_CONFLICT = "REPLAY_CONFLICT"
    DUPLICATE_EVENT = "DUPLICATE_EVENT"
    INVALID_TRANSITION = "INVALID_TRANSITION"
    CORRUPT_SNAPSHOT = "CORRUPT_SNAPSHOT"


class ClockError(ValueError):
    """Typed, non-secret error; rejected mutations leave state unchanged."""

    def __init__(self, code: ClockErrorCode, message: str) -> None:
        self.code = code
        super().__init__(message)


def _check_id(value: object, label: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > 128:
        raise ClockError(ClockErrorCode.INVALID, f"Invalid {label}")


def _nonnegative(value: object, label: str) -> None:
    if type(value) is not int or value < 0:
        raise ClockError(ClockErrorCode.INVALID, f"Invalid {label}")


@dataclass(frozen=True, slots=True)
class GameClockProfile:
    """Versioned ruleset durations; synthetic profiles require a source label."""

    ref: str
    combat_round_seconds: int
    dungeon_turn_seconds: int
    normal_battle_minimum_seconds: int
    source_ref: str

    def __post_init__(self) -> None:
        _check_id(self.ref, "rules profile")
        _check_id(self.source_ref, "rules source")
        for name in ("combat_round_seconds", "dungeon_turn_seconds",
                     "normal_battle_minimum_seconds"):
            value = getattr(self, name)
            if type(value) is not int or value <= 0:
                raise ClockError(ClockErrorCode.INVALID, f"Invalid {name}")


MENTZER_BASIC_1983 = GameClockProfile(
    "mentzer-basic-1983-v1", 10, 600, 600,
    "Mentzer Basic Players Manual (1983), printed p.56; approved AIDM ADR-017.2-01/03",
)


class ClockEventKind(str, Enum):
    COMBAT_ROUND = "COMBAT_ROUND"
    EXPLORATION_TURN = "EXPLORATION_TURN"
    COMBAT_NORMAL_CLOSE = "COMBAT_NORMAL_CLOSE"
    COMBAT_EXCEPTIONAL_CLOSE = "COMBAT_EXCEPTIONAL_CLOSE"


@dataclass(frozen=True, slots=True)
class VerifiedClockEvent:
    """Opaque in-process evidence minted ONLY by trusted service authority."""

    clock_id: str
    source_event_id: str
    kind: ClockEventKind
    caller_service: str
    encounter_id: str | None = None
    round_id: int | None = None
    expedition_id: str | None = None
    turn_id: str | None = None
    close_reason: str | None = None
    _seal: object = field(default=None, repr=False, compare=False)


class ClockEventAuthority:
    """Capability issuer injected into trusted Combat/Expedition orchestrators.

    The authority must NEVER be passed to the browser, a model or a public tool.
    Attestation asserts that the authoritative domain verified completion;
    GameClock independently validates issuer, scope and replay/version details.
    """

    def __init__(self) -> None:
        self._seal = object()

    def completed_round(self, clock_id: str, event_id: str,
                        encounter_id: str, round_id: int) -> VerifiedClockEvent:
        return VerifiedClockEvent(clock_id, event_id, ClockEventKind.COMBAT_ROUND,
                                  "COMBAT", encounter_id=encounter_id,
                                  round_id=round_id, _seal=self._seal)

    def completed_turn(self, clock_id: str, event_id: str,
                       expedition_id: str, turn_id: str) -> VerifiedClockEvent:
        return VerifiedClockEvent(clock_id, event_id, ClockEventKind.EXPLORATION_TURN,
                                  "EXPEDITION", expedition_id=expedition_id,
                                  turn_id=turn_id, _seal=self._seal)

    def closed_normal_combat(self, clock_id: str, event_id: str,
                             encounter_id: str) -> VerifiedClockEvent:
        return VerifiedClockEvent(clock_id, event_id, ClockEventKind.COMBAT_NORMAL_CLOSE,
                                  "COMBAT", encounter_id=encounter_id,
                                  _seal=self._seal)

    def closed_exceptional_combat(self, clock_id: str, event_id: str,
                                  encounter_id: str, reason: str) -> VerifiedClockEvent:
        return VerifiedClockEvent(clock_id, event_id,
                                  ClockEventKind.COMBAT_EXCEPTIONAL_CLOSE,
                                  "COMBAT", encounter_id=encounter_id,
                                  close_reason=reason, _seal=self._seal)


@dataclass(frozen=True, slots=True)
class ClockCommand:
    clock_id: str
    caller_service: str
    action_id: str
    source_event_id: str
    expected_version: int
    rules_profile_ref: str
    correlation_id: str


@dataclass(frozen=True, slots=True)
class ClockRoundCompleted:
    envelope: ClockCommand
    encounter_id: str
    round_id: int
    evidence: VerifiedClockEvent


@dataclass(frozen=True, slots=True)
class ClockExplorationTurnCompleted:
    envelope: ClockCommand
    expedition_id: str
    turn_id: str
    evidence: VerifiedClockEvent


@dataclass(frozen=True, slots=True)
class ClockCombatSettled:
    envelope: ClockCommand
    encounter_id: str
    evidence: VerifiedClockEvent


@dataclass(frozen=True, slots=True)
class ClockCombatClosedExceptional:
    envelope: ClockCommand
    encounter_id: str
    reason: str  # PURSUIT / INTERRUPTED / ABORTED only
    evidence: VerifiedClockEvent


@dataclass(frozen=True, slots=True)
class ClockAdvanceReceipt:
    receipt_id: str
    clock_id: str
    action_id: str
    source_event_id: str
    kind: ClockEventKind
    elapsed_before: int
    elapsed_after: int
    delta_seconds: int
    prior_version: int
    new_version: int
    rules_profile_ref: str
    correlation_id: str
    caller_service: str
    encounter_id: str | None = None


@dataclass(frozen=True, slots=True)
class ClockRead:
    clock_id: str
    campaign_id: str
    elapsed_game_seconds: int
    version: int
    rules_profile_ref: str


@dataclass(frozen=True, slots=True)
class EncounterClockSnapshot:
    encounter_id: str
    round_ids: tuple[int, ...]
    accounted_round_seconds: int
    closed: bool
    closure_kind: str | None


@dataclass(frozen=True, slots=True)
class ClockSnapshot:
    clock_id: str
    campaign_id: str
    profile: GameClockProfile
    elapsed_game_seconds: int
    version: int
    receipts: tuple[ClockAdvanceReceipt, ...]
    action_fingerprints: tuple[tuple[str, tuple[object, ...]], ...]
    source_event_ids: tuple[str, ...]
    encounters: tuple[EncounterClockSnapshot, ...]
    exploration_turn_keys: tuple[tuple[str, str], ...]


class GameClock:
    """One in-memory authoritative clock; all changes guarded by a single lock."""

    def __init__(self, campaign_id: str, profile: GameClockProfile,
                 authority: ClockEventAuthority, *, clock_id: str | None = None) -> None:
        _check_id(campaign_id, "campaign")
        if not isinstance(profile, GameClockProfile):
            raise ClockError(ClockErrorCode.INVALID, "Invalid rules profile")
        if not isinstance(authority, ClockEventAuthority):
            raise ClockError(ClockErrorCode.UNAUTHORISED, "Trusted clock issuer required")
        self.clock_id = clock_id or f"clock-{uuid4().hex}"
        _check_id(self.clock_id, "clock")
        self.campaign_id = campaign_id
        self.profile = profile
        self._authority = authority
        self._lock = RLock()
        self._elapsed = 0
        self._version = 0
        self._receipts: dict[str, ClockAdvanceReceipt] = {}
        self._fingerprints: dict[str, tuple[object, ...]] = {}
        self._source_events: set[str] = set()
        self._encounters: dict[str, EncounterClockSnapshot] = {}
        self._exploration_turns: set[tuple[str, str]] = set()

    @classmethod
    def create_clock(cls, campaign_id: str, profile: GameClockProfile,
                     authority: ClockEventAuthority, *, clock_id: str | None = None
                     ) -> GameClock:
        return cls(campaign_id, profile, authority, clock_id=clock_id)

    def read_clock(self) -> ClockRead:
        with self._lock:
            return ClockRead(self.clock_id, self.campaign_id, self._elapsed,
                             self._version, self.profile.ref)

    def read_action_receipt(self, action_id: str) -> ClockAdvanceReceipt | None:
        _check_id(action_id, "action id")
        with self._lock:
            return self._receipts.get(action_id)

    def handoff_clock(self, expected_version: int) -> ClockRead:
        """Read the SAME identity for another trusted service; never advance."""
        with self._lock:
            _nonnegative(expected_version, "expected version")
            if expected_version != self._version:
                raise ClockError(ClockErrorCode.STALE_VERSION, "Stale clock handoff")
            return self.read_clock()

    def _execute(self, envelope: ClockCommand, evidence: VerifiedClockEvent,
                 kind: ClockEventKind, domain: tuple[object, ...],
                 encounter_id: str | None, apply: object) -> ClockAdvanceReceipt:
        with self._lock:
            if not isinstance(envelope, ClockCommand) or not isinstance(evidence, VerifiedClockEvent):
                raise ClockError(ClockErrorCode.INVALID, "Invalid clock command/evidence")
            for key, value in (("action id", envelope.action_id),
                               ("source event id", envelope.source_event_id),
                               ("correlation id", envelope.correlation_id),
                               ("caller", envelope.caller_service),
                               ("rules profile", envelope.rules_profile_ref)):
                _check_id(value, key)
            _nonnegative(envelope.expected_version, "expected version")
            fingerprint = (kind.value, envelope, domain,
                           evidence.clock_id, evidence.source_event_id,
                           evidence.kind, evidence.caller_service,
                           evidence.encounter_id, evidence.round_id,
                           evidence.expedition_id, evidence.turn_id,
                           evidence.close_reason)
            prior = self._fingerprints.get(envelope.action_id)
            if prior is not None:
                if prior != fingerprint:
                    raise ClockError(ClockErrorCode.REPLAY_CONFLICT, "Conflicting action replay")
                return self._receipts[envelope.action_id]
            if envelope.clock_id != self.clock_id or evidence.clock_id != self.clock_id:
                raise ClockError(ClockErrorCode.WRONG_CLOCK, "Wrong campaign clock")
            if envelope.expected_version != self._version:
                raise ClockError(ClockErrorCode.STALE_VERSION, "Stale clock version")
            if envelope.rules_profile_ref != self.profile.ref:
                raise ClockError(ClockErrorCode.INVALID, "Rules profile mismatch")
            if (evidence._seal is not self._authority._seal or evidence.kind != kind or
                    evidence.source_event_id != envelope.source_event_id or
                    evidence.caller_service != envelope.caller_service or
                    envelope.caller_service != ("EXPEDITION" if kind == ClockEventKind.EXPLORATION_TURN else "COMBAT")):
                raise ClockError(ClockErrorCode.UNAUTHORISED, "Trusted completion evidence required")
            if envelope.source_event_id in self._source_events:
                raise ClockError(ClockErrorCode.DUPLICATE_EVENT, "Completion event already applied")
            # Compute/check domain transition before changing any state.
            delta, updated_encounter = apply()
            _nonnegative(delta, "computed clock delta")
            before = self._elapsed
            after = before + delta
            receipt = ClockAdvanceReceipt(
                f"{self.clock_id}:{envelope.action_id}", self.clock_id,
                envelope.action_id, envelope.source_event_id, kind,
                before, after, delta, self._version, self._version + 1,
                self.profile.ref, envelope.correlation_id,
                envelope.caller_service, encounter_id,
            )
            self._elapsed = after
            self._version += 1
            if updated_encounter is not None:
                self._encounters[updated_encounter.encounter_id] = updated_encounter
            self._receipts[envelope.action_id] = receipt
            self._fingerprints[envelope.action_id] = fingerprint
            self._source_events.add(envelope.source_event_id)
            if kind == ClockEventKind.EXPLORATION_TURN:
                self._exploration_turns.add((str(domain[0]), str(domain[1])))
            return receipt

    def _other_unfinished(self, selected_id: str | None = None) -> bool:
        return any(not e.closed and e.encounter_id != selected_id
                   for e in self._encounters.values())

    def complete_combat_round(self, cmd: ClockRoundCompleted) -> ClockAdvanceReceipt:
        _check_id(cmd.encounter_id, "encounter")
        if type(cmd.round_id) is not int or cmd.round_id < 1:
            raise ClockError(ClockErrorCode.INVALID, "Invalid round id")
        if (cmd.evidence.encounter_id != cmd.encounter_id or
                cmd.evidence.round_id != cmd.round_id or
                cmd.evidence.expedition_id is not None):
            raise ClockError(ClockErrorCode.UNAUTHORISED, "Round proof mismatch")

        def apply():
            old = self._encounters.get(cmd.encounter_id)
            if self._other_unfinished(cmd.encounter_id):
                raise ClockError(ClockErrorCode.INVALID_TRANSITION,
                                 "Concurrent encounters not supported")
            if old is not None and old.closed:
                raise ClockError(ClockErrorCode.INVALID_TRANSITION, "Combat already closed")
            rounds = old.round_ids if old else ()
            if cmd.round_id in rounds:
                raise ClockError(ClockErrorCode.DUPLICATE_EVENT, "Round already completed")
            if rounds and cmd.round_id != max(rounds) + 1:
                raise ClockError(ClockErrorCode.INVALID_TRANSITION, "Nonsequential completed round")
            if not rounds and cmd.round_id != 1:
                raise ClockError(ClockErrorCode.INVALID_TRANSITION, "Battle must start at round one")
            delta = self.profile.combat_round_seconds
            return delta, EncounterClockSnapshot(
                cmd.encounter_id, rounds + (cmd.round_id,),
                (old.accounted_round_seconds if old else 0) + delta,
                False, None)

        return self._execute(cmd.envelope, cmd.evidence, ClockEventKind.COMBAT_ROUND,
                             (cmd.encounter_id, cmd.round_id), cmd.encounter_id, apply)

    def complete_exploration_turn(self, cmd: ClockExplorationTurnCompleted) -> ClockAdvanceReceipt:
        _check_id(cmd.expedition_id, "expedition")
        _check_id(cmd.turn_id, "exploration turn")
        if (cmd.evidence.expedition_id != cmd.expedition_id or
                cmd.evidence.turn_id != cmd.turn_id or
                cmd.evidence.encounter_id is not None):
            raise ClockError(ClockErrorCode.UNAUTHORISED, "Exploration proof mismatch")

        def apply():
            if self._other_unfinished():
                raise ClockError(ClockErrorCode.INVALID_TRANSITION,
                                 "Cannot count exploration during unresolved combat")
            if (cmd.expedition_id, cmd.turn_id) in self._exploration_turns:
                raise ClockError(ClockErrorCode.DUPLICATE_EVENT,
                                 "Exploration turn already completed")
            return self.profile.dungeon_turn_seconds, None

        return self._execute(cmd.envelope, cmd.evidence, ClockEventKind.EXPLORATION_TURN,
                             (cmd.expedition_id, cmd.turn_id), None, apply)

    def settle_combat(self, cmd: ClockCombatSettled) -> ClockAdvanceReceipt:
        _check_id(cmd.encounter_id, "encounter")
        if (cmd.evidence.encounter_id != cmd.encounter_id or
                cmd.evidence.close_reason is not None):
            raise ClockError(ClockErrorCode.UNAUTHORISED, "Normal close proof mismatch")

        def apply():
            old = self._encounters.get(cmd.encounter_id)
            if old is None or old.closed or not old.round_ids:
                raise ClockError(ClockErrorCode.INVALID_TRANSITION,
                                 "No verified unsettled battle")
            delta = max(0, self.profile.normal_battle_minimum_seconds -
                        old.accounted_round_seconds)
            return delta, EncounterClockSnapshot(
                old.encounter_id, old.round_ids, old.accounted_round_seconds,
                True, "NORMAL")

        return self._execute(cmd.envelope, cmd.evidence, ClockEventKind.COMBAT_NORMAL_CLOSE,
                             (cmd.encounter_id,), cmd.encounter_id, apply)

    def close_exceptional_combat(self, cmd: ClockCombatClosedExceptional) -> ClockAdvanceReceipt:
        _check_id(cmd.encounter_id, "encounter")
        if (cmd.reason not in ("PURSUIT", "INTERRUPTED", "ABORTED") or
                cmd.evidence.encounter_id != cmd.encounter_id or
                cmd.evidence.close_reason != cmd.reason):
            raise ClockError(ClockErrorCode.UNAUTHORISED, "Exceptional close proof mismatch")

        def apply():
            old = self._encounters.get(cmd.encounter_id)
            if old is None or old.closed or not old.round_ids:
                raise ClockError(ClockErrorCode.INVALID_TRANSITION,
                                 "No verified unsettled battle")
            return 0, EncounterClockSnapshot(
                old.encounter_id, old.round_ids, old.accounted_round_seconds,
                True, cmd.reason)

        return self._execute(cmd.envelope, cmd.evidence, ClockEventKind.COMBAT_EXCEPTIONAL_CLOSE,
                             (cmd.encounter_id, cmd.reason), cmd.encounter_id, apply)

    def snapshot(self) -> ClockSnapshot:
        with self._lock:
            return ClockSnapshot(self.clock_id, self.campaign_id, self.profile,
                                 self._elapsed, self._version,
                                 tuple(self._receipts.values()),
                                 tuple(self._fingerprints.items()),
                                 tuple(sorted(self._source_events)),
                                 tuple(self._encounters.values()),
                                 tuple(sorted(self._exploration_turns)))

    @classmethod
    def restore(cls, snapshot: ClockSnapshot, authority: ClockEventAuthority) -> GameClock:
        """Create a separate recovered clock; never overwrite an active clock."""
        if not isinstance(snapshot, ClockSnapshot):
            raise ClockError(ClockErrorCode.CORRUPT_SNAPSHOT, "Snapshot type invalid")
        clock = cls(snapshot.campaign_id, snapshot.profile, authority,
                    clock_id=snapshot.clock_id)
        try:
            _nonnegative(snapshot.elapsed_game_seconds, "snapshot seconds")
            _nonnegative(snapshot.version, "snapshot version")
            receipts = {r.action_id: r for r in snapshot.receipts}
            fingerprints = dict(snapshot.action_fingerprints)
            event_ids = set(snapshot.source_event_ids)
            encounters = {e.encounter_id: e for e in snapshot.encounters}
            turns = set(snapshot.exploration_turn_keys)
            if (len(receipts) != len(snapshot.receipts) or
                    len(fingerprints) != len(snapshot.action_fingerprints) or
                    len(event_ids) != len(snapshot.source_event_ids) or
                    len(encounters) != len(snapshot.encounters) or
                    len(turns) != len(snapshot.exploration_turn_keys) or
                    len(receipts) != snapshot.version or
                    set(receipts) != set(fingerprints) or
                    len(event_ids) != len(receipts) or
                    {r.source_event_id for r in receipts.values()} != event_ids or
                    len(turns) != sum(r.kind == ClockEventKind.EXPLORATION_TURN
                                      for r in receipts.values()) or
                    any(r.clock_id != snapshot.clock_id or
                        r.rules_profile_ref != snapshot.profile.ref
                        for r in receipts.values()) or
                    (snapshot.receipts and
                     (snapshot.receipts[-1].elapsed_after != snapshot.elapsed_game_seconds or
                      snapshot.receipts[-1].new_version != snapshot.version)) or
                    (not snapshot.receipts and snapshot.elapsed_game_seconds != 0)):
                raise ValueError("Inconsistent ledger")
        except (TypeError, ValueError, AttributeError, ClockError):
            raise ClockError(ClockErrorCode.CORRUPT_SNAPSHOT,
                             "Snapshot ledger inconsistent") from None
        clock._elapsed = snapshot.elapsed_game_seconds
        clock._version = snapshot.version
        clock._receipts = receipts
        clock._fingerprints = fingerprints
        clock._source_events = event_ids
        clock._encounters = encounters
        clock._exploration_turns = turns
        return clock