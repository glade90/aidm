"""AIDM-DES-017.2.1 — supplementary duplicate/recovery timing invariants."""

from dataclasses import replace

import pytest

from aidm.timekeeping.clock import (
    ClockCommand, ClockError, ClockErrorCode, ClockEventAuthority,
    ClockExplorationTurnCompleted, ClockRoundCompleted, ClockCombatClosedExceptional,
    ClockSnapshot, GameClock, MENTZER_BASIC_1983,
)


def new_clock():
    issuer = ClockEventAuthority()
    return GameClock.create_clock("campaign-a", MENTZER_BASIC_1983, issuer,
                                  clock_id="clock-a"), issuer


def event_command(clock, caller, action, event):
    return ClockCommand(clock.clock_id, caller, action, event,
                        clock.read_clock().version, clock.profile.ref, action)


def completed_turn(clock, issuer, turn="turn-1", action="turn-action-1",
                   event="expedition-event-1"):
    return ClockExplorationTurnCompleted(
        event_command(clock, "EXPEDITION", action, event), "expedition-a", turn,
        issuer.completed_turn(clock.clock_id, event, "expedition-a", turn))


def test_exploration_turn_id_is_deduplicated_even_with_different_source_event():
    clock, issuer = new_clock()
    first = clock.complete_exploration_turn(completed_turn(clock, issuer))
    assert first.elapsed_after == 600
    before = clock.snapshot()
    with pytest.raises(ClockError) as caught:
        clock.complete_exploration_turn(
            completed_turn(clock, issuer, action="another-action",
                           event="another-valid-event"))
    assert caught.value.code is ClockErrorCode.DUPLICATE_EVENT
    assert clock.snapshot() == before


def test_exploration_turn_dedup_survives_snapshot_restore():
    clock, issuer = new_clock()
    first = completed_turn(clock, issuer)
    receipt = clock.complete_exploration_turn(first)
    recovered = GameClock.restore(clock.snapshot(), issuer)
    assert recovered.complete_exploration_turn(first) == receipt
    with pytest.raises(ClockError) as caught:
        recovered.complete_exploration_turn(
            completed_turn(recovered, issuer, action="another-action",
                           event="another-valid-event"))
    assert caught.value.code is ClockErrorCode.DUPLICATE_EVENT


def test_five_rounds_then_exceptional_close_then_separate_turn_is_raw_650():
    clock, issuer = new_clock()
    for index in range(1, 6):
        event = f"engine-round-{index}"
        command = ClockRoundCompleted(
            event_command(clock, "COMBAT", f"action-{index}", event),
            "encounter-a", index,
            issuer.completed_round(clock.clock_id, event, "encounter-a", index))
        clock.complete_combat_round(command)
    assert clock.read_clock().elapsed_game_seconds == 50
    event = "verified-pursuit-close"
    close = ClockCombatClosedExceptional(
        event_command(clock, "COMBAT", "close-pursuit", event),
        "encounter-a", "PURSUIT",
        issuer.closed_exceptional_combat(clock.clock_id, event,
                                         "encounter-a", "PURSUIT"))
    assert clock.close_exceptional_combat(close).delta_seconds == 0
    assert clock.complete_exploration_turn(
        completed_turn(clock, issuer)).elapsed_after == 650
    # The 650s arithmetic is an EXCEPTIONAL closure, not a normal settled battle.


def test_clock_rejects_unknown_issuer_even_with_matching_completion_metadata():
    clock, issuer = new_clock()
    fake_issuer = ClockEventAuthority()
    valid = completed_turn(clock, issuer)
    forged = replace(valid, evidence=fake_issuer.completed_turn(
        clock.clock_id, valid.envelope.source_event_id,
        "expedition-a", "turn-1"))
    before = clock.snapshot()
    with pytest.raises(ClockError) as caught:
        clock.complete_exploration_turn(forged)
    assert caught.value.code is ClockErrorCode.UNAUTHORISED
    assert clock.snapshot() == before