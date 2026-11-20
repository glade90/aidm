"""AIDM-owned, non-LLM Dungeon Master gateway for the first combat prototype.

Purpose: Expose the thin, injectable DungeonMasterAgent/Braider subclass.
Usage: from aidm.dm import DungeonMasterAgent
Change Log: 2026-11-20 DAVOS — AIDM-DES-015.2 gateway package.
"""

from .agent import DungeonMasterAgent

__all__ = ["DungeonMasterAgent"]
