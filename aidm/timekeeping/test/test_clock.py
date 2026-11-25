"""AIDM-DES-017.2.1 T01–T14 offline authoritative-clock acceptance tests.

Run: python -m pytest aidm/timekeeping/test/test_clock.py -q
Change Log: 2026-11-25 COSTA — BON-approved GameClock technical acceptance.
"""

from __future__ import annotations

from dataclasses import replace

import pytest

from aidm.timekeeping.clock import (
    ClockAdvanceReceipt, ClockCombatClosedExceptional, ClockCombatSettled,
    ClockCommand, ClockError, ClockErrorCode, ClockEventAuthority,
    ClockExplorationTurnCompleted, ClockRoundCompleted, ClockSnapshot,
    GameClock, GameClockProfile, MENTZER_BASIC_1983,
)


def new_clock(profile=MENTZER_BASIC_1983, campaign='campaign-a', clock_id='clock-a'):
    issuer = ClockEventAuthority()
    return GameClock.create_clock(campaign, profile, issuer, clock_id=clock_id), issuer


def envelope(clock, action, event, caller='COMBAT', *, expected=None, profile=None):
    return ClockCommand(clock.clock_id, caller, action, event,
                        clock.read_clock().version if expected is None else expected,
                        clock.profile.ref if profile is None else profile,
                        'trace-' + action)


def round_complete(clock, issuer, round_id, battle='battle-1', *, action=None, event=None,
                   expected=None):
    action = action or f'round-action-{battle}-{round_id}'
    event = event or f'engine-round-{battle}-{round_id}'
    evidence = issuer.completed_round(clock.clock_id, event, battle, round_id)
    return ClockRoundCompleted(envelope(clock, action, event, expected=expected),
                               battle, round_id, evidence)


def turn_complete(clock, issuer, turn='turn-1', expedition='expedition-1', *, action=None):
    action = action or f'turn-action-{turn}'
    event = f'completed-turn-{turn}'
    evidence = issuer.completed_turn(clock.clock_id, event, expedition, turn)
    return ClockExplorationTurnCompleted(envelope(clock, action, event, 'EXPEDITION'),
                                         expedition, turn, evidence)


def settle(clock, issuer, battle='battle-1', action=None, event=None):
    action = action or 'settle-' + battle
    event = event or 'battle-close-' + battle
    evidence = issuer.closed_normal_combat(clock.clock_id, event, battle)
    return ClockCombatSettled(envelope(clock, action, event), battle, evidence)


def exception_close(clock, issuer, reason):
    event = f'battle-close-{reason}'
    evidence = issuer.closed_exceptional_combat(clock.clock_id, event, 'battle-1', reason)
    return ClockCombatClosedExceptional(
        envelope(clock, f'exit-{reason}', event), 'battle-1', reason, evidence)


def rounds(clock, issuer, count):
    for n in range(1, count + 1):
        receipt = clock.complete_combat_round(round_complete(clock, issuer, n))
        assert receipt.delta_seconds == clock.profile.combat_round_seconds


def rejected(clock, code, action):
    before = clock.snapshot()
    with pytest.raises(ClockError) as info:
        action()
    assert info.value.code == code
    assert clock.snapshot() == before


def test_t01_zero_read_immutable_and_wallclock_independent():
    c, _ = new_clock()
    assert c.read_clock().elapsed_game_seconds == 0
    assert c.read_clock().version == 0
    assert c.read_clock() == c.read_clock()
    assert c.snapshot().version == 0
    assert c.read_action_receipt('missing') is None


def test_t02_five_verified_rounds_exactly_fifty_seconds():
    c, issuer = new_clock()
    rounds(c, issuer, 5)
    assert c.read_clock().elapsed_game_seconds == 50
    assert c.read_clock().version == 5
    assert c.snapshot().encounters[0].accounted_round_seconds == 50


def test_t03_t04_five_rounds_settle_and_independent_exploration():
    c, issuer = new_clock()
    rounds(c, issuer, 5)
    final = c.settle_combat(settle(c, issuer))
    assert isinstance(final, ClockAdvanceReceipt)
    assert (final.elapsed_before, final.delta_seconds, final.elapsed_after) == (50, 550, 600)
    assert c.complete_exploration_turn(turn_complete(c, issuer)).elapsed_after == 1200
    # Raw arithmetic without settlement remains 50+600, though it is NOT a normal battle.
    d, other_issuer = new_clock(clock_id='clock-b')
    rounds(d, other_issuer, 5)
    assert d.read_clock().elapsed_game_seconds == 50
    rejected(d, ClockErrorCode.INVALID_TRANSITION,
             lambda: d.complete_exploration_turn(turn_complete(d, other_issuer)))


@pytest.mark.parametrize('num_rounds,expected', [(60, 600), (70, 700)])
def test_t05_t06_long_battles_settle_with_zero_delta(num_rounds, expected):
    c, issuer = new_clock()
    rounds(c, issuer, num_rounds)
    r = c.settle_combat(settle(c, issuer))
    assert r.delta_seconds == 0
    assert r.prior_version + 1 == r.new_version
    assert r.elapsed_after == expected
    rejected(c, ClockErrorCode.REPLAY_CONFLICT,
             lambda: c.settle_combat(settle(c, issuer, event='new-close')))


@pytest.mark.parametrize('reason', ['PURSUIT', 'INTERRUPTED', 'ABORTED'])
def test_t07_exceptional_combat_has_no_normal_recovery_settlement(reason):
    c, issuer = new_clock()
    rounds(c, issuer, 3)
    r = c.close_exceptional_combat(exception_close(c, issuer, reason))
    assert r.delta_seconds == 0
    assert c.read_clock().elapsed_game_seconds == 30
    rejected(c, ClockErrorCode.INVALID_TRANSITION,
             lambda: c.settle_combat(settle(c, issuer)))
    assert c.complete_exploration_turn(turn_complete(c, issuer)).elapsed_after == 630


def test_t08_paused_round_is_not_a_completion_event_and_resume_once():
    c, issuer = new_clock()
    rounds(c, issuer, 1)
    assert c.read_clock().elapsed_game_seconds == 10
    # No controller-issued verified completed-round evidence exists while PAUSED.
    unknown_issuer = ClockEventAuthority()
    forged = round_complete(c, unknown_issuer, 2)
    rejected(c, ClockErrorCode.UNAUTHORISED,
             lambda: c.complete_combat_round(forged))
    r = c.complete_combat_round(round_complete(c, issuer, 2))
    assert r.elapsed_after == 20
    assert c.complete_combat_round(round_complete(c, issuer, 2, expected=1)) == r


def test_t09_action_replay_returns_original_receipt_even_after_new_actions():
    c, issuer = new_clock()
    cmd = round_complete(c, issuer, 1)
    original = c.complete_combat_round(cmd)
    c.complete_combat_round(round_complete(c, issuer, 2))
    assert c.complete_combat_round(cmd) is original
    assert c.read_action_receipt(cmd.envelope.action_id) is original
    assert c.read_clock().elapsed_game_seconds == 20


def test_t10_conflicting_id_and_event_deduplication():
    c, issuer = new_clock()
    cmd = round_complete(c, issuer, 1)
    c.complete_combat_round(cmd)
    conflict = replace(cmd, round_id=2)
    rejected(c, ClockErrorCode.UNAUTHORISED,
             lambda: c.complete_combat_round(conflict))
    altered = replace(cmd, envelope=replace(cmd.envelope, correlation_id='changed'))
    rejected(c, ClockErrorCode.REPLAY_CONFLICT,
             lambda: c.complete_combat_round(altered))
    new_id = replace(cmd, envelope=replace(cmd.envelope, action_id='other-action',
                                          expected_version=1, correlation_id='new-trace'))
    rejected(c, ClockErrorCode.DUPLICATE_EVENT,
             lambda: c.complete_combat_round(new_id))
    duplicated_round = round_complete(c, issuer, 1, action='different', event='different')
    rejected(c, ClockErrorCode.DUPLICATE_EVENT,
             lambda: c.complete_combat_round(duplicated_round))


def test_t11_forged_wrong_clock_stale_unauthorised_and_profile_fail_closed():
    c, issuer = new_clock()
    cmd = round_complete(c, issuer, 1)
    rejected(c, ClockErrorCode.STALE_VERSION,
             lambda: c.complete_combat_round(replace(cmd, envelope=replace(
                 cmd.envelope, expected_version=2))))
    rejected(c, ClockErrorCode.WRONG_CLOCK,
             lambda: c.complete_combat_round(replace(cmd, envelope=replace(
                 cmd.envelope, clock_id='other-clock'))))
    rejected(c, ClockErrorCode.INVALID,
             lambda: c.complete_combat_round(replace(cmd, envelope=replace(
                 cmd.envelope, rules_profile_ref='unknown-profile'))))
    rejected(c, ClockErrorCode.UNAUTHORISED,
             lambda: c.complete_combat_round(replace(cmd, envelope=replace(
                 cmd.envelope, caller_service='PLAYER'))))
    fake = replace(cmd, evidence=replace(cmd.evidence, _seal=object()))
    rejected(c, ClockErrorCode.UNAUTHORISED,
             lambda: c.complete_combat_round(fake))
    rejected(c, ClockErrorCode.INVALID,
             lambda: c.complete_combat_round(replace(cmd, envelope=replace(
                 cmd.envelope, expected_version=-1))))


def test_t12_snapshot_restores_deduplication_and_settlement():
    c, issuer = new_clock()
    first = round_complete(c, issuer, 1)
    r1 = c.complete_combat_round(first)
    snapshot = c.snapshot()
    clone = GameClock.restore(snapshot, issuer)
    assert clone.read_clock() == c.read_clock()
    assert clone.complete_combat_round(first) == r1
    for clock in (c, clone):
        for n in (2, 3, 4, 5):
            clock.complete_combat_round(round_complete(clock, issuer, n))
        clock.settle_combat(settle(clock, issuer))
    assert clone.snapshot() == c.snapshot()
    again = GameClock.restore(c.snapshot(), issuer)
    original_settle = c.read_action_receipt('settle-battle-1')
    original_cmd = ClockCombatSettled(
        envelope(c, 'settle-battle-1', 'battle-close-battle-1', expected=5),
        'battle-1', issuer.closed_normal_combat(c.clock_id, 'battle-close-battle-1', 'battle-1'))
    assert again.settle_combat(original_cmd) == original_settle
    corrupt = replace(c.snapshot(), elapsed_game_seconds=999)
    with pytest.raises(ClockError) as info:
        GameClock.restore(corrupt, issuer)
    assert info.value.code == ClockErrorCode.CORRUPT_SNAPSHOT


def test_t13_handoff_and_isolation():
    a, issuer_a = new_clock()
    b, issuer_b = new_clock(campaign='campaign-b', clock_id='clock-b')
    ra = a.complete_combat_round(round_complete(a, issuer_a, 1))
    assert a.handoff_clock(1).clock_id == 'clock-a'
    assert a.handoff_clock(1).elapsed_game_seconds == 10
    rejected(a, ClockErrorCode.STALE_VERSION, lambda: a.handoff_clock(0))
    assert b.read_clock().elapsed_game_seconds == 0
    rejected(b, ClockErrorCode.WRONG_CLOCK,
             lambda: b.complete_combat_round(round_complete(a, issuer_a, 2)))
    assert a.read_action_receipt(ra.action_id) == ra
    assert b.read_action_receipt(ra.action_id) is None


def test_t14_alternate_profile_is_not_hardcoded():
    synthetic = GameClockProfile('synthetic-1', 7, 120, 180,
                                 'TEST-ONLY alternate time rules')
    c, issuer = new_clock(synthetic)
    rounds(c, issuer, 5)
    assert c.read_clock().elapsed_game_seconds == 35
    assert c.settle_combat(settle(c, issuer)).delta_seconds == 145
    assert c.complete_exploration_turn(turn_complete(c, issuer)).elapsed_after == 300
    with pytest.raises(ClockError):
        GameClockProfile('broken', True, 600, 600, 'source')


def test_unfinished_and_duplicate_actions_are_safe():
    c, issuer = new_clock()
    rejected(c, ClockErrorCode.INVALID_TRANSITION,
             lambda: c.settle_combat(settle(c, issuer)))
    rounds(c, issuer, 1)
    rejected(c, ClockErrorCode.INVALID_TRANSITION,
             lambda: c.complete_combat_round(round_complete(c, issuer, 3)))
    rejected(c, ClockErrorCode.INVALID_TRANSITION,
             lambda: c.complete_combat_round(round_complete(c, issuer, 2, battle='other')))
    rejected(c, ClockErrorCode.INVALID_TRANSITION,
             lambda: c.complete_exploration_turn(turn_complete(c, issuer)))


def test_snapshot_is_read_only_value_copy():
    c, issuer = new_clock()
    prior = c.snapshot()
    rounds(c, issuer, 1)
    assert prior.elapsed_game_seconds == 0
    assert c.snapshot().elapsed_game_seconds == 10
    with pytest.raises(Exception):
        prior.elapsed_game_seconds = -100