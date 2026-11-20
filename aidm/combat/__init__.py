"""AIDM combat specialist contracts, not an authoritative combat engine.

Usage: from aidm.combat import CombatAgent
Change Log: 2026-11-20 COSTA — AIDM-DES-004.1 first stub.
"""

from .agent import CombatAgent, MOCK_COMBAT_OPERATION

__all__ = ["CombatAgent", "MOCK_COMBAT_OPERATION"]