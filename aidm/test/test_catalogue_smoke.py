"""DES-001.7.9: local smoke boundaries (no actual PEQUOD access in CI)."""
from __future__ import annotations

import pytest

from aidm.catalogue_smoke import smoke
from aidm.test.test_catalogue import FakeQuery, monster_row, scenario_row, case_row


def draft_db(*, omit: str | None = None):
    four = ("ORC", "GIANT_CENTIPEDE", "CARRION_CRAWLER", "GIANT_CRAB_SPIDER")
    return FakeQuery(
        monsters=[monster_row(code=c, active=0, status="SourceChecked")
                  for c in four if c != omit],
        scenarios=[scenario_row(ready=0, status="Specified")],
        cases=[case_row(status="Specified")],
    )


def test_readonly_smoke_inspects_four_draft_species_and_never_approves():
    query = draft_db()
    output = []
    assert smoke(query=query, report=output.append) is True
    assert sum("TEST_ONLY SourceChecked" in x for x in output) == 4
    assert sum("normal Approved-only lookup rejects draft" in x for x in output) == 4
    assert any("ORC-T001-A: TEST_ONLY status=Specified" in x for x in output)
    assert all(sql.startswith("SELECT ") for sql, _ in query.calls)
    assert all("UPDATE " not in sql and "INSERT " not in sql for sql, _ in query.calls)


def test_readonly_smoke_missing_species_fails_without_writes():
    query = draft_db(omit="CARRION_CRAWLER")
    output = []
    assert smoke(query=query, report=output.append) is False
    assert any("CARRION_CRAWLER: BLOCKED" in x for x in output)
    assert any("3/4 reviewed species visible" in x for x in output)
    assert all(sql.startswith("SELECT ") for sql, _ in query.calls)
