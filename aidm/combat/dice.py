"""Source-injected, rules-neutral raw dice (AIDM-DES-005.2).

Purpose: Roll actual selected Die values; report unmodified faces and provenance.
Usage: DiceRoller(FixedRollSource([12])).roll(Die('blue-d20', 20, 'blue'))
Change Log: 2026-11-20 COSTA — owner-approved raw Die architecture (§10).

Dice have identity, sides and appearance, never combat modifiers. Rules and
state resolution belong to other services. DES-005.3 owns full combat batches.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from enum import Enum
import secrets
from threading import Lock
from typing import Protocol
from uuid import uuid4


class InvalidDiceRequest(ValueError):
    """Caller supplied an invalid die/selection/roll identifier."""


class FixedRollsExhausted(ValueError):
    """Fixed queue lacks faces; cursor did not move."""


class FixedRollOutOfRange(ValueError):
    """A queued face is invalid for the selected die; cursor did not move."""


class InvalidRollSource(ValueError):
    """Injected source violates the raw-face contract."""


class RollSourceKind(str, Enum):
    FIXED = "FIXED"
    SYSTEM_RANDOM = "SYSTEM_RANDOM"


_MAX_COUNT = 100
_MAX_SIDES = 1000


def _integer(value: object, *, lower: int, upper: int, field: str) -> None:
    if type(value) is not int or not lower <= value <= upper:
        raise InvalidDiceRequest(f"Invalid {field}: expected integer in [{lower}, {upper}]")


def _label(value: object, field: str, *, max_length: int = 128, optional: bool = False) -> None:
    if optional and value is None:
        return
    if not isinstance(value, str) or not value.strip() or len(value) > max_length:
        raise InvalidDiceRequest(f"Invalid {field}: expected nonblank string of at most {max_length} characters")


def _sides_sequence(sides: Sequence[int]) -> tuple[int, ...]:
    if not isinstance(sides, Sequence) or isinstance(sides, (str, bytes, bytearray)):
        raise InvalidDiceRequest("Expected an ordered dice sides sequence")
    if not 1 <= len(sides) <= _MAX_COUNT:
        raise InvalidDiceRequest("Invalid number of selected dice")
    result = tuple(sides)
    for value in result:
        _integer(value, lower=2, upper=_MAX_SIDES, field="sides")
    return result


@dataclass(frozen=True, slots=True)
class Die:
    """One selected collectible or explicitly registered virtual die.

    No face, actor, combat purpose, modifier or random source belongs to Die.
    Collection ownership and global uniqueness belong to a later resolver.
    """

    die_id: str
    sides: int
    colour: str

    def __post_init__(self) -> None:
        _label(self.die_id, "die_id")
        _integer(self.sides, lower=2, upper=_MAX_SIDES, field="sides")
        _label(self.colour, "colour", max_length=80)


@dataclass(frozen=True, slots=True)
class SourceFace:
    """Source-provided raw face, optionally with its fixed queue offset."""

    face: int
    queue_position: int | None = None


class RollSource(Protocol):
    """Injectable source; mixed-sided roll_sequence is all-or-nothing for FIXED."""

    kind: RollSourceKind

    def roll_sequence(self, sides: Sequence[int]) -> tuple[SourceFace, ...]: ...
    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]: ...


class FixedRollSource:
    """Ordered fixture queue; validates the ENTIRE selection before consuming."""

    kind = RollSourceKind.FIXED

    def __init__(self, faces: Sequence[int]) -> None:
        self._faces = tuple(faces)
        self._cursor = 0
        self._lock = Lock()

    @property
    def cursor(self) -> int:
        with self._lock:
            return self._cursor

    def roll_sequence(self, sides: Sequence[int]) -> tuple[SourceFace, ...]:
        selected = _sides_sequence(sides)
        with self._lock:
            start = self._cursor
            upcoming = self._faces[start:start + len(selected)]
            if len(upcoming) != len(selected):
                raise FixedRollsExhausted("Insufficient fixed roll faces")
            if any(type(face) is not int or not 1 <= face <= size
                   for face, size in zip(upcoming, selected)):
                raise FixedRollOutOfRange("Queued fixed face out of range for selected die")
            result = tuple(SourceFace(face, start + i) for i, face in enumerate(upcoming))
            self._cursor += len(selected)
            return result

    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]:
        _integer(count, lower=1, upper=_MAX_COUNT, field="count")
        _integer(sides, lower=2, upper=_MAX_SIDES, field="sides")
        return self.roll_sequence((sides,) * count)


class SystemRandomSource:
    """Unbiased local RNG. No LLM, network or external entropy provider."""

    kind = RollSourceKind.SYSTEM_RANDOM

    def roll_sequence(self, sides: Sequence[int]) -> tuple[SourceFace, ...]:
        selected = _sides_sequence(sides)
        return tuple(SourceFace(secrets.randbelow(size) + 1) for size in selected)

    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]:
        _integer(count, lower=1, upper=_MAX_COUNT, field="count")
        _integer(sides, lower=2, upper=_MAX_SIDES, field="sides")
        return self.roll_sequence((sides,) * count)


@dataclass(frozen=True, slots=True)
class RawDieResult:
    """One immutable numeric fact; its meaning is owned by the Rules Engine."""

    roll_id: str
    die_id: str
    sides: int
    face: int
    source: RollSourceKind
    queue_position: int | None
    die_index: int = 1
    roll_group_id: str | None = None
    correlation_id: str | None = None


class DiceRoller:
    """Roll selected dice; never receives or calculates modifiers/totals."""

    def __init__(self, source: RollSource) -> None:
        if (not isinstance(getattr(source, "kind", None), RollSourceKind)
                or not callable(getattr(source, "roll_sequence", None))
                or not callable(getattr(source, "roll_many", None))):
            raise InvalidRollSource("Source must supply kind, roll_sequence and roll_many")
        self.source = source

    def _draw(self, sides: Sequence[int]) -> tuple[SourceFace, ...]:
        draws = self.source.roll_sequence(sides)
        if not isinstance(draws, tuple) or len(draws) != len(sides):
            raise InvalidRollSource("Source returned incorrect face count")
        for item, size in zip(draws, sides):
            if not isinstance(item, SourceFace) or type(item.face) is not int or not 1 <= item.face <= size:
                raise InvalidRollSource("Source returned invalid face")
            if self.source.kind is RollSourceKind.FIXED:
                if type(item.queue_position) is not int or item.queue_position < 0:
                    raise InvalidRollSource("Fixed source must report queue offset")
            elif item.queue_position is not None:
                raise InvalidRollSource("Live source cannot report fixed queue offset")
        return draws

    def roll(self, die: Die, *, roll_id: str | None = None,
             correlation_id: str | None = None) -> RawDieResult:
        """Return precisely one unmodified face for the explicitly selected die."""
        if not isinstance(die, Die):
            raise InvalidDiceRequest("Expected a selected Die object")
        _label(roll_id, "roll_id", optional=True)
        _label(correlation_id, "correlation_id", optional=True)
        resolved_id = roll_id if roll_id is not None else f"roll-{uuid4().hex}"
        draw = self._draw((die.sides,))[0]
        return RawDieResult(resolved_id, die.die_id, die.sides, draw.face,
                            self.source.kind, draw.queue_position,
                            correlation_id=correlation_id)

    def roll_many(self, dice: Sequence[Die], *, roll_group_id: str | None = None,
                  correlation_id: str | None = None) -> tuple[RawDieResult, ...]:
        """Raw handful only: mixed sides, no rule/actor/weapon batch semantics.

        Fixed sources preflight every selected die atomically. DES-005.3 owns
        the richer multi-actor grouped request and combat association contract.
        """
        if not isinstance(dice, Sequence) or isinstance(dice, (str, bytes, bytearray)):
            raise InvalidDiceRequest("Expected selected dice sequence")
        if not 1 <= len(dice) <= _MAX_COUNT:
            raise InvalidDiceRequest("Invalid number of selected dice")
        selected = tuple(dice)
        if any(not isinstance(die, Die) for die in selected):
            raise InvalidDiceRequest("Every selected item must be a Die")
        _label(roll_group_id, "roll_group_id", optional=True, max_length=120)
        _label(correlation_id, "correlation_id", optional=True)
        # One stable identity cannot refer to contradictory physical metadata
        # within the same handful. Reusing the SAME die for several draws is fine.
        descriptors: dict[str, Die] = {}
        for die in selected:
            previous = descriptors.setdefault(die.die_id, die)
            if previous != die:
                raise InvalidDiceRequest("Conflicting descriptors for selected die_id")
        group_id = roll_group_id if roll_group_id is not None else f"group-{uuid4().hex}"
        draws = self._draw(tuple(die.sides for die in selected))
        return tuple(
            RawDieResult(f"{group_id}:{i + 1}", die.die_id, die.sides, draw.face,
                         self.source.kind, draw.queue_position, die_index=i + 1,
                         roll_group_id=group_id, correlation_id=correlation_id)
            for i, (die, draw) in enumerate(zip(selected, draws))
        )