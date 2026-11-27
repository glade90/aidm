"""AIDM-DES-037.1 offline identity/permissions evidence tests.

No Windows account, SQL Server, pyodbc or scheduler is contacted by these tests.
"""
from __future__ import annotations

import json
from pathlib import Path
import pytest

from aidm import reader_probe as probe


SHA = "a" * 40
ACCOUNT = "PEQUOD\\AIDM_Reader"
SID = "S-1-5-21-100-200-300-1001"


class FakeCursor:
    def __init__(self, *, original=ACCOUNT, login=ACCOUNT, database="DnD",
                 sysadmin=0, owner=0, writer=0,
                 object_rights=(1, 0, 0, 0, 0, 0),
                 database_rights=(0, 0, 0), fail_query=None):
        self.original, self.login, self.database = original, login, database
        self.sysadmin, self.owner, self.writer = sysadmin, owner, writer
        self.object_rights, self.database_rights = object_rights, database_rights
        self.fail_query = fail_query
        self.executed = []
        self.current = ()
        self.closed = False
        self.selects = 0

    def execute(self, sql, *params):
        self.executed.append((sql, params))
        if self.fail_query and self.fail_query in sql:
            raise RuntimeError("Server=SECRET;PWD=should-not-leak")
        assert sql.startswith("SELECT "), "Probe must not submit SQL mutations"
        if sql == probe._SQL_ID:
            self.current = (self.original, self.login, self.database,
                            self.sysadmin, self.owner, self.writer)
        elif sql == probe._SQL_DATABASE_PERMS:
            self.current = self.database_rights
        elif sql == probe._SQL_OBJECT_PERMS:
            assert len(params) == 6 and len(set(params)) == 1
            assert params[0] in {row[0] for row in probe._OBJECTS}
            self.current = self.object_rights
        elif sql.startswith("SELECT TOP (0) ["):
            assert not params
            assert any(table in sql for _, table, _ in probe._OBJECTS)
            self.current = ()
            self.selects += 1
        else:
            raise AssertionError("Unreviewed SQL submitted by the proof")
        return self

    def fetchone(self):
        return self.current

    def fetchall(self):
        assert self.current == ()
        return []

    def close(self):
        self.closed = True


class FakeConnection:
    def __init__(self, cursor=None):
        self.child = cursor or FakeCursor()
        self.closed = self.rollback_called = False
        self.timeout = None

    def cursor(self):
        assert self.timeout == 10
        return self.child

    def rollback(self):
        self.rollback_called = True

    def close(self):
        self.closed = True


def run(*, cursor=None, account=ACCOUNT, sid=SID, machine="PEQUOD",
        expected=ACCOUNT, server=r".\SQLEXPRESS", driver="ODBC Driver 17 for SQL Server",
        source=SHA):
    connection = FakeConnection(cursor)
    factory_calls = []

    def factory(s, d):
        factory_calls.append((s, d))
        return connection

    outcome = probe.inspect_reader(expected, server, driver, machine, source,
                                   identity_fn=lambda: (account, sid),
                                   connector=factory)
    return outcome, connection, factory_calls


def test_success_is_real_token_and_sql_permissions_not_an_environment_variable():
    outcome, connection, factory_calls = run()
    assert outcome["status"] == "PASS"
    assert outcome["reason"] == "EFFECTIVE_WINDOWS_AND_SQL_READONLY_VERIFIED"
    assert outcome["source_sha"] == SHA
    assert outcome["process_account"] == ACCOUNT
    assert outcome["process_sid"] == SID
    assert len(outcome["objects"]) == 3
    assert all(row["select"] and not row["writes_and_ddl"] for row in outcome["objects"])
    assert connection.child.selects == 3
    assert connection.closed and connection.rollback_called and connection.child.closed
    assert factory_calls == [(r".\SQLEXPRESS", "ODBC Driver 17 for SQL Server")]
    assert all(sql.startswith("SELECT ") for sql, _ in connection.child.executed)


@pytest.mark.parametrize("bad_identity,sid", [
    ("PEQUOD\\Owner", SID),
    ("PEQUOD\\Administrator", SID),
    (ACCOUNT, ""),
    (ACCOUNT, "unverified"),
])
def test_wrong_os_token_never_opens_a_connection(bad_identity, sid):
    out, conn, factory = run(account=bad_identity, sid=sid)
    assert out["status"] == "BLOCKED"
    assert out["reason"] in ("WINDOWS_PROCESS_IDENTITY_MISMATCH", "WINDOWS_TOKEN_UNAVAILABLE")
    assert factory == []
    assert not conn.closed
    assert "SECRET" not in json.dumps(out)


@pytest.mark.parametrize("kwargs,reason", [
    ({"expected": "PEQUOD\\Administrator"}, "INVALID_EXPECTED_READER_ACCOUNT"),
    ({"machine": "OTHER"}, "INVALID_EXPECTED_READER_ACCOUNT"),
    ({"server": "EXTERNAL-SERVER"}, "NONLOCAL_SQL_SERVER"),
    ({"server": r".\SQLEXPRESS;Trusted_Connection=no"}, "INVALID_LOCAL_SQL_SERVER"),
    ({"driver": "SQL Server Native Client"}, "UNSUPPORTED_ODBC_DRIVER"),
    ({"source": "short"}, "INVALID_SOURCE_SHA"),
])
def test_untrusted_config_is_rejected_before_connection(kwargs, reason):
    out, conn, factory = run(**kwargs)
    assert out["reason"] == reason and out["status"] == "BLOCKED"
    assert factory == []


@pytest.mark.parametrize("cursor,reason", [
    (FakeCursor(original="PEQUOD\\Owner"), "SQL_LOGIN_IDENTITY_MISMATCH"),
    (FakeCursor(login="PEQUOD\\Owner"), "SQL_LOGIN_IDENTITY_MISMATCH"),
    (FakeCursor(database="master"), "WRONG_DATABASE_CONTEXT"),
    (FakeCursor(sysadmin=1), "PRIVILEGED_SQL_ROLE"),
    (FakeCursor(owner=1), "PRIVILEGED_SQL_ROLE"),
    (FakeCursor(writer=1), "PRIVILEGED_SQL_ROLE"),
    (FakeCursor(sysadmin=None), "PRIVILEGED_SQL_ROLE"),
    (FakeCursor(object_rights=(0, 0, 0, 0, 0, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(1, 1, 0, 0, 0, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(1, 0, 1, 0, 0, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(1, 0, 0, 1, 0, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(1, 0, 0, 0, 1, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(1, 0, 0, 0, 0, 1)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(object_rights=(None, 0, 0, 0, 0, 0)), "OBJECT_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(database_rights=(1, 0, 0)), "DATABASE_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(database_rights=(0, 1, 0)), "DATABASE_PRIVILEGE_NOT_READONLY"),
    (FakeCursor(database_rights=(0, 0, 1)), "DATABASE_PRIVILEGE_NOT_READONLY"),
])
def test_sql_identity_and_all_write_ddl_permissions_fail_closed(cursor, reason):
    out, conn, factory = run(cursor=cursor)
    assert out["status"] == "BLOCKED"
    assert out["reason"] == reason
    assert len(factory) == 1
    assert conn.closed and conn.rollback_called and cursor.closed
    assert "password" not in json.dumps(out).lower()


def test_driver_exception_and_unavailable_identity_are_redacted():
    out = probe.inspect_reader(
        ACCOUNT, "PEQUOD", "ODBC Driver 18 for SQL Server", "PEQUOD", SHA,
        identity_fn=lambda: (ACCOUNT, SID),
        connector=lambda _s, _d: (_ for _ in ()).throw(
            RuntimeError("Server=SECRET;UID=SECRET;PWD=SECRET")
        ),
    )
    assert out["status"] == "BLOCKED"
    assert out["reason"] == "READER_RUNTIME_OR_SQL_FAILED"
    assert "SECRET" not in json.dumps(out)


def test_read_only_query_driver_failure_still_closes_resources():
    out, conn, factory = run(cursor=FakeCursor(fail_query="HAS_PERMS_BY_NAME"))
    assert out["status"] == "BLOCKED" and len(factory) == 1
    assert out["reason"] == "READER_RUNTIME_OR_SQL_FAILED"
    assert "SECRET" not in json.dumps(out)
    assert conn.closed and conn.rollback_called and conn.child.closed


def test_no_reader_environment_or_pyodbc_dependency_on_import(monkeypatch):
    monkeypatch.setenv("USERNAME", "AIDM_Reader")
    out, _conn, factory = run(account="PEQUOD\\Administrator")
    assert out["reason"] == "WINDOWS_PROCESS_IDENTITY_MISMATCH"
    assert factory == []


def test_cli_report_is_fresh_redacted_and_has_script_hash(tmp_path, monkeypatch):
    monkeypatch.setenv("COMPUTERNAME", "PEQUOD")
    monkeypatch.setattr(probe, "_token_whoami", lambda: (ACCOUNT, SID))
    monkeypatch.setattr(probe, "_connect_integrated", lambda _s, _d: FakeConnection())
    report = tmp_path / "proof.json"
    args = [
        "--server", "PEQUOD", "--driver", "ODBC Driver 17 for SQL Server",
        "--expected-account", ACCOUNT, "--source-sha", SHA,
        "--report-file", str(report),
    ]
    assert probe.main(args) == 0
    evidence = json.loads(report.read_text(encoding="utf-8"))
    assert evidence["status"] == "PASS"
    assert evidence["source_sha"] == SHA
    assert len(evidence["script_sha256"]) == 64
    assert "password" not in report.read_text(encoding="utf-8").lower()
    # Never replace an earlier attestation, even if a second run succeeds.
    assert probe.main(args) == 3
    assert json.loads(report.read_text(encoding="utf-8")) == evidence


def test_cli_error_does_not_echo_conn_string_and_reports_block(tmp_path, monkeypatch):
    monkeypatch.setenv("COMPUTERNAME", "PEQUOD")
    monkeypatch.setattr(probe, "_token_whoami", lambda: ("PEQUOD\\Admin", SID))
    monkeypatch.setattr(probe, "_connect_integrated",
                        lambda *_: (_ for _ in ()).throw(AssertionError("NO ODBC")))
    report = tmp_path / "denied.json"
    result = probe.main([
        "--server", "PEQUOD", "--driver", "ODBC Driver 17 for SQL Server",
        "--expected-account", ACCOUNT, "--source-sha", SHA,
        "--report-file", str(report),
    ])
    assert result == 3
    j = json.loads(report.read_text())
    assert j["status"] == "BLOCKED"
    assert j["reason"] == "WINDOWS_PROCESS_IDENTITY_MISMATCH"
    assert "NO ODBC" not in json.dumps(j)
