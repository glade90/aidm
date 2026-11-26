"""AIDM-DES-006.5: deterministic synthetic verified-event/clock bridge tests.

These are integration contract tests, NOT published Mentzer poison/Sleep rules.
Run: python -m pytest aidm/combat/test/test_condition_bridge.py -q
"""

from dataclasses import replace
import pytest

from aidm.combat.condition_bridge import (
    BridgeError, BridgeErrorCode, CombatConditionBridge,
    ConditionChangeProposal, VerifiedConditionEffect,
)
from aidm.combat.conditions import (
    ConditionError, ConditionErrorCode, ConditionEventAuthority,
    ConditionStateService, ConditionStatus, EncounterActorIndex,
)
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.state import Combatant, Controller, Origin
from aidm.timekeeping.clock import (
    ClockCommand, ClockEventAuthority, ClockRoundCompleted,
    GameClock, MENTZER_BASIC_1983,
)


class SyntheticRuleEvents:
    """Explicit fake trusted RULES results; never created from model output."""

    def __init__(self, *events):
        self.events = {event.event_id: event for event in events}

    def verified_condition_effect(self, event_id):
        return self.events.get(event_id)


def effect(event_id, actor_id, code, *, operation="APPLY", instance=None,
           source="test.synthetic-verified-effect", applied_at=None,
           expiry_at=None, verified=True, source_actor=None):
    return VerifiedConditionEffect(
        event_id, actor_id, code, operation,
        instance or "instance-" + event_id, source, "synthetic.test.profile",
        source_actor_id=source_actor,
        applied_at_game_seconds=applied_at, expiry_at_game_seconds=expiry_at,
        rule_verified=verified)


def proposal(fact, *, version=0, action_id=None, code=None, actor_id=None,
             rule_ref=None):
    return ConditionChangeProposal(
        actor_id or fact.actor_id, code or fact.condition_code, fact.operation,
        fact.event_id, version, action_id or "action-" + fact.event_id,
        "trace-" + fact.event_id, rule_ref or fact.source_rule_ref,
        original_player_text="I attempt the effect; a model suggestion is not a rule verdict")


def setup(*facts, clock_id="clock-bridge", visible=("alho", "orc-01", "orc-02", "orc-03")):
    ca = ClockEventAuthority()
    clock = GameClock.create_clock("campaign", MENTZER_BASIC_1983, ca, clock_id=clock_id)
    actors = EncounterActorIndex(canonical_three_vs_three().encounter.members)
    status_authority = ConditionEventAuthority()
    conditions = ConditionStateService(actors, status_authority, clock_id=clock_id)
    bridge = CombatConditionBridge(conditions, status_authority,
                                   actors, clock, SyntheticRuleEvents(*facts),
                                   visible_actor_ids=visible)
    return bridge, conditions, clock, ca, actors


def advance(clock, authority, round_id):
    event = f"verified-combat-round-{round_id}"
    envelope = ClockCommand(clock.clock_id, "COMBAT", f"clock-action-{round_id}",
                            event, clock.read_clock().version,
                            clock.profile.ref, "trace-" + event)
    completed = ClockRoundCompleted(
        envelope, "encounter", round_id,
        authority.completed_round(clock.clock_id, event, "encounter", round_id))
    return clock.complete_combat_round(completed)


def reject_without_mutation(bridge, code, call):
    snapshot = bridge.conditions.snapshot()
    with pytest.raises(BridgeError) as caught:
        call()
    assert caught.value.code == code
    assert bridge.conditions.snapshot() == snapshot


def test_f01_model_proposal_is_non_authoritative_and_no_source_event_blocks():
    bridge, service, clock, authority, actors = setup()
    p = ConditionChangeProposal("alho", "POISONED", "APPLY", "imaginary-hit", 0,
                                "action-imaginary", "trace-imaginary", "made-up-rule",
                                "The orc poisons Alho")
    reject_without_mutation(bridge, BridgeErrorCode.UNSUPPORTED_RULE,
                            lambda: bridge.submit(p))
    assert service.get_active("alho").active == ()
    assert actors.get("alho").hp_current == 8
    assert clock.read_clock().elapsed_game_seconds == 0


def test_f02_f03_synthetic_verified_effect_updates_real_pc_and_orc_refs():
    pc = effect("verified-poison", "alho", "POISONED", source_actor="orc-01")
    orc = effect("verified-sleep", "orc-01", "ASLEEP", source_actor="alho")
    bridge, service, clock, authority, actors = setup(pc, orc)
    a = bridge.submit(proposal(pc))
    b = bridge.submit(proposal(orc))
    assert a.receipt.status is ConditionStatus.ACTIVE
    assert b.receipt.status is ConditionStatus.ACTIVE
    assert a.receipt.actor_id == "alho" and b.receipt.actor_id == "orc-01"
    assert a.player_safe_message == "Alho gains POISONED status."
    assert b.player_safe_message == "Orc 1 gains ASLEEP status."
    assert service.get_active("alho").active[0].code == "POISONED"
    assert service.get_active("orc-01").active[0].code == "ASLEEP"
    assert actors.get("alho").hp_current == 8
    assert actors.get("orc-01").hp_current == 6
    assert clock.read_clock().elapsed_game_seconds == 0


def test_f02_proposal_cannot_change_rule_verified_target_status_rule_or_operation():
    proof = effect("verified-01", "alho", "POISONED")
    bridge, service, _, _, _ = setup(proof)
    for unsafe in (proposal(proof, actor_id="orc-01"),
                   proposal(proof, code="ASLEEP"),
                   proposal(proof, rule_ref="invented-rule"),
                   replace(proposal(proof), operation="REMOVE")):
        reject_without_mutation(bridge, BridgeErrorCode.MISMATCHED_EVIDENCE,
                                lambda p=unsafe: bridge.submit(p))
    assert service.get_active("alho").active == ()


def test_f02_unverified_rule_is_blocked():
    fact = effect("provisional", "alho", "POISONED", verified=False)
    bridge, *_ = setup(fact)
    reject_without_mutation(bridge, BridgeErrorCode.UNSUPPORTED_RULE,
                            lambda: bridge.submit(proposal(fact)))


def test_f03_replays_same_action_without_mutating_twice():
    first = effect("first", "alho", "POISONED")
    second = effect("second", "alho", "NAUSEATED")
    bridge, service, *_ = setup(first, second)
    p = proposal(first)
    old = bridge.submit(p).receipt
    bridge.submit(proposal(second, version=1))
    same = bridge.submit(p).receipt
    assert same is old
    assert service.get_active("alho").condition_version == 2
    assert len(service.get_active("alho").active) == 2
    with pytest.raises(ConditionError) as caught:
        bridge.submit(replace(p, correlation_id="different"))
    assert caught.value.code is ConditionErrorCode.REPLAY_CONFLICT


def test_f03_duplicate_source_event_new_action_and_stale_version_rejected():
    fact = effect("first", "alho", "POISONED")
    other = effect("second", "alho", "ASLEEP")
    bridge, service, *_ = setup(fact, other)
    bridge.submit(proposal(fact))
    with pytest.raises(ConditionError) as duplicate:
        bridge.submit(proposal(fact, version=1, action_id="another-id"))
    assert duplicate.value.code is ConditionErrorCode.DUPLICATE_EVENT
    with pytest.raises(ConditionError) as stale:
        bridge.submit(proposal(other, version=0))
    assert stale.value.code is ConditionErrorCode.STALE_VERSION
    assert service.get_active("alho").condition_version == 1


def test_f03_verified_remove_only_existing_instance():
    added = effect("add", "alho", "POISONED")
    removal = effect("remove", "alho", "POISONED", operation="REMOVE",
                     instance="instance-add")
    bridge, service, *_ = setup(added, removal)
    bridge.submit(proposal(added))
    removed = bridge.submit(proposal(removal, version=1))
    assert removed.receipt.status is ConditionStatus.REMOVED
    assert removed.player_safe_message == "Alho's POISONED status is removed."
    assert service.get_active("alho").active == ()


def test_f03_hidden_opponent_never_leaks_status_in_player_output():
    hidden = Combatant("unseen", "Hidden foe", "monsters", Origin.CREATURE,
                       "test.ref", Controller.SCRIPTED, 4, 4)
    seen = canonical_three_vs_three().encounter.members
    actors = EncounterActorIndex(tuple(seen) + (hidden,))
    ca = ClockEventAuthority()
    clock = GameClock.create_clock("campaign", MENTZER_BASIC_1983, ca,
                                   clock_id="clock-bridge")
    auth = ConditionEventAuthority()
    state = ConditionStateService(actors, auth, clock_id=clock.clock_id)
    fact = effect("secret", "unseen", "ASLEEP")
    bridge = CombatConditionBridge(
        state, auth, actors, clock, SyntheticRuleEvents(fact),
        visible_actor_ids=("alho", "unseen"))
    result = bridge.submit(proposal(fact))
    assert result.player_safe_message is None
    assert result.player_safe_codes == ()
    assert state.get_active("unseen").active[0].code == "ASLEEP"


def test_f04_source_validated_expiry_at_10_then_20_once():
    first = effect("e-poison", "alho", "POISONED", applied_at=0, expiry_at=10)
    second = effect("e-nausea", "alho", "NAUSEATED", applied_at=0, expiry_at=20)
    bridge, state, clock, auth, actors = setup(first, second)
    bridge.submit(proposal(first))
    bridge.submit(proposal(second, version=1))
    assert len(state.get_active("alho").active) == 2
    first_tick = advance(clock, auth, 1)
    processed = bridge.on_clock_advance(first_tick)
    assert len(processed.receipts) == 1
    assert len(state.get_active("alho").active) == 1
    assert state.get_active("alho").active[0].code == "NAUSEATED"
    assert bridge.on_clock_advance(first_tick) == processed  # exactly-once expiry
    second_tick = advance(clock, auth, 2)
    remaining = bridge.on_clock_advance(second_tick)
    assert len(remaining.receipts) == 1
    assert state.get_active("alho").active == ()
    assert state.get_active("alho").condition_version == 4
    assert clock.read_clock().elapsed_game_seconds == 20


def test_f04_no_deadline_does_not_expire_automatically():
    fact = effect("indefinite", "alho", "ASLEEP")
    bridge, state, clock, auth, _ = setup(fact)
    bridge.submit(proposal(fact))
    bridge.on_clock_advance(advance(clock, auth, 1))
    bridge.on_clock_advance(advance(clock, auth, 2))
    assert state.get_active("alho").active[0].code == "ASLEEP"


def test_f04_forged_or_wrong_clock_receipt_is_rejected():
    bridge, state, clock, auth, _ = setup()
    receipt = advance(clock, auth, 1)
    reject_without_mutation(bridge, BridgeErrorCode.UNTRUSTED_CLOCK,
                            lambda: bridge.on_clock_advance(replace(
                                receipt, elapsed_after=receipt.elapsed_after + 10)))
    reject_without_mutation(bridge, BridgeErrorCode.UNTRUSTED_CLOCK,
                            lambda: bridge.on_clock_advance(None))
    assert bridge.on_clock_advance(receipt).receipts == ()


def test_f04_catch_up_with_verified_ledger_and_no_double_expiry():
    fact = effect("deadline", "alho", "POISONED", applied_at=0, expiry_at=20)
    bridge, state, clock, auth, _ = setup(fact)
    bridge.submit(proposal(fact))
    advance(clock, auth, 1)
    advance(clock, auth, 2)
    results = bridge.reconcile_clock()
    assert len(results) == 2
    assert len(results[0].receipts) == 0
    assert len(results[1].receipts) == 1
    assert bridge.reconcile_clock() == ()
    assert state.get_active("alho").active == ()


def test_f02_f03_invalid_proposals_fail_without_source_mutations():
    fact = effect("test", "alho", "POISONED")
    bridge, state, *_ = setup(fact)
    for unsafe in (
        replace(proposal(fact), expected_actor_version=-1),
        replace(proposal(fact), operation="DELETE"),
        replace(proposal(fact), original_player_text=1),
        replace(proposal(fact), actor_id=""),
    ):
        reject_without_mutation(bridge, BridgeErrorCode.INVALID_PROPOSAL,
                                lambda p=unsafe: bridge.submit(p))
    assert state.get_active("alho").active == ()


def test_f05_idempotent_old_condition_action_after_later_clock_version():
    fact = effect("later-clock-replay", "alho", "POISONED",
                  applied_at=0, expiry_at=100)
    bridge, state, clock, auth, _ = setup(fact)
    original_proposal = proposal(fact)
    first_receipt = bridge.submit(original_proposal).receipt
    bridge.on_clock_advance(advance(clock, auth, 1))
    assert clock.read_clock().elapsed_game_seconds == 10
    replay_receipt = bridge.submit(original_proposal).receipt
    assert replay_receipt is first_receipt
    assert state.get_active("alho").condition_version == 1
