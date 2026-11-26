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

from aidm.catalogue import (
    CatalogueError, MonsterCatalogue, MonsterTestScenarios, SqlServerReader,
)
from aidm.config import load_config

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
    reader = SqlServerReader(
        lambda: pyodbc.connect(secret, timeout=5, autocommit=False),
        timeout_seconds=10,
    )
    try:
        return 0 if smoke(query=reader) else 1
    except CatalogueError as exc:
        print(f"BLOCKED: read-only PEQUOD unavailable ({type(exc).__name__})")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
