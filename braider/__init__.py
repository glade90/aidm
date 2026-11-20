"""Standalone Golden Braid generic agent contract (AIDM-DES-042.1).

Usage: from braider import Braider, ModelChoice, ContextItem
Change Log: 2026-11-20 COSTA — initial project-neutral public exports.
"""

from .core import (
    Braider, BraiderErrorCode, BraiderOutput, ContextItem,
    FakeModelRuntime, ModelChoice, ModelRuntime, ModelTarget,
)

__all__ = [
    "Braider", "BraiderErrorCode", "BraiderOutput", "ContextItem",
    "FakeModelRuntime", "ModelChoice", "ModelRuntime", "ModelTarget",
]