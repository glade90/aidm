"""One rules-neutral AIDM dice request, deterministic queue and unbiased random source.

Purpose: Produce exact faces with per-die identity and replay-ready provenance.
Usage: DiceRoller(FixedRollSource([2, 5])).roll(RollRequest(2, 6, request_id="r", correlation_id="c"))
Change Log: 2026-11-20 COSTA — AIDM-DES-005.2 first single-expression roll increment.

DES-005.3 owns mixed-sided roll batches. This module does not validate D&D
rules, authorise collectible die IDs, commit events or modify game state.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import re
import secrets
from threading import Lock
from typing import Iterable, Protocol


class InvalidDiceRequest(ValueError):
    """Invalid roll request or unsupported dice expression (safe public message)."""


class FixedRollsExhausted(ValueError):
    """Not enough queued fixed values; no faces were consumed."""


class FixedRollOutOfRange(ValueError):
    """One of the next queued values cannot represent the requested die."""


class InvalidRollSource(ValueError):
    """Injected source did not obey the agreed typed die-source contract."""


class RollSourceKind(str, Enum):
    FIXED = "FIXED"
    SYSTEM_RANDOM = "SYSTEM_RANDOM"


_DICE = re.compile(r"(?P<count>[0-9]*)[dD](?P<sides>[0-9]+)(?:(?P<sign>[+-])(?P<modifier>[0-9]+))?\Z")
_MAX_COUNT = 100
_MAX_SIDES = 1000
_MAX_MODIFIER = 1_000_000


def _integer(value: object, *, lower: int, upper: int, field: str) -> None:
    if type(value) is not int or not lower <= value <= upper:
        raise InvalidDiceRequest(f"Invalid {field}: expected integer in [{lower}, {upper}]")


def _id(value: object, field: str, *, optional: bool = False) -> None:
    if optional and value is None:
        return
    if not isinstance(value, str) or not value.strip():
        raise InvalidDiceRequest(f"Missing or invalid {field}")


def _dice_bounds(count: object, sides: object) -> None:
    _integer(count, lower=1, upper=_MAX_COUNT, field="count")
    _integer(sides, lower=2, upper=_MAX_SIDES, field="sides")


def parse_dice_expression(expression: str) -> tuple[int, int, int]:
    """Strict dS/NdS±M parser; no arithmetic evaluator or rules decision."""
    if not isinstance(expression, str):
        raise InvalidDiceRequest("Invalid dice expression")
    match = _DICE.fullmatch(expression.strip())
    if match is None:
        raise InvalidDiceRequest("Unsupported dice expression")
    count = int(match["count"]) if match["count"] else 1
    sides = int(match["sides"])
    modifier = int(match["modifier"]) if match["modifier"] is not None else 0
    if match["sign"] == "-":
        modifier = -modifier
    _dice_bounds(count, sides)
    _integer(modifier, lower=-_MAX_MODIFIER, upper=_MAX_MODIFIER, field="modifier")
    return count, sides, modifier


@dataclass(frozen=True, slots=True)
class RollRequest:
    """Exactly one homogeneous dice expression; ID labels are not authority."""

    count: int = 1
    sides: int = 20
    modifier: int = 0
    request_id: str = ""
    correlation_id: str = ""
    purpose: str | None = None
    actor_id: str | None = None
    die_ids: tuple[str, ...] | None = None

    def __post_init__(self) -> None:
        _dice_bounds(self.count, self.sides)
        _integer(self.modifier, lower=-_MAX_MODIFIER, upper=_MAX_MODIFIER, field="modifier")
        _id(self.request_id, "request_id")
        _id(self.correlation_id, "correlation_id")
        _id(self.purpose, "purpose", optional=True)
        _id(self.actor_id, "actor_id", optional=True)
        if self.die_ids is not None:
            if not isinstance(self.die_ids, tuple) or len(self.die_ids) != self.count:
                raise InvalidDiceRequest("die_ids must be a tuple with one ID per die")
            for die_id in self.die_ids:
                _id(die_id, "die_id")

    @classmethod
    def from_expression(
        cls, expression: str, *, request_id: str, correlation_id: str,
        purpose: str | None = None, actor_id: str | None = None,
        die_ids: tuple[str, ...] | None = None,
    ) -> RollRequest:
        count, sides, modifier = parse_dice_expression(expression)
        return cls(count, sides, modifier, request_id, correlation_id, purpose, actor_id, die_ids)


@dataclass(frozen=True, slots=True)
class SourceFace:
    """One source-produced face, with optional zero-based fixed queue position."""

    face: int
    queue_position: int | None = None


class RollSource(Protocol):
    kind: RollSourceKind

    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]:
        """Return exactly count ordered faces; fixed implementations must preflight."""
        ...


class FixedRollSource:
    """Finite repeatable queue: validate entire next draw before advancing cursor."""

    kind = RollSourceKind.FIXED

    def __init__(self, faces: Iterable[int]) -> None:
        self._faces = tuple(faces)
        self._cursor = 0
        self._lock = Lock()

    @property
    def cursor(self) -> int:
        with self._lock:
            return self._cursor

    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]:
        _dice_bounds(count, sides)
        with self._lock:
            start = self._cursor
            upcoming = self._faces[start:start + count]
            if len(upcoming) != count:
                raise FixedRollsExhausted("Insufficient fixed roll faces")
            if any(type(face) is not int or not 1 <= face <= sides for face in upcoming):
                raise FixedRollOutOfRange("Queued fixed die face out of range")
            draws = tuple(SourceFace(face, start + i) for i, face in enumerate(upcoming))
            self._cursor += count
            return draws


class SystemRandomSource:
    """Ordinary independent local unbiased values, no network or LLM."""

    kind = RollSourceKind.SYSTEM_RANDOM

    def roll_many(self, count: int, sides: int) -> tuple[SourceFace, ...]:
        _dice_bounds(count, sides)
        return tuple(SourceFace(secrets.randbelow(sides) + 1) for _ in range(count))


@dataclass(frozen=True, slots=True)
class DieResult:
    """One ordered face and its declared identity, independent from RNG source."""

    die_index: int                  # 1-based in this request
    face: int
    sides: int
    source: RollSourceKind
    queue_position: int | None     # 0-based, only for FIXED
    die_id: str | None             # Unassigned when caller supplied no die ID


@dataclass(frozen=True, slots=True)
class RollResult:
    """Immutable replay-ready numeric fact, not a committed combat event."""

    request_id: str
    correlation_id: str
    count: int
    sides: int
    modifier: int
    purpose: str | None
    actor_id: str | None
    dice: tuple[DieResult, ...]
    raw_sum: int
    total: int
    source: RollSourceKind

    @property
    def faces(self) -> tuple[int, ...]:
        return tuple(die.face for die in self.dice)


class DiceRoller:
    """Typed single-request entry point. Never adjudicates or persists rolls."""

    def __init__(self, source: RollSource) -> None:
        if not isinstance(getattr(source, "kind", None), RollSourceKind) or not callable(
            getattr(source, "roll_many", None)
        ):
            raise InvalidRollSource("Source must provide kind and roll_many")
        self.source = source

    def roll(self, request: RollRequest) -> RollResult:
        if not isinstance(request, RollRequest):
            raise InvalidDiceRequest("Expected RollRequest")
        # The request's frozen dataclass already validated IDs, bounds and die_ids.
        source = self.source
        draws = source.roll_many(request.count, request.sides)
        if not isinstance(draws, tuple) or len(draws) != request.count:
            raise InvalidRollSource("Source returned wrong number of faces")
        for item in draws:
            if not isinstance(item, SourceFace) or type(item.face) is not int or not 1 <= item.face <= request.sides:
                raise InvalidRollSource("Source returned invalid face")
            if source.kind is RollSourceKind.FIXED:
                if type(item.queue_position) is not int or item.queue_position < 0:
                    raise InvalidRollSource("Fixed source missing queue position")
            elif item.queue_position is not None:
                raise InvalidRollSource("Live source cannot claim fixed queue position")
        dice = tuple(
            DieResult(i + 1, draw.face, request.sides, source.kind, draw.queue_position,
                      request.die_ids[i] if request.die_ids is not None else None)
            for i, draw in enumerate(draws)
        )
        raw_sum = sum(die.face for die in dice)
        return RollResult(
            request.request_id, request.correlation_id,
            request.count, request.sides, request.modifier, request.purpose,
            request.actor_id, dice, raw_sum, raw_sum + request.modifier, source.kind,
        )