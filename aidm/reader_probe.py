"""AIDM-DES-037.1: Windows-token and SQL SELECT-only runtime attestation.

Usage: python -I reader_probe.py --server ".\\SQLEXPRESS" --driver \
       "ODBC Driver 17 for SQL Server" --expected-account "PEQUOD\\AIDM_Reader" \
       --source-sha FULL40SHA --report-file C:\\ProgramData\\AIDM\\Reader0371\\Reports\\proof.json

This file is copied alone into an ACL-restricted shared runtime by the owner.
It has NO dependency on the AIDM source tree or on a personal Windows profile.
Only fixed SELECT statements are executed; no source data is written.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Callable

STORY = "AIDM-DES-037.1"
_OBJECTS = (
    ("Rules.Monster", "[Rules].[Monster]", "MonsterCode"),
    ("Test.MonsterTestScenario", "[Test].[MonsterTestScenario]", "ScenarioCode"),
    ("Test.MonsterTestCase", "[Test].[MonsterTestCase]", "TestCaseCode"),
)
_SQL_ID = (
    "SELECT ORIGINAL_LOGIN(), SUSER_SNAME(), DB_NAME(), "
    "IS_SRVROLEMEMBER(N'sysadmin'), IS_ROLEMEMBER(N'db_owner'), "
    "IS_ROLEMEMBER(N'db_datawriter')"
)
_SQL_OBJECT_PERMS = (
    "SELECT HAS_PERMS_BY_NAME(?, N'OBJECT', N'SELECT'), "
    "HAS_PERMS_BY_NAME(?, N'OBJECT', N'INSERT'), "
    "HAS_PERMS_BY_NAME(?, N'OBJECT', N'UPDATE'), "
    "HAS_PERMS_BY_NAME(?, N'OBJECT', N'DELETE'), "
    "HAS_PERMS_BY_NAME(?, N'OBJECT', N'ALTER'), "
    "HAS_PERMS_BY_NAME(?, N'OBJECT', N'CONTROL')"
)
_SQL_DATABASE_PERMS = (
    "SELECT HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CONTROL'), "
    "HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CREATE TABLE'), "
    "HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'ALTER ANY SCHEMA')"
)
_DRIVERS = frozenset({"ODBC Driver 17 for SQL Server", "ODBC Driver 18 for SQL Server"})
_SHA = re.compile(r"[0-9a-f]{40}\Z")
_SID = re.compile(r"S-1-(?:[0-9]+-)+[0-9]+\Z")
_SERVER = re.compile(r"[A-Za-z0-9_.()\\-]{1,128}\Z")


class ProbeBlocked(Exception):
    """Coded, non-secret failure; no exception or connection string is logged."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def _token_whoami() -> tuple[str, str]:
    """Read the OS execution token, NOT USERNAME or USERDOMAIN environment."""
    if sys.platform != "win32":
        raise ProbeBlocked("WINDOWS_TOKEN_REQUIRED")
    try:
        result = subprocess.run(
            ["whoami.exe", "/user", "/fo", "csv", "/nh"],
            check=True, capture_output=True, text=True, timeout=6,
            encoding="utf-8", errors="replace",
        )
        values = next(csv.reader(io.StringIO(result.stdout)), [])
        if len(values) != 2 or not _SID.fullmatch(values[1]):
            raise ProbeBlocked("WINDOWS_TOKEN_UNAVAILABLE")
        return values[0], values[1]
    except ProbeBlocked:
        raise
    except Exception:
        raise ProbeBlocked("WINDOWS_TOKEN_UNAVAILABLE") from None


def _validate_inputs(expected: str, server: str, driver: str,
                     machine: str, sha: str) -> None:
    # Do not let a caller bypass this check by replacing the target account.
    if (type(machine) is not str or not machine
            or expected.casefold() != (machine + "\\AIDM_Reader").casefold()):
        raise ProbeBlocked("INVALID_EXPECTED_READER_ACCOUNT")
    if type(sha) is not str or not _SHA.fullmatch(sha):
        raise ProbeBlocked("INVALID_SOURCE_SHA")
    if driver not in _DRIVERS:
        raise ProbeBlocked("UNSUPPORTED_ODBC_DRIVER")
    if type(server) is not str or not _SERVER.fullmatch(server):
        raise ProbeBlocked("INVALID_LOCAL_SQL_SERVER")
    host = server.split("\\", 1)[0]
    if host.casefold() not in (machine.casefold(), ".", "(local)", "localhost"):
        raise ProbeBlocked("NONLOCAL_SQL_SERVER")


def _connect_integrated(server: str, driver: str) -> Any:
    """Explicit integrated Windows auth, local SQL only; never SQL passwords."""
    try:
        import pyodbc  # type: ignore[import-not-found]
    except ImportError:
        raise ProbeBlocked("PYODBC_NOT_INSTALLED") from None
    if driver not in pyodbc.drivers():
        raise ProbeBlocked("ODBC_DRIVER_NOT_INSTALLED")
    # No UID/PWD, no mixed-mode auth, and no credential material in args.
    # TrustServerCertificate is limited to the validated SAME-MACHINE server.
    conn_str = (
        f"DRIVER={{{driver}}};SERVER={server};DATABASE=DnD;"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;"
        "APP=AIDM_Reader_0371"
    )
    return pyodbc.connect(conn_str, timeout=5, autocommit=False)


def _zero(value: object) -> bool:
    return type(value) in (int, bool) and value == 0


def _one(value: object) -> bool:
    return type(value) in (int, bool) and value == 1


def _check_permissions(connection: Any, expected: str) -> dict[str, Any]:
    cursor = None
    try:
        # As in SqlServerReader: pyodbc timeout belongs to Connection.
        connection.timeout = 10
        cursor = connection.cursor()
        cursor.execute(_SQL_ID)
        row = cursor.fetchone()
        if row is None or len(row) != 6:
            raise ProbeBlocked("SQL_IDENTITY_UNAVAILABLE")
        original, login, database, sysadmin, owner, writer = row
        if (not isinstance(original, str) or not isinstance(login, str)
                or original.casefold() != expected.casefold()
                or login.casefold() != expected.casefold()):
            raise ProbeBlocked("SQL_LOGIN_IDENTITY_MISMATCH")
        if database != "DnD":
            raise ProbeBlocked("WRONG_DATABASE_CONTEXT")
        if not all(_zero(v) for v in (sysadmin, owner, writer)):
            raise ProbeBlocked("PRIVILEGED_SQL_ROLE")

        cursor.execute(_SQL_DATABASE_PERMS)
        db_perms = cursor.fetchone()
        if db_perms is None or len(db_perms) != 3 or not all(_zero(v) for v in db_perms):
            raise ProbeBlocked("DATABASE_PRIVILEGE_NOT_READONLY")

        inspected: list[dict[str, Any]] = []
        for name, sql_table, primary_code in _OBJECTS:
            cursor.execute(_SQL_OBJECT_PERMS, *(name for _ in range(6)))
            rights = cursor.fetchone()
            if (rights is None or len(rights) != 6 or not _one(rights[0])
                    or not all(_zero(permission) for permission in rights[1:])):
                raise ProbeBlocked("OBJECT_PRIVILEGE_NOT_READONLY")
            # TOP 0 exercises object/column SELECT and schema access without
            # reading or emitting source records; UAT-01/02/03 run separately.
            cursor.execute(
                f"SELECT TOP (0) [{primary_code}] FROM {sql_table}"
            )
            cursor.fetchall()
            inspected.append({"object": name, "select": True, "writes_and_ddl": False,
                              "select_query_executed": True})
        return {
            "windows_integrated_sql_login": True,
            "database": "DnD",
            "server_sysadmin": False,
            "database_owner": False,
            "database_writer": False,
            "database_control_create_alter": False,
            "objects": inspected,
        }
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                pass


def inspect_reader(expected: str, server: str, driver: str, machine: str,
                   source_sha: str, *,
                   identity_fn: Callable[[], tuple[str, str]] | None = None,
                   connector: Callable[[str, str], Any] | None = None,
                   ) -> dict[str, Any]:
    """Fail closed: check Windows token BEFORE opening ODBC, then effective SQL.

    Inject identity_fn and connector in offline tests; no SQL Server or Windows
    identity is required for ordinary Python/GitHub CI.
    """
    result: dict[str, Any] = {
        "story": STORY, "status": "BLOCKED",
        "source_sha": source_sha,
        "utc": datetime.now(timezone.utc).isoformat(),
        "reason": "UNVERIFIED",
    }
    connection = None
    try:
        _validate_inputs(expected, server, driver, machine, source_sha)
        account, sid = (identity_fn or _token_whoami)()
        if not isinstance(account, str) or account.casefold() != expected.casefold():
            raise ProbeBlocked("WINDOWS_PROCESS_IDENTITY_MISMATCH")
        if not isinstance(sid, str) or not _SID.fullmatch(sid):
            raise ProbeBlocked("WINDOWS_TOKEN_UNAVAILABLE")
        result["process_account"] = account
        result["process_sid"] = sid
        connection = (connector or _connect_integrated)(server, driver)
        verified = _check_permissions(connection, expected)
        result.update(verified)
        result["status"] = "PASS"
        result["reason"] = "EFFECTIVE_WINDOWS_AND_SQL_READONLY_VERIFIED"
    except ProbeBlocked as blocked:
        result["reason"] = blocked.reason
    except Exception:
        # Never include pyodbc errors, DNS, paths, tokens or credentials.
        result["reason"] = "READER_RUNTIME_OR_SQL_FAILED"
    finally:
        if connection is not None:
            try:
                connection.rollback()
            except Exception:
                pass
            try:
                connection.close()
            except Exception:
                pass
    return result


def _load_reviewed_catalogue(path: Path) -> Any:
    """Load the exact source-controlled catalogue.py copied by the admin.

    Python -I deliberately omits the script directory from sys.path. An
    absolute reviewed-file import avoids a writable personal user site.
    """
    if not path.is_file() or path.name != "catalogue.py":
        raise ProbeBlocked("REVIEWED_CATALOGUE_FILE_MISSING")
    spec = importlib.util.spec_from_file_location("aidm_reader_reviewed_catalogue", path)
    if spec is None or spec.loader is None:
        raise ProbeBlocked("REVIEWED_CATALOGUE_FILE_MISSING")
    module = importlib.util.module_from_spec(spec)
    # Dataclass type resolution requires the module in sys.modules.
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        raise ProbeBlocked("REVIEWED_CATALOGUE_IMPORT_FAILED") from None
    return module


def _check_catalogue_source(catalogue: Any, query: Callable[..., Any]) -> dict[str, Any]:
    """Developer read-only smoke of three parent UAT areas, NOT BON acceptance.

    The real UAT owner still checks source-field fidelity and records each
    case separately in DnD_Test under their administrative identity.
    """
    species = ("ORC", "GIANT_CENTIPEDE", "CARRION_CRAWLER", "GIANT_CRAB_SPIDER")
    repo = catalogue.MonsterCatalogue(query)
    for code in species:
        try:
            snap = repo.resolve("MentzerBECMI", code, source_checked_test_only=True)
            if (snap.active or snap.source_status != "SourceChecked"
                    or not snap.source_reference or not snap.hit_dice_text
                    or snap.armor_class is None or not snap.attack_pattern
                    or not snap.damage_pattern or not snap.special_attacks_features
                    or not snap.special_encounter_features
                    or not all(v is not None for v in
                               (snap.d1_feet, snap.d2_feet, snap.z_feet))):
                raise ProbeBlocked("DRAFT_SPECIES_INCOMPLETE_OR_UNEXPECTED")
            try:
                approved = repo.resolve("MentzerBECMI", code)
            except catalogue.CatalogueUnavailable:
                raise ProbeBlocked("APPROVAL_GATE_QUERY_UNAVAILABLE") from None
            except catalogue.CatalogueError as error:
                # Only a missing/ambiguous approved row is the expected gate.
                if str(error) != "Monster version missing or ambiguous":
                    raise ProbeBlocked("APPROVAL_GATE_QUERY_UNEXPECTED") from None
            else:
                # A genuinely approved version needs owner review. Never infer
                # that a source-checked draft was promoted, or grant readiness.
                if approved.active and approved.source_status == "Approved":
                    raise ProbeBlocked("APPROVED_VERSION_REQUIRES_OWNER_REVIEW")
                raise ProbeBlocked("APPROVAL_GATE_UNEXPECTED")
        except ProbeBlocked:
            raise
        except Exception:
            raise ProbeBlocked("DRAFT_SPECIES_RETRIEVAL_BLOCKED") from None

    scenarios = catalogue.MonsterTestScenarios(query)
    for code in ("ORC-T001-A", "ORC-T001-B"):
        try:
            fixture = scenarios.resolve(code, include_unready_test_only=True)
            if (fixture.ready or fixture.ready_for_execution
                    or fixture.status != "Specified" or not fixture.cases
                    or any(case.executable for case in fixture.cases)):
                raise ProbeBlocked("TEST_CASE_GATE_UNEXPECTED")
        except ProbeBlocked:
            raise
        except Exception:
            raise ProbeBlocked("NORMALIZED_SCENARIO_RETRIEVAL_BLOCKED") from None
    return {
        "status": "DEVELOPER_SMOKE_PASS_NOT_BON_UAT",
        "reviewed_draft_species": len(species),
        "draft_approval_gates": len(species),
        "normalized_scenarios_inspected": 2,
        "writes_performed": False,
        "approved_as_playable": False,
    }


def _run_source_smoke(server: str, driver: str) -> dict[str, Any]:
    """Use fixed production provider code from same locked runtime directory."""
    source_path = Path(__file__).with_name("catalogue.py")
    catalogue = _load_reviewed_catalogue(source_path)
    sql_reader = catalogue.SqlServerReader(
        lambda: _connect_integrated(server, driver), timeout_seconds=10,
    )
    result = _check_catalogue_source(catalogue, sql_reader)
    result["catalogue_sha256"] = hashlib.sha256(source_path.read_bytes()).hexdigest()
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=STORY + " local reader proof")
    parser.add_argument("--server", required=True)
    parser.add_argument("--driver", required=True)
    parser.add_argument("--expected-account", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--report-file", required=True)
    parser.add_argument("--with-source-smoke", action="store_true")
    args = parser.parse_args(argv)
    machine = os.environ.get("COMPUTERNAME", "")
    result = inspect_reader(
        args.expected_account, args.server, args.driver, machine,
        args.source_sha,
    )
    if args.with_source_smoke and result["status"] == "PASS":
        try:
            result["provider_smoke"] = _run_source_smoke(args.server, args.driver)
        except ProbeBlocked as blocked:
            result["status"] = "BLOCKED"
            result["reason"] = blocked.reason
        except Exception:
            result["status"] = "BLOCKED"
            result["reason"] = "SOURCE_SMOKE_FAILED"
    result["script_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    report_path = Path(args.report_file)
    if not report_path.is_absolute():
        print("BLOCKED: ABSOLUTE_REPORT_PATH_REQUIRED")
        return 3
    # Fresh unique owner-chosen filename: no silently replacing old evidence.
    try:
        with report_path.open("x", encoding="utf-8") as out:
            json.dump(result, out, indent=2, sort_keys=True)
            out.write("\n")
    except (OSError, ValueError):
        print("BLOCKED: REPORT_WRITE_DENIED")
        return 3
    print(result["status"] + ": " + result["reason"])
    return 0 if result["status"] == "PASS" else 3


if __name__ == "__main__":
    sys.exit(main())
