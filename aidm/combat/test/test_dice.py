"""AIDM-DES-005.2 raw dice: BON §10 RAW-01..06, RULE-01 and source regressions.

Usage: python -m pytest aidm/combat/test/test_dice.py -q --cov=aidm.combat.dice
Change Log: 2026-11-20 COSTA — replace obsolete modifier-based D01..D16 tests.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from dataclasses import FrozenInstanceError, asdict, fields
import json
import subprocess
import sys

import pytest

from aidm.combat.dice import (
    Die, DiceRoller, FixedRollOutOfRange, FixedRollSource, FixedRollsExhausted,
    InvalidDiceRequest, InvalidRollSource, RawDieResult, RollSourceKind,
    SourceFace, SystemRandomSource,
)


def die(name="blue-d20", sides=20, colour="blue"):
    return Die(name, sides, colour)


def roller(faces):
    source = FixedRollSource(faces)
    return DiceRoller(source), source


def test_raw01_selected_blue_d20_has_exact_unmodified_face_and_provenance():
    dr, src = roller([12])
    blue = die()
    result = dr.roll(blue, roll_id="attack-001", correlation_id="turn-101")
    assert result == RawDieResult("attack-001", blue.die_id, blue.sides,
                                  12, RollSourceKind.FIXED, 0,
                                  correlation_id="turn-101")
    assert src.cursor == 1
    assert not hasattr(result, "modifier")
    assert not hasattr(result, "total")


def test_raw02_distinct_selected_red_and_gold_d20s_with_same_face():
    dr, source = roller([14, 14])
    red = die("alho-red-d20", 20, "red")
    gold = die("evro-gold-d20", 20, "gold")
    a = dr.roll(red, roll_id="alho")
    b = dr.roll(gold, roll_id="evro")
    assert (a.face, b.face) == (14, 14)
    assert (a.die_id, b.die_id) == (red.die_id, gold.die_id)
    assert red.colour == "red" and gold.colour == "gold"
    assert source.cursor == 2


def test_raw03_heterogeneous_handful_raw_values_never_summed():
    dice = [die("blue-d8", 8), die("red-d6", 6, "red"),
            die("gold-d4", 4, "gold"), die("green-d4", 4, "green")]
    dr, src = roller([6, 4, 2, 3])
    result = dr.roll_many(dice, roll_group_id="group-1", correlation_id="turn-7")
    assert isinstance(result, tuple)
    assert [r.face for r in result] == [6, 4, 2, 3]
    assert [r.sides for r in result] == [8, 6, 4, 4]
    assert [r.die_id for r in result] == [d.die_id for d in dice]
    assert [r.roll_id for r in result] == [f"group-1:{i}" for i in (1,2,3,4)]
    assert [r.queue_position for r in result] == [0, 1, 2, 3]
    assert [r.die_index for r in result] == [1, 2, 3, 4]
    assert all(r.roll_group_id == "group-1" and r.correlation_id == "turn-7" for r in result)
    assert not hasattr(result[0], "raw_sum") and not hasattr(result[0], "total")
    assert src.cursor == 4


def test_raw04_exhaustion_entire_mixed_handful_is_atomic():
    dr, src = roller([6, 4, 2])
    with pytest.raises(FixedRollsExhausted):
        dr.roll_many((die("d8", 8), die("d6", 6), die("d4a", 4), die("d4b", 4)))
    assert src.cursor == 0
    assert dr.roll(die("blue-d8", 8)).face == 6


def test_raw04_invalid_later_mixed_face_is_atomic_even_if_early_values_valid():
    dr, src = roller([6, 4, 9, 3])
    with pytest.raises(FixedRollOutOfRange):
        dr.roll_many([die("d8", 8), die("d6", 6), die("d4a", 4), die("d4b", 4)])
    assert src.cursor == 0
    assert dr.roll(die("replacement-d8", 8)).face == 6


def test_raw04_invalid_first_face_preserves_queue_and_can_be_used_by_valid_die():
    dr, src = roller([7])
    with pytest.raises(FixedRollOutOfRange):
        dr.roll(die("bad-d6", 6))
    assert src.cursor == 0
    assert dr.roll(die("ok-d8", 8)).face == 7


def test_raw04_no_random_fallback_when_fixed_is_exhausted(monkeypatch):
    import secrets
    monkeypatch.setattr(secrets, "randbelow", lambda n: pytest.fail("Live RNG called"))
    dr, src = roller([6])
    with pytest.raises(FixedRollsExhausted):
        dr.roll_many((die("one", 6), die("two", 6)))
    assert src.cursor == 0
    assert dr.roll(die("one", 6)).face == 6


def test_raw04_fixed_source_direct_roll_many_preserved_for_homogeneous_calls():
    source = FixedRollSource([4, 3, 6])
    assert source.roll_many(1, 6) == (SourceFace(4, 0),)
    assert source.roll_many(2, 6) == (SourceFace(3, 1), SourceFace(6, 2))
    assert source.cursor == 3
    with pytest.raises(FixedRollsExhausted):
        source.roll_many(1, 6)
    assert source.cursor == 3


def test_raw04_rolling_single_dice_across_requests_preserves_queue_positions():
    dr, src = roller([1, 20])
    minimum = dr.roll(die(), roll_id="min")
    maximum = dr.roll(die(), roll_id="max")
    assert (minimum.face, maximum.face) == (1, 20)
    assert (minimum.queue_position, maximum.queue_position) == (0, 1)
    assert src.cursor == 2


def test_raw05_die_and_results_are_frozen():
    selected = die()
    result = roller([12])[0].roll(selected)
    for obj, attr, value in [(selected, "sides", 4), (selected, "colour", "red"),
                             (result, "face", 15), (result, "die_id", "another")]:
        with pytest.raises(FrozenInstanceError):
            setattr(obj, attr, value)


@pytest.mark.parametrize("field,value", [
    ("die_id", ""), ("die_id", " "), ("die_id", None), ("die_id", 4),
    ("die_id", "x" * 129), ("sides", 1), ("sides", 1001),
    ("sides", 0), ("sides", True), ("sides", False), ("sides", "20"),
    ("sides", 6.0), ("colour", ""), ("colour", "  "),
    ("colour", None), ("colour", 20), ("colour", "blue" * 30),
])
def test_raw05_invalid_die_attributes_rejected_before_source(field, value):
    dr, src = roller([12])
    selected = {"die_id": "blue-d20", "sides": 20, "colour": "blue"}
    selected[field] = value
    with pytest.raises(InvalidDiceRequest):
        dr.roll(Die(**selected))
    assert src.cursor == 0


def test_raw05_die_identity_conflict_within_a_handful_rejected_before_consumption():
    dr, src = roller([5, 6])
    with pytest.raises(InvalidDiceRequest, match="Conflicting"):
        dr.roll_many((die("same", 6, "red"), die("same", 6, "gold")))
    assert src.cursor == 0
    assert dr.roll(die("first", 6)).face == 5


def test_raw05_reusing_same_selected_die_twice_is_allowed():
    selected = die("one-favourite", 6, "blue")
    dr, source = roller([2, 5])
    results = dr.roll_many((selected, selected), roll_group_id="repeat")
    assert [(r.die_id, r.face) for r in results] == [(selected.die_id, 2), (selected.die_id, 5)]
    assert source.cursor == 2


def test_raw05_collection_ownership_is_not_falsely_verified():
    # User's synthetic assertion of a selected die is recorded, NOT validated
    # against a collection that this isolated tool does not own.
    result = roller([6])[0].roll(die("illustrative-collection-die", 8))
    assert result.die_id == "illustrative-collection-die"
    assert not hasattr(result, "owned_by")
    assert not hasattr(result, "collection_id")


def test_raw06_no_modifier_or_combat_fields_in_die_or_raw_result_contract():
    die_fields = {f.name for f in fields(Die)}
    raw_fields = {f.name for f in fields(RawDieResult)}
    assert die_fields == {"die_id", "sides", "colour"}
    assert raw_fields == {"roll_id", "die_id", "sides", "face", "source",
                          "queue_position", "die_index", "roll_group_id", "correlation_id"}
    banned = {"modifier", "total", "raw_sum", "weapon_ref", "attack_id",
              "damage", "strength", "armour_class", "purpose", "actor_id"}
    assert not (die_fields & banned)
    assert not (raw_fields & banned)


def test_raw06_dice_roller_rejects_modifier_or_dice_expression_not_ignores():
    dr, src = roller([12])
    with pytest.raises(TypeError):
        dr.roll(die(), modifier=3)
    with pytest.raises(TypeError):
        dr.roll_many([die()], modifier=3)
    with pytest.raises(InvalidDiceRequest):
        dr.roll("1d8+3")
    assert src.cursor == 0


def test_rule01_downstream_external_arithmetic_never_mutates_raw_12_or_5():
    dr, _ = roller([12, 5])
    attack_raw = dr.roll(die("evro-gold-d20", 20, "gold"), roll_id="attack")
    damage_raw = dr.roll(die("evro-sword-d8", 8, "red"), roll_id="damage")
    external_attack = attack_raw.face + 3
    external_damage = damage_raw.face + 3
    assert (external_attack, external_damage) == (15, 8)
    assert attack_raw.face == 12 and damage_raw.face == 5
    assert "modifier" not in asdict(attack_raw)


def test_raw_results_serialise_for_replay_without_a_second_rng_draw():
    dr, src = roller([4, 6])
    results = dr.roll_many([die("blue-d6", 6), die("gold-d6", 6, "gold")],
                           roll_group_id="group-2", correlation_id="corr-1")
    payload = json.loads(json.dumps([asdict(r) for r in results]))
    assert [p["face"] for p in payload] == [4, 6]
    assert [p["die_id"] for p in payload] == ["blue-d6", "gold-d6"]
    assert [p["queue_position"] for p in payload] == [0, 1]
    assert [p["source"] for p in payload] == ["FIXED", "FIXED"]
    assert src.cursor == 2


def test_auto_roll_and_group_ids_exist_but_no_die_ids_are_fabricated():
    dr, _ = roller([5, 4])
    a = dr.roll(die("selected", 6))
    b = dr.roll_many([die("also-selected", 6)])
    assert a.roll_id.startswith("roll-")
    assert b[0].roll_id.startswith("group-")
    assert b[0].roll_group_id is not None
    assert a.die_id == "selected" and b[0].die_id == "also-selected"


@pytest.mark.parametrize("field,value", [
    ("roll_id", ""), ("roll_id", "  "), ("roll_id", 4),
    ("roll_id", "x" * 129), ("correlation_id", "  "),
    ("correlation_id", True),
])
def test_invalid_single_roll_metadata_before_draw(field, value):
    dr, source = roller([3])
    with pytest.raises(InvalidDiceRequest):
        dr.roll(die("one", 6), **{field: value})
    assert source.cursor == 0


@pytest.mark.parametrize("field,value", [
    ("roll_group_id", ""), ("roll_group_id", 3),
    ("roll_group_id", "g" * 121), ("correlation_id", "  "),
    ("correlation_id", 5),
])
def test_invalid_group_metadata_before_draw(field, value):
    dr, source = roller([3])
    with pytest.raises(InvalidDiceRequest):
        dr.roll_many([die("one", 6)], **{field: value})
    assert source.cursor == 0


@pytest.mark.parametrize("selection", [[], (), [42], [die(), "2d6"], "die", None, object()])
def test_invalid_selected_dice_sequence_before_draw(selection):
    dr, src = roller([3])
    with pytest.raises(InvalidDiceRequest):
        dr.roll_many(selection)
    assert src.cursor == 0


def test_invalid_single_selected_die_before_draw():
    dr, src = roller([3])
    with pytest.raises(InvalidDiceRequest):
        dr.roll(6)
    assert src.cursor == 0


def test_too_many_dice_rejected_before_consumption():
    dr, src = roller([3])
    with pytest.raises(InvalidDiceRequest):
        dr.roll_many([die()] * 101)
    assert src.cursor == 0


def test_fixed_source_rejects_boolean_face_atomically():
    src = FixedRollSource([True])
    dr = DiceRoller(src)
    with pytest.raises(FixedRollOutOfRange):
        dr.roll(die("one", 6))
    assert src.cursor == 0


@pytest.mark.parametrize("source", [None, 1, object(), "FIXED"])
def test_invalid_injected_source_rejected(source):
    with pytest.raises(InvalidRollSource):
        DiceRoller(source)


@pytest.mark.parametrize("method,args", [
    ("roll_many", (True, 6)), ("roll_many", (1, False)),
    ("roll_many", (0, 6)), ("roll_many", (101, 6)),
    ("roll_sequence", ((),)), ("roll_sequence", ((1,),)),
    ("roll_sequence", ((True,),)), ("roll_sequence", ("6",)),
    ("roll_sequence", ((6,) * 101,)),
])
def test_source_validates_counts_sides_and_selection_before_consumption(method, args):
    for src in (FixedRollSource([3]), SystemRandomSource()):
        with pytest.raises(InvalidDiceRequest):
            getattr(src, method)(*args)
        if isinstance(src, FixedRollSource):
            assert src.cursor == 0


def test_system_random_source_unbiased_bounds_and_no_queue_offset(monkeypatch):
    import secrets
    calls = []
    def selected(n):
        calls.append(n)
        return 0 if len(calls) % 2 else n - 1
    monkeypatch.setattr(secrets, "randbelow", selected)
    dr = DiceRoller(SystemRandomSource())
    raws = dr.roll_many([die("blue", 20), die("red", 6, "red"),
                         die("gold", 4, "gold")], roll_group_id="live")
    assert [r.face for r in raws] == [1, 6, 1]
    assert calls == [20, 6, 4]
    assert all(r.source is RollSourceKind.SYSTEM_RANDOM and r.queue_position is None for r in raws)


def test_system_random_direct_homogeneous_source_remains_available(monkeypatch):
    import secrets
    monkeypatch.setattr(secrets, "randbelow", lambda n: n - 1)
    assert SystemRandomSource().roll_many(2, 6) == (SourceFace(6), SourceFace(6))


def test_import_and_roller_construction_have_no_random_side_effects():
    script = (
        "import secrets,sys; "
        "secrets.randbelow=lambda n: (_ for _ in ()).throw(AssertionError('import drew')); "
        "from aidm.combat.dice import Die,DiceRoller,FixedRollSource; "
        "d=Die('blue',6,'blue');r=DiceRoller(FixedRollSource([3])); "
        "assert 'crewai' not in sys.modules"
    )
    r = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_invalid_source_values_are_rejected_without_fake_numeric_outcomes():
    class FakeBadSource:
        kind = RollSourceKind.FIXED
        def __init__(self, draws):
            self.draws = draws
        def roll_sequence(self, sides):
            return self.draws
        def roll_many(self, count, sides):
            return self.draws
    for draws in ([], (SourceFace(1),), (SourceFace(0, 0),),
                  (SourceFace(True, 0),), (SourceFace(999, 0),),
                  (SourceFace(4, -1),), (SourceFace(4, None),)):
        with pytest.raises(InvalidRollSource):
            DiceRoller(FakeBadSource(draws)).roll(die("bad", 6))


def test_live_source_cannot_forge_fixed_offset():
    class BadLive:
        kind = RollSourceKind.SYSTEM_RANDOM
        def roll_sequence(self, sides):
            return (SourceFace(4, 0),)
        def roll_many(self, count, sides):
            return (SourceFace(4, 0),)
    with pytest.raises(InvalidRollSource):
        DiceRoller(BadLive()).roll(die("one", 6))


def test_invalid_source_result_for_second_selected_die_rejected():
    class BadMixed:
        kind = RollSourceKind.FIXED
        def roll_sequence(self, sides):
            return (SourceFace(2, 0), SourceFace(7, 1))
        def roll_many(self, count, sides):
            return self.roll_sequence((sides,) * count)
    with pytest.raises(InvalidRollSource):
        DiceRoller(BadMixed()).roll_many([die("d6", 6), die("d4", 4)])


def test_fixed_cursor_linearizable_across_concurrent_rolls():
    src = FixedRollSource(list(range(1, 21)))
    dr = DiceRoller(src)
    one = die("d20", 20)
    with ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(lambda i: dr.roll(one, roll_id=f"r-{i}"), range(20)))
    assert src.cursor == 20
    assert sorted(r.face for r in results) == list(range(1, 21))
    assert sorted(r.queue_position for r in results) == list(range(20))


def test_fixed_source_inserts_no_actor_or_weapon_metadata_into_raw_result():
    dr, src = roller([4])
    r = dr.roll(die("d6", 6))
    assert "actor_id" not in asdict(r)
    assert "weapon_ref" not in asdict(r)
    assert "damage" not in asdict(r)
    assert src.cursor == 1