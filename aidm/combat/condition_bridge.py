"""AIDM-DES-006.5 — trusted combat-condition proposal and clock bridge.

Purpose: A CombatAgent may *propose* a condition, but only an injected trusted
         rules-event provider may approve a source-verified effect. Conditions
         remain in DES-006.4; time remains in DES-017.2.1. No new game rules.
Usage: bridge = CombatConditionBridge(conditions, authority, actors, clock,
                                     verified_rule_events)
       result = bridge.submit(ConditionChangeProposal(...))
       expirations = bridge.on_clock_advance(clock_receipt)
Change Log: 2026-11-26 COSTA — first F01–F05 synthetic verified-event integration.

IMPORTANT: The current live CombatEngine has no source-verified condition events.
No real poison, Sleep spell, nausea, duration or condition-specific mechanics
are implied. RuleEventSource MUST be an internal deterministic rules provider,
never a model, browser request, or raw player-supplied JSON.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from threading import RLock
from typing import Protocol

from aidm.combat.conditions import (
    ApplyCondition, ConditionCommand, ConditionError, ConditionEventAuthority,
    ConditionReceipt, ConditionStateService, EncounterActorIndex,
    ExpiryReceipt, RemoveCondition,
)
from aidm.timekeeping.clock import ClockAdvanceReceipt, GameClock


class BridgeErrorCode(str, Enum):
    INVALID_PROPOSAL = "INVALID_PROPOSAL"
    UNSUPPORTED_RULE = "UNSUPPORTED_RULE"
    MISMATCHED_EVIDENCE = "MISMATCHED_EVIDENCE"
    UNTRUSTED_CLOCK = "UNTRUSTED_CLOCK"
    REPLAY_CONFLICT = "REPLAY_CONFLICT"


class BridgeError(ValueError):
    """Fail-closed public-safe integration rejection."""

    def __init__(self, code: BridgeErrorCode, message: str) -> None:
        self.code = code
        super().__init__(message)


def _id(value: object, name: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > 128:
        raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, f"Invalid {name}")


@dataclass(frozen=True, slots=True)
class ConditionChangeProposal:
    """Untrusted specialist proposal; contains NO authority or duration.

    Source-specific effect validation occurs AFTER proposal; player text alone
    cannot certify a hit, failed save, disease onset or spell application.
    """

    actor_id: str
    condition_code: str
    operation: str  # APPLY or REMOVE
    cause_event_id: str
    expected_actor_version: int
    action_id: str
    correlation_id: str
    source_rule_ref: str
    original_player_text: str = ""


@dataclass(frozen=True, slots=True)
class VerifiedConditionEffect:
    """Trusted deterministic rule result, NEVER authored by the LLM.

    A verified rules engine must establish a legal target, completed effect,
    source rule, valid duration, and exact instance identity before returning.
    This data class alone grants no authority; the provider injection is
    trusted only inside the server's Combat/Rules orchestration boundary.
    """

    event_id: str
    actor_id: str
    condition_code: str
    operation: str
    instance_id: str
    source_rule_ref: str
    ruleset_ref: str
    source_actor_id: str | None = None
    house_overlay_refs: tuple[str, ...] = ()
    applied_at_game_seconds: int | None = None
    expiry_at_game_seconds: int | None = None
    parameters: tuple[tuple[str, str | int | bool], ...] = ()
    rule_verified: bool = False


class RuleEventSource(Protocol):
    """Trusted internal rules/Combat event lookup; must not expose model input."""

    def verified_condition_effect(self, event_id: str) -> VerifiedConditionEffect | None: ...


@dataclass(frozen=True, slots=True)
class ConditionBridgeResult:
    """Server-internal receipt. Expose ONLY player_safe_* through DM/Meta."""

    receipt: ConditionReceipt
    player_safe_message: str | None
    player_safe_codes: tuple[str, ...]
    source_event_id: str
    correlation_id: str
    private_original_player_text: str
    private_source_rule_ref: str


@dataclass(frozen=True, slots=True)
class ConditionExpiryResult:
    clock_receipt_id: str
    receipts: tuple[ExpiryReceipt, ...]
    player_safe_messages: tuple[str, ...]


class CombatConditionBridge:
    """Trusted glue only. No duplicate HP/actor store, clock or source rules.

    The accepted RuleEventSource is an injected *server-controlled* provider.
    Calling this bridge with a raw model proposal alone never mints evidence.
    The ConditionStateService remains the single mutation/version authority.
    """

    def __init__(
        self, conditions: ConditionStateService,
        condition_authority: ConditionEventAuthority,
        actors: EncounterActorIndex,
        clock: GameClock,
        rule_events: RuleEventSource,
        *,
        visible_actor_ids: tuple[str, ...] = (),
    ) -> None:
        if not isinstance(conditions, ConditionStateService):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Condition service required")
        if not isinstance(condition_authority, ConditionEventAuthority):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Condition capability required")
        if not isinstance(actors, EncounterActorIndex) or not isinstance(clock, GameClock):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Known actors and clock required")
        if conditions.clock_id != clock.clock_id:
            raise BridgeError(BridgeErrorCode.UNTRUSTED_CLOCK, "Campaign time identity mismatch")
        if not callable(getattr(rule_events, "verified_condition_effect", None)):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Rules-event provider required")
        if not isinstance(visible_actor_ids, tuple):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Visibility projection must be a tuple")
        for actor_id in visible_actor_ids:
            actors.get(actor_id)
        self.conditions = conditions
        self._authority = condition_authority
        self._actors = actors
        self._clock = clock
        self._rule_events = rule_events
        self._visible_actor_ids = visible_actor_ids
        self._lock = RLock()

    def _validate(self, proposal: ConditionChangeProposal) -> None:
        if not isinstance(proposal, ConditionChangeProposal):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Typed proposal required")
        for name in ("actor_id", "condition_code", "cause_event_id", "action_id",
                     "correlation_id", "source_rule_ref"):
            _id(getattr(proposal, name), name)
        if proposal.operation not in ("APPLY", "REMOVE"):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Invalid condition operation")
        if type(proposal.expected_actor_version) is not int or proposal.expected_actor_version < 0:
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Invalid actor version")
        if not isinstance(proposal.original_player_text, str):
            raise BridgeError(BridgeErrorCode.INVALID_PROPOSAL, "Invalid original text")

    def _verified_fact(self, proposal: ConditionChangeProposal) -> VerifiedConditionEffect:
        # No event in the authoritative source -> UNSUPPORTED, not speculative.
        event = self._rule_events.verified_condition_effect(proposal.cause_event_id)
        if event is None or not isinstance(event, VerifiedConditionEffect) or not event.rule_verified:
            raise BridgeError(BridgeErrorCode.UNSUPPORTED_RULE,
                              "No source-verified condition effect")
        if (event.event_id != proposal.cause_event_id or
                event.actor_id != proposal.actor_id or
                event.condition_code != proposal.condition_code or
                event.operation != proposal.operation or
                event.source_rule_ref != proposal.source_rule_ref):
            raise BridgeError(BridgeErrorCode.MISMATCHED_EVIDENCE,
                              "Proposed condition differs from verified effect")
        _id(event.instance_id, "verified condition instance")
        _id(event.ruleset_ref, "verified ruleset")
        _id(event.source_rule_ref, "verified source rule")
        if event.source_actor_id is not None:
            self._actors.get(event.source_actor_id)
        self._actors.get(event.actor_id)
        return event

    def _safe_projection(self, actor_id: str, code: str, operation: str
                         ) -> tuple[str | None, tuple[str, ...]]:
        allowed = self.conditions.get_player_safe(
            actor_id, visible_actor_ids=self._visible_actor_ids)
        actor = self._actors.get(actor_id)
        if actor_id not in self._visible_actor_ids:
            return None, ()
        is_character = getattr(getattr(actor, "origin", None), "value", None) == "CHARACTER"
        if not (actor.publicly_visible or is_character):
            return None, ()
        display = getattr(actor, "display_name", actor_id)
        if operation == "APPLY" and code in allowed:
            return f"{display} gains {code} status.", allowed
        if operation == "REMOVE":
            return f"{display}'s {code} status is removed.", allowed
        return None, allowed

    def submit(self, proposal: ConditionChangeProposal) -> ConditionBridgeResult:
        """Resolve trusted domain fact, then delegate one mutation to 006.4."""
        with self._lock:
            self._validate(proposal)
            fact = self._verified_fact(proposal)
            # Duration is CERTIFIED by the trusted source fact, never proposal.
            # Never silently backdate an application relative to GameClock.
            if (fact.applied_at_game_seconds is not None and
                    self.conditions.read_action_receipt(proposal.action_id) is None):
                if fact.applied_at_game_seconds != self._clock.read_clock().elapsed_game_seconds:
                    raise BridgeError(BridgeErrorCode.UNTRUSTED_CLOCK,
                                      "Verified effect timing inconsistent with GameClock")
            proof = self._authority.verified(
                fact.event_id, fact.actor_id, fact.operation, fact.source_rule_ref)
            command = ConditionCommand(
                proposal.action_id, fact.event_id, fact.actor_id,
                proposal.expected_actor_version, proposal.correlation_id, proof)
            if fact.operation == "APPLY":
                result = self.conditions.apply(ApplyCondition(
                    command, fact.instance_id, fact.condition_code,
                    fact.source_actor_id, fact.ruleset_ref, fact.source_rule_ref,
                    fact.house_overlay_refs, fact.applied_at_game_seconds,
                    fact.expiry_at_game_seconds, fact.parameters))
            else:
                result = self.conditions.remove(RemoveCondition(
                    command, fact.instance_id, fact.source_rule_ref))
            message, codes = self._safe_projection(
                fact.actor_id, fact.condition_code, fact.operation)
            return ConditionBridgeResult(
                result, message, codes, fact.event_id, proposal.correlation_id,
                proposal.original_player_text, fact.source_rule_ref)

    def on_clock_advance(self, receipt: ClockAdvanceReceipt) -> ConditionExpiryResult:
        """Only canonical receipts from the SAME authoritative clock are trusted."""
        with self._lock:
            if not isinstance(receipt, ClockAdvanceReceipt):
                raise BridgeError(BridgeErrorCode.UNTRUSTED_CLOCK,
                                  "Expected verified GameClock receipt")
            actual = self._clock.read_action_receipt(receipt.action_id)
            if actual is not receipt or receipt.clock_id != self._clock.clock_id:
                raise BridgeError(BridgeErrorCode.UNTRUSTED_CLOCK,
                                  "Clock receipt not found in authoritative ledger")
            expired = self.conditions.process_due(receipt, authority=self._authority)
            safe = []
            for entry in expired:
                status = self.conditions.get_active(entry.actor_id)
                instance = next(c for c in status.instances
                                if c.instance_id == entry.instance_id)
                msg, _ = self._safe_projection(entry.actor_id, instance.code, "REMOVE")
                if msg is not None:
                    safe.append(msg)
            return ConditionExpiryResult(receipt.receipt_id, expired, tuple(safe))

    def reconcile_clock(self) -> tuple[ConditionExpiryResult, ...]:
        """Catch up ordered verified events after handoff, never silently skip."""
        with self._lock:
            applied = self.conditions.snapshot().latest_clock_version
            return tuple(self.on_clock_advance(receipt)
                         for receipt in self._clock.snapshot().receipts
                         if receipt.new_version > applied)
