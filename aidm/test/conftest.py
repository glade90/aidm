"""Reusable controlled-roll fixture for tests beside AIDM source modules.

Purpose: Demonstrate deterministic dependency injection without game rules.
Usage: Inject the scripted_die fixture into tests in aidm/test/.
Change Log: 2026-11-17 COSTA — AIDM-DES-028.1 shared test fixture.
"""

from collections.abc import Callable

import pytest


@pytest.fixture
def scripted_die() -> Callable[[], int]:
    """Return a fresh predetermined die sequence for each test invocation."""
    rolls = iter((4, 2, 6))
    return lambda: next(rolls)