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


class FakeODBCError(Exception):
    pass


class ProbeCursor:
    def __init__(self, *, database="DnD", failure_table=None, failure_code="42S02"):
        self.database = database
        self.failure_table = failure_table
        self.failure_code = failure_code
        self.queries = []
        self.closed = False
        self.timeout = None

    def execute(self, sql):
        assert sql.startswith("SELECT ")
        self.queries.append(sql)
        if self.failure_table and self.failure_table in sql:
            raise FakeODBCError(self.failure_code, "PRIVATE_ODBC_SERVER_PASSWORD")
        return self

    def fetchone(self):
        return (self.database,)

    def close(self):
        self.closed = True


class ProbeConnection:
    def __init__(self, cursor):
        self.child = cursor
        self.closed = False

    def cursor(self):
        return self.child

    def close(self):
        self.closed = True


def test_odbc_preflight_success_only_three_full_schema_selects():
    from aidm.catalogue_smoke import diagnose_sql
    cursor = ProbeCursor()
    connection = ProbeConnection(cursor)
    report = []
    assert diagnose_sql(lambda: connection, report=report.append) is True
    assert report == [
        "ODBC_CONNECT: OK; DATABASE_CONTEXT: DnD",
        "RULES_MONSTER: SCHEMA_AND_SELECT_OK",
        "TEST_SCENARIO: SCHEMA_AND_SELECT_OK",
        "TEST_CASE: SCHEMA_AND_SELECT_OK",
    ]
    assert len(cursor.queries) == 4
    assert "SpecialEncounterFeatures" in cursor.queries[1]
    assert "TestCaseCode" in cursor.queries[-1]
    assert cursor.closed and connection.closed


def test_odbc_preflight_wrong_database_is_blocked_before_table_probes():
    from aidm.catalogue_smoke import diagnose_sql
    cursor = ProbeCursor(database="master")
    connection = ProbeConnection(cursor)
    reports = []
    assert diagnose_sql(lambda: connection, report=reports.append) is False
    assert reports == ["DATABASE_CONTEXT: BLOCKED — connection does not target DnD"]
    assert cursor.queries == ["SELECT DB_NAME()"]
    assert cursor.closed and connection.closed


@pytest.mark.parametrize("code,expected", [
    ("42S02", "table or schema missing/inaccessible"),
    ("42S22", "required column missing"),
    ("42000", "login or SQL permission"),
])
def test_odbc_preflight_schema_error_reports_only_safe_sqlstate(code, expected):
    from aidm.catalogue_smoke import diagnose_sql
    cursor = ProbeCursor(failure_table="[Rules].[Monster]", failure_code=code)
    connection = ProbeConnection(cursor)
    reports = []
    assert diagnose_sql(lambda: connection, report=reports.append) is False
    assert any(f"RULES_MONSTER: BLOCKED [{code}] {expected}" == line for line in reports)
    assert any("TEST_SCENARIO: SCHEMA_AND_SELECT_OK" == line for line in reports)
    assert cursor.closed and connection.closed
    assert "PRIVATE_ODBC" not in repr(reports)


@pytest.mark.parametrize("code", ["08001", "28000", "IM002", "HYT00", "HY000"])
def test_odbc_preflight_connect_error_never_prints_driver_exceptions(code):
    from aidm.catalogue_smoke import diagnose_sql
    reports = []
    def fail():
        raise FakeODBCError(code, "SERVER=PRIVATE;PWD=PRIVATE_KEY")
    assert diagnose_sql(fail, report=reports.append) is False
    assert len(reports) == 1 and f"[{code}]" in reports[0]
    assert "PRIVATE" not in reports[0]
