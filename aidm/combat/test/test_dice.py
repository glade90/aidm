"""DES-005.2: synthetic source-backed dice test oracles D01–D16 and edge cases.

Usage: python -m pytest aidm/combat/test/test_dice.py --cov=aidm.combat.dice
Change Log: 2026-11-20 COSTA — first single-roll deterministic test suite.
"""

from __future__ import annotations

from dataclasses import FrozenInstanceError, asdict
import json
import subprocess
import sys

import pytest

from aidm.combat.dice import (
    DiceRoller, FixedRollOutOfRange, FixedRollSource, FixedRollsExhausted,
    InvalidDiceRequest, InvalidRollSource, RollRequest, RollSourceKind,
    SourceFace, SystemRandomSource, parse_dice_expression,
)


def request(expression="d20", *, die_ids=None, rid="req-a", cid="trace-1", **kw):
    return RollRequest.from_expression(expression, request_id=rid,
                                       correlation_id=cid, die_ids=die_ids, **kw)


def roll(expression, faces, **kwargs):
    source = FixedRollSource(faces)
    result = DiceRoller(source).roll(request(expression, **kwargs))
    return result, source


def test_d01_d20_min_max():
    minimum, _ = roll("d20", [1])
    maximum, _ = roll("1d20", [20])
    assert minimum.faces == (1,) and minimum.total == 1
    assert maximum.faces == (20,) and maximum.total == 20
    assert [d.die_index for d in maximum.dice] == [1]


def test_d02_2d6_plus_3():
    result, _ = roll("2d6+3", [2, 5])
    assert result.faces == (2, 5)
    assert (result.raw_sum, result.modifier, result.total) == (7, 3, 10)


def test_d03_3d4_minus_2():
    result, _ = roll("3d4-2", [1, 4, 2])
    assert result.faces == (1, 4, 2)
    assert (result.raw_sum, result.total) == (7, 5)


def test_d04_d100_and_uppercase_D_and_outer_whitespace():
    assert roll("d100", [100])[0].total == 100
    assert roll(" 1D8+1 \n", [8])[0].total == 9


def test_d05_queue_spans_requests_with_offsets_ids_and_purpose():
    source = FixedRollSource([4, 3, 6])
    roller = DiceRoller(source)
    first = roller.roll(request("1d6", purpose="fixture", actor_id="a"))
    second = roller.roll(request("2d6", rid="req-b", cid="trace-b"))
    assert first.faces == (4,) and second.faces == (3, 6)
    assert [die.queue_position for die in first.dice] == [0]
    assert [die.queue_position for die in second.dice] == [1, 2]
    assert [die.die_index for die in second.dice] == [1, 2]
    assert first.source is RollSourceKind.FIXED
    assert first.purpose == "fixture" and first.actor_id == "a"
    assert (second.request_id, second.correlation_id) == ("req-b", "trace-b")
    assert source.cursor == 3


def test_d06_fixed_exhaustion_never_consumes_partial_roll():
    source = FixedRollSource([5])
    roller = DiceRoller(source)
    with pytest.raises(FixedRollsExhausted):
        roller.roll(request("2d6"))
    assert source.cursor == 0
    assert roller.roll(request("d6")).faces == (5,)
    assert source.cursor == 1


def test_d07_invalid_face_leaves_cursor_unmodified():
    source = FixedRollSource([7])
    roller = DiceRoller(source)
    with pytest.raises(FixedRollOutOfRange):
        roller.roll(request("d6"))
    assert source.cursor == 0
    assert roller.roll(request("d8")).faces == (7,)


@pytest.mark.parametrize("expression", [
    "0d6", "d1", "d0", "101d6", "1d6+1d4", "2d6++1", "d6.5",
    "1d6 +3", "1d6+ 3", "2 d6", "d%", "d6!", "1d6kh1", "d6/2", "6",
    "-1d6", "d6-1000001", "d6+1000001", "d1001", "d6+", "", " ",
    "1d6\n1d6", "d6+1e2", "1d6+2-3", "d6.0", "d6=5",
])
def test_d08_malformed_expressions_atomic(expression):
    source = FixedRollSource([4])
    with pytest.raises(InvalidDiceRequest):
        DiceRoller(source).roll(request(expression))
    assert source.cursor == 0


@pytest.mark.parametrize("field,value", [
    ("count", True), ("sides", False), ("modifier", True),
    ("count", 0), ("count", 101), ("count", -1), ("count", 1.0),
    ("sides", 1), ("sides", 1001), ("sides", "6"),
    ("modifier", 1_000_001), ("modifier", -1_000_001), ("modifier", 2.5),
    ("request_id", ""), ("request_id", "  "), ("correlation_id", None),
    ("purpose", ""), ("actor_id", "  "),
])
def test_d08_bad_typed_request_atomic(field, value):
    source = FixedRollSource([4])
    kwargs = dict(count=1, sides=6, modifier=0,
                  request_id="req", correlation_id="cid")
    kwargs[field] = value
    with pytest.raises(InvalidDiceRequest):
        DiceRoller(source).roll(RollRequest(**kwargs))
    assert source.cursor == 0


def test_d09_negative_total_is_not_clamped():
    r, _ = roll("2d6-8", [1, 1])
    assert r.total == -6 and r.raw_sum == 2


def test_d10_fixed_source_never_calls_system_rng(monkeypatch):
    import secrets
    monkeypatch.setattr(secrets, "randbelow", lambda n: pytest.fail("used live RNG"))
    assert roll("2d6", [4, 6])[0].total == 10


def test_d10_no_rolls_on_import_and_protocol_does_not_pull_frameworks():
    script = (
        "import secrets, sys; "
        "secrets.randbelow=lambda _: (_ for _ in ()).throw(AssertionError('import rolled')); "
        "import aidm.combat.dice; "
        "assert 'crewai' not in sys.modules"
    )
    completed = subprocess.run([sys.executable, "-c", script],
                               capture_output=True, text=True, check=False)
    assert completed.returncode == 0, completed.stderr
    # Construction alone does not call a source.
    class FailingSource:
        kind = RollSourceKind.FIXED
        def roll_many(self, count, sides):
            raise AssertionError("rolled")
    DiceRoller(FailingSource())


def test_d11_replay_ready_json_without_reroll():
    r, source = roll("2d6+1", [4, 6], die_ids=("red-001", "gold-001"),
                     purpose="example", actor_id="synthetic")
    serialized = json.loads(json.dumps(asdict(r)))
    assert serialized["dice"][0]["face"] == 4
    assert serialized["dice"][1]["queue_position"] == 1
    assert serialized["dice"][1]["die_id"] == "gold-001"
    assert serialized["source"] == "FIXED" and serialized["total"] == 11
    assert serialized["request_id"] == "req-a"
    assert serialized["correlation_id"] == "trace-1"
    assert source.cursor == 2  # serialization does not consume another face
    with pytest.raises(FrozenInstanceError):
        r.total = 42
    with pytest.raises(FrozenInstanceError):
        r.dice[0].die_id = "other"


def test_d12_distinct_d20_die_ids_same_face():
    source = FixedRollSource([14, 14])
    roller = DiceRoller(source)
    a = roller.roll(request("d20", die_ids=("red-001",), rid="alho"))
    b = roller.roll(request("d20", die_ids=("gold-001",), rid="evro"))
    assert (a.faces, b.faces) == ((14,), (14,))
    assert a.dice[0].die_id == "red-001"
    assert b.dice[0].die_id == "gold-001"


@pytest.mark.parametrize("die_ids", [("blue-d6", "green-d6"), ("blue-d6", "blue-d6")])
def test_d13_ordered_selected_dice_and_repeats(die_ids):
    r, _ = roll("2d6", [2, 5], die_ids=die_ids)
    assert [die.die_id for die in r.dice] == list(die_ids)
    assert r.faces == (2, 5)


def test_d14_missing_die_identity_does_not_invent_preference():
    r, _ = roll("d20", [14])
    assert r.dice[0].die_id is None
    assert asdict(r)["dice"][0]["die_id"] is None


@pytest.mark.parametrize("bad", [("only-one",), ("blue", " "), (),
                                 ["blue", "green"], ("blue", 123)])
def test_d15_bad_die_ids_checked_before_rolling(bad):
    source = FixedRollSource([2, 5])
    roller = DiceRoller(source)
    with pytest.raises(InvalidDiceRequest):
        roller.roll(request("2d6", die_ids=bad))
    assert source.cursor == 0
    assert roller.roll(request("2d6", die_ids=("blue", "green"))).faces == (2, 5)


def test_d16_die_id_is_independent_of_numeric_face_or_appearance():
    source = FixedRollSource([7, 3])
    roller = DiceRoller(source)
    first = roller.roll(request("d8", die_ids=("favorite-d8",)))
    next_result = roller.roll(request("d8", die_ids=("favorite-d8",), rid="next"))
    assert first.dice[0].die_id == next_result.dice[0].die_id
    assert (first.faces, next_result.faces) == ((7,), (3,))
    assert set(asdict(first).keys()) == {"request_id", "correlation_id", "count", "sides",
                                       "modifier", "purpose", "actor_id", "dice",
                                       "raw_sum", "total", "source"}
    assert "appearance" not in asdict(first.dice[0])


def test_parser_returns_numbers_and_modifier_only():
    assert parse_dice_expression(" d6 ") == (1, 6, 0)
    assert parse_dice_expression("003D004-0002") == (3, 4, -2)
    with pytest.raises(InvalidDiceRequest):
        parse_dice_expression(12)
    with pytest.raises(InvalidDiceRequest):
        parse_dice_expression("d" + "9" * 5000)


def test_source_api_rejects_invalid_count_or_sides():
    for source in (FixedRollSource([1]), SystemRandomSource()):
        with pytest.raises(InvalidDiceRequest):
            source.roll_many(True, 6)
        with pytest.raises(InvalidDiceRequest):
            source.roll_many(1, False)


def test_fixed_invalid_bool_face_atomic():
    source = FixedRollSource([True])
    with pytest.raises(FixedRollOutOfRange):
        source.roll_many(1, 6)
    assert source.cursor == 0


def test_system_random_source_uses_unbiased_range_and_has_no_queue_position(monkeypatch):
    import secrets
    drawn = []
    def known(n):
        drawn.append(n)
        return [0, n - 1][len(drawn) - 1]
    monkeypatch.setattr(secrets, "randbelow", known)
    result = DiceRoller(SystemRandomSource()).roll(request("2d6"))
    assert result.faces == (1, 6)
    assert drawn == [6, 6]
    assert result.source == RollSourceKind.SYSTEM_RANDOM
    assert [die.queue_position for die in result.dice] == [None, None]


@pytest.mark.parametrize("source", [None, object(), "fixed", 42])
def test_invalid_source_rejected(source):
    with pytest.raises(InvalidRollSource):
        DiceRoller(source)


def test_wrong_input_rejected_before_source():
    source = FixedRollSource([2])
    with pytest.raises(InvalidDiceRequest):
        DiceRoller(source).roll("d6")
    assert source.cursor == 0


@pytest.mark.parametrize("faces", [
    (), [2], (SourceFace(2),), [2, 100],
    (SourceFace(0, 0), SourceFace(2, 1)),
    (SourceFace(True, 0), SourceFace(2, 1)),
    (SourceFace(2, 0), SourceFace(99, 1)),
])
def test_bad_injected_source_response_rejected(faces):
    class BadSource:
        kind = RollSourceKind.FIXED
        def roll_many(self, count, sides):
            return faces
    with pytest.raises(InvalidRollSource):
        DiceRoller(BadSource()).roll(request("2d6"))


def test_fixed_source_must_provide_valid_offsets():
    class BadSource:
        kind = RollSourceKind.FIXED
        def roll_many(self, count, sides):
            return (SourceFace(2, None),)
    with pytest.raises(InvalidRollSource):
        DiceRoller(BadSource()).roll(request("d6"))


def test_live_source_cannot_claim_fixed_queue_offset():
    class BadSource:
        kind = RollSourceKind.SYSTEM_RANDOM
        def roll_many(self, count, sides):
            return (SourceFace(2, 0),)
    with pytest.raises(InvalidRollSource):
        DiceRoller(BadSource()).roll(request("d6"))