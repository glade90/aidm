"""AIDM combat specialist contracts, not an authoritative combat engine.

Usage: from aidm.combat import CombatAgent, DiceRoller, FixedRollSource
Change Log: 2026-11-20 COSTA — AIDM-DES-004.1 first stub.
            2026-11-20 COSTA — AIDM-DES-005.2 typed dice exports.
"""

from .agent import CombatAgent, MOCK_COMBAT_OPERATION
from .dice import (
    DiceRoller, DieResult, FixedRollOutOfRange, FixedRollSource, FixedRollsExhausted,
    InvalidDiceRequest, InvalidRollSource, RollRequest, RollResult, RollSource,
    RollSourceKind, SourceFace, SystemRandomSource, parse_dice_expression,
)

__all__ = [
    "CombatAgent", "MOCK_COMBAT_OPERATION", "DiceRoller", "DieResult",
    "FixedRollOutOfRange", "FixedRollSource", "FixedRollsExhausted",
    "InvalidDiceRequest", "InvalidRollSource", "RollRequest", "RollResult",
    "RollSource", "RollSourceKind", "SourceFace", "SystemRandomSource",
    "parse_dice_expression",
]