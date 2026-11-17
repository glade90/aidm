"""Example deterministic tests and opt-in failing-assertion demonstration.

Purpose: Validate repeatable fixture injection without real services or game rules.
Usage: python -m aidm.test_runner [--demonstrate-failure]
Change Log: 2026-11-17 COSTA — AIDM-DES-028.1 example tests.
"""

from collections.abc import Callable
import os


def test_injected_die_sequence(scripted_die: Callable[[], int]) -> None:
    """A controlled dice source makes nondeterministic inputs predictable."""
    assert [scripted_die() for _ in range(3)] == [4, 2, 6]


def test_separate_tests_receive_fresh_die(scripted_die: Callable[[], int]) -> None:
    """Fixture isolation prevents another test consuming our expected rolls."""
    assert scripted_die() == 4


def test_intentional_failure_demonstration() -> None:
    """Only the explicit runner flag enables the deliberately false assertion."""
    assert 2 + 2 == 4
    if os.environ.get("AIDM_TEST_DEMO_FAILURE") == "1":
        assert 2 + 2 == 5, "Intentional AIDM-DES-028.1 failure: JUnit must show this assertion"