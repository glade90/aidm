"""DES-001.7.9 — PEQUOD *read-only* local smoke, never called by the server.

Usage (Windows Git Bash, development mode, installed pyodbc and SELECT-only principal):
    read -r -s -p 'Read-only ODBC connection string: ' AIDM_SQL_ODBC_CONNECTION
    printf '\\n'; export AIDM_SQL_ODBC_CONNECTION
    python -m aidm.catalogue_smoke
    unset AIDM_SQL_ODBC_CONNECTION

Secret is never printed or logged. This validates retrieval only. It does not
grant approval, migrate a database, or start a combat encounter.
Change Log: 2026-11-26 DAVOS — local read-only four-species smoke.
"""
from __future__ import annotations

import re

from aidm.catalogue import (
    CatalogueError, MonsterCatalogue, MonsterTestScenarios, SqlServerReader,
    _MONSTER_COLS, _SCENARIO_COLS, _CASE_COLS,
)
from aidm.config import load_config


def _sql_state(exc: Exception) -> str:
    """Return only the five-character ODBC SQLSTATE; NEVER print exception."""
    for arg in getattr(exc, "args", ()):
        if isinstance(arg, str) and re.fullmatch(r"[A-Z0-9]{5}", arg[:5]):
            return arg[:5]
    return "UNKNOWN"


def _failure_class(state: str) -> str:
    if state.startswith(("08", "HYT")):
        return "server/network/timeout"
    if state in ("28000", "42000"):
        return "login or SQL permission"
    if state in ("42S02", "S0002"):
        return "table or schema missing/inaccessible"
    if state in ("42S22", "S0022"):
        return "required column missing"
    if state.startswith("IM"):
        return "ODBC driver or DSN configuration"
    return "SQL/ODBC error"


def diagnose_sql(open_connection, *, report=print) -> bool:
    """Trusted CLI preflight; SELECT only, no raw errors or secret disclosure.

    Isolates connection, wrong database, missing table/column and permissions
    before the public-facing SqlServerReader deliberately masks ODBC errors.
    The explicit configured connection must point at the DnD database.
    """
    connection = cursor = None
    try:
        try:
            connection = open_connection()
        except Exception as exc:
            state = _sql_state(exc)
            report(f"ODBC_CONNECT: BLOCKED [{state}] {_failure_class(state)}")
            return False
        try:
            cursor = connection.cursor()
            cursor.timeout = 10
            cursor.execute("SELECT DB_NAME()")
            row = cursor.fetchone()
            db_name = row[0] if row else None
        except Exception as exc:
            state = _sql_state(exc)
            report(f"DATABASE_CONTEXT: BLOCKED [{state}] {_failure_class(state)}")
            return False
        if not isinstance(db_name, str) or db_name.casefold() != "dnd":
            report("DATABASE_CONTEXT: BLOCKED — connection does not target DnD")
            return False
        report("ODBC_CONNECT: OK; DATABASE_CONTEXT: DnD")
        ready = True
        for name, table, columns in (
            ("RULES_MONSTER", "[Rules].[Monster]", _MONSTER_COLS),
            ("TEST_SCENARIO", "[Test].[MonsterTestScenario]", _SCENARIO_COLS),
            ("TEST_CASE", "[Test].[MonsterTestCase]", _CASE_COLS),
        ):
            # Fixed audited identifiers only; no caller-provided SQL.
            statement = "SELECT TOP (0) " + ", ".join(
                f"[{column}]" for column in columns
            ) + f" FROM {table}"
            try:
                cursor.execute(statement)
                report(f"{name}: SCHEMA_AND_SELECT_OK")
            except Exception as exc:
                state = _sql_state(exc)
                report(f"{name}: BLOCKED [{state}] {_failure_class(state)}")
                ready = False
        return ready
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                pass
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass


_FOUR = ("ORC", "GIANT_CENTIPEDE", "CARRION_CRAWLER", "GIANT_CRAB_SPIDER")


def smoke(*, query, report=print) -> bool:
    """Run against an injected SELECT-only row reader; no database writes."""
    monsters = MonsterCatalogue(query)
    checked = 0
    for code in _FOUR:
        try:
            snapshot = monsters.resolve("MentzerBECMI", code,
                                       source_checked_test_only=True)
        except CatalogueError as exc:
            report(f"{code}: BLOCKED: {type(exc).__name__}")
            continue
        report(
            f"{code}: TEST_ONLY {snapshot.source_status}, Active={int(snapshot.active)}, "
            f"version={snapshot.record_date}, AC={snapshot.armor_class}, "
            f"HD={snapshot.hit_dice_text}, attacks={snapshot.attack_pattern!r}, "
            f"dimensions=({snapshot.d1_feet},{snapshot.d2_feet},{snapshot.z_feet}), "
            f"specials_present={bool(snapshot.special_attacks_features)}, "
            f"encounter_guidance_present={bool(snapshot.special_encounter_features)}, "
            f"image_path_present={bool(snapshot.illustration_path)}, "
            f"source_present={bool(snapshot.source_reference)}"
        )
        checked += 1
        try:
            monsters.resolve("MentzerBECMI", code)
        except CatalogueError:
            report(f"{code}: normal Approved-only lookup rejects draft as required")
        else:
            report(f"{code}: an independent Approved/Active version exists; inspect it separately")
    try:
        scenario = MonsterTestScenarios(query).resolve(
            "ORC-T001-A", include_unready_test_only=True)
        report(
            f"{scenario.code}: TEST_ONLY status={scenario.status}, "
            f"ReadyForExecution={int(scenario.ready_for_execution)}, "
            f"child_count={len(scenario.cases)}; NO case execution"
        )
    except CatalogueError as exc:
        report(f"ORC-T001-A: Test schema/fixture unavailable: {type(exc).__name__}")
    if checked != 4:
        report(f"BLOCKED: {checked}/4 reviewed species visible, no approval changed")
        return False
    report("READ-ONLY smoke: four draft species retrievable; no combat readiness implied")
    return True


def main() -> int:
    # No .env or secret access unless a human runs this explicit developer CLI.
    config = load_config(required_secrets=("AIDM_SQL_ODBC_CONNECTION",))
    if config.mode != "development":
        print("BLOCKED: smoke is only allowed in explicit development mode")
        return 2
    secret = config.get_secret("AIDM_SQL_ODBC_CONNECTION")
    if not secret:
        print("BLOCKED: dedicated read-only ODBC connection secret missing")
        return 2
    try:
        import pyodbc
    except ImportError:
        print("BLOCKED: install local pyodbc before optional SQL smoke")
        return 2
    # Preflight categorises a database access problem without printing raw
    # ODBC diagnostics, server/username, the connection string or credentials.
    open_connection = lambda: pyodbc.connect(secret, timeout=5, autocommit=False)
    if not diagnose_sql(open_connection):
        print("BLOCKED: fix the reported connection/database/schema gate first")
        return 1
    reader = SqlServerReader(open_connection, timeout_seconds=10)
    try:
        return 0 if smoke(query=reader) else 1
    except CatalogueError as exc:
        print(f"BLOCKED: read-only PEQUOD unavailable ({type(exc).__name__})")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
