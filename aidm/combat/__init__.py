"""AIDM combat specialist contracts and rules-neutral raw dice.

Usage: from aidm.combat import CombatAgent, Die, DiceRoller, RawDieResult
Change Log: 2026-11-20 COSTA — AIDM-DES-004.1 initial combat stub.
            2026-11-20 COSTA — AIDM-DES-005.2 raw dice architecture correction.
"""

from .agent import CombatAgent, MOCK_COMBAT_OPERATION
from .dice import (
    Die, DiceRoller, FixedRollOutOfRange, FixedRollSource, FixedRollsExhausted,
    InvalidDiceRequest, InvalidRollSource, RawDieResult, RollSource,
    RollSourceKind, SourceFace, SystemRandomSource,
)

__all__ = [
    "CombatAgent", "MOCK_COMBAT_OPERATION", "Die", "DiceRoller",
    "FixedRollOutOfRange", "FixedRollSource", "FixedRollsExhausted",
    "InvalidDiceRequest", "InvalidRollSource", "RawDieResult",
    "RollSource", "RollSourceKind", "SourceFace", "SystemRandomSource",
]