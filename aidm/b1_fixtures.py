"""AIDM-DES-001.7.12.1: source-verified candidate allocation / SQL test seed builder.

Purpose: keep five separate printed B1 stock-option identities and their
source HP lists outside the species catalogue. Generate safe, INSERT-ONLY
Test.MonsterTestScenario / normalized Test.MonsterTestCase SPECIFICATIONS.

Usage: python -m aidm.b1_fixtures --check
       python -m aidm.b1_fixtures --write  # regenerates REVIEW-ONLY seed SQL

Change Log: 2026-11-25 DAVOS — first five source candidates, NOT playable.
This module is development tooling only: no SQL, UI, Combat or network I/O.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any, Mapping

_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = _ROOT / "Database" / "fixtures" / "B1_First_Five_Source_Candidates.json"
SEED_SQL = _ROOT / "Database" / "tables" / "inserts" / "MonsterTestScenario_B1_First_Five_Candidates.sql"
_SOURCE_IDS = frozenset(("S12", "S15", "S16", "S20", "S25"))
_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,79}\Z")
_NAME_RE = re.compile(r"[A-Z][A-Z_]{1,79}\Z")


class B1CandidateError(ValueError):
    """Fail-closed source review or manifest structural error."""


def _positive(value: object, label: str, *, maximum: int = 10000) -> int:
    if type(value) is not int or not 1 <= value <= maximum:
        raise B1CandidateError(f"Invalid {label}")
    return value


def _string(value: object, label: str, *, max_length: int = 500) -> str:
    if not isinstance(value, str) or not value or len(value) > max_length:
        raise B1CandidateError(f"Invalid {label}")
    if any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise B1CandidateError(f"Invalid {label}")
    return value


@dataclass(frozen=True, slots=True)
class B1Candidate:
    """Optional B1 stocking ENTRY, not a species or an automatically spawned actor."""
    source_id: str
    fixture_id: str
    scenario_code: str
    species: str
    label: str
    count_min: int
    count_max: int
    source_hp: tuple[int, ...]
    armor_class: int
    hit_dice: str
    attacks: int
    damage: str
    movement_turn_feet: int
    movement_round_feet: int
    save_as: str
    morale: int
    source_page: int
    mechanics_questions: tuple[str, ...]

    @property
    def source_ref(self) -> str:
        return f"TSR 9023 B1 brown-cover printed p.{self.source_page} / option {self.source_id}"

    def roster(self) -> list[dict[str, Any]]:
        """Explicit MAX count as a *test* choice, never default actual B1 stocking."""
        return [
            {
                "actor_id": f"b1-{self.source_id.lower()}-{self.species.lower()}-{i:02d}",
                "species": self.species,
                "role": "SOURCE_UNDESIGNATED",
                "hp_start": hp,
                "armor_class": self.armor_class,
                "species_record_date": None,  # PEQUOD version must be approved/pinned
                "equipment": None,  # no invented weapon selection
                "source_hp_ordinal": i,
            }
            for i, hp in enumerate(self.source_hp, 1)
        ]


def _entry(row: Mapping[str, Any]) -> B1Candidate:
    if not isinstance(row, Mapping):
        raise B1CandidateError("Invalid B1 source entry")
    source_id = _string(row.get("source_id"), "source_id", max_length=3)
    if source_id not in _SOURCE_IDS:
        raise B1CandidateError("Unexpected B1 source option")
    n = int(source_id[1:])
    fixture = _string(row.get("fixture_id"), "fixture_id")
    scenario = _string(row.get("scenario_code"), "scenario_code")
    if fixture != f"b1.stock.{n:02d}" or scenario != f"B1-{source_id}":
        raise B1CandidateError("Inconsistent B1 source IDs")
    species = _string(row.get("species"), "species", max_length=80)
    if _NAME_RE.fullmatch(species) is None:
        raise B1CandidateError("Invalid species code")
    lower = _positive(row.get("count_min"), "count_min", maximum=100)
    upper = _positive(row.get("count_max"), "count_max", maximum=100)
    hp = row.get("source_hp")
    if not isinstance(hp, list) or not hp or len(hp) != upper or lower > upper:
        raise B1CandidateError("B1 HP list/count mismatch")
    hp_values = tuple(_positive(h, "source_hp") for h in hp)
    ac = row.get("armor_class")
    if type(ac) is not int or not -20 <= ac <= 20:
        raise B1CandidateError("Invalid B1 armor class")
    morale = row.get("morale")
    if type(morale) is not int or not 2 <= morale <= 12:
        raise B1CandidateError("Invalid B1 morale")
    queries = row.get("mechanics_questions")
    if not isinstance(queries, list) or not queries or any(
        not isinstance(q, str) or not q.strip() or len(q) > 500 for q in queries
    ):
        raise B1CandidateError("Missing explicit mechanics review blockers")
    return B1Candidate(
        source_id, fixture, scenario, species,
        _string(row.get("label"), "label", max_length=120),
        lower, upper, hp_values, ac,
        _string(row.get("hit_dice"), "hit_dice", max_length=30),
        _positive(row.get("attacks"), "attacks", maximum=20),
        _string(row.get("damage"), "damage", max_length=120),
        _positive(row.get("movement_turn_feet"), "turn movement", maximum=1000),
        _positive(row.get("movement_round_feet"), "round movement", maximum=1000),
        _string(row.get("save_as"), "save_as", max_length=30),
        morale, _positive(row.get("source_page"), "source_page", maximum=100),
        tuple(_string(q, "mechanics_question") for q in queries),
    )


def read_candidates(path: Path = MANIFEST) -> tuple[B1Candidate, ...]:
    """Parse review-only source manifest. Never interpret it as runtime authority."""
    try:
        raw = path.read_text(encoding="utf-8")
        if len(raw) > 100_000:
            raise B1CandidateError("Candidate manifest too large")
        obj = json.loads(raw)
    except (OSError, ValueError) as exc:
        raise B1CandidateError("Missing or invalid B1 source manifest") from None
    if not isinstance(obj, dict):
        raise B1CandidateError("Invalid manifest document")
    if (obj.get("schema") != "aidm.b1.first_five.candidates.v1"
            or obj.get("allocation_status") != "PROPOSED_BY_DAVOS_PENDING_BON"
            or obj.get("ready_for_execution") is not False
            or obj.get("record_date_policy") != "UNRESOLVED_UNTIL_APPROVED_PEQUOD_RULES_MONSTER_VERSION"):
        raise B1CandidateError("Source review or approval contract changed unexpectedly")
    entries = obj.get("entries")
    if not isinstance(entries, list) or len(entries) != 5:
        raise B1CandidateError("Exactly five independently numbered B1 options required")
    result = tuple(_entry(x) for x in entries)
    ids = [x.source_id for x in result]
    if len(set(ids)) != 5 or set(ids) != _SOURCE_IDS:
        raise B1CandidateError("Missing, duplicate or substituted B1 source option")
    if len({x.fixture_id for x in result}) != 5:
        raise B1CandidateError("Duplicate fixture ID")
    if len({x.scenario_code for x in result}) != 5:
        raise B1CandidateError("Duplicate scenario code")
    if len({tuple(x.source_hp) for x in result}) != 5:
        raise B1CandidateError("Duplicate source HP profile is suspicious")
    return result


def _sql(value: str) -> str:
    """SQL literal for reviewed seed text only, NEVER a live query builder."""
    return "N'" + _string(value, "SQL seed literal", max_length=131072).replace("'", "''") + "'"


def _json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"))


def render_seed_sql(entries: tuple[B1Candidate, ...]) -> str:
    """Render deterministic INSERT-ONLY draft fixtures with BLOCKED case oracles."""
    if len(entries) != 5 or {e.source_id for e in entries} != _SOURCE_IDS:
        raise B1CandidateError("Unexpected first-five allocation")
    lines = [
        "/* AIDM-DES-001.7.12.1 — FIRST FIVE B1 SOURCE CANDIDATES.",
        "   Generated from Database/fixtures/B1_First_Five_Source_Candidates.json.",
        "   BON SOURCE/EDITION/MECHANICS APPROVAL PENDING; DO NOT PROMOTE TO READY.",
        "   TEST ONLY — no schema migration, no fake passed UAT and no autostocking.",
        "   Usage: DBA review BEFORE manually executing in private DnD database.",
        "*/",
        "USE [DnD];",
        "GO",
        "IF OBJECT_ID(N'Test.MonsterTestScenario', N'U') IS NULL",
        "    THROW 57820, 'Test.MonsterTestScenario not deployed; abort', 1;",
        "IF OBJECT_ID(N'Test.MonsterTestCase', N'U') IS NULL",
        "    THROW 57821, 'Test.MonsterTestCase not deployed; abort', 1;",
        "SET XACT_ABORT ON;",
        "GO",
        "BEGIN TRY",
        "    BEGIN TRAN;",
    ]
    for e in entries:
        scenario = e.scenario_code
        count = e.count_max
        party = [
            {"actor_id": "alho", "source": "owner-canonical-3v3-fixture-v1", "hp_start": 8},
            {"actor_id": "evro", "source": "owner-canonical-3v3-fixture-v1", "hp_start": 8},
            {"actor_id": "sho-rembo", "source": "owner-canonical-3v3-fixture-v1", "hp_start": 9},
        ]
        count_choice = {
            "b1_count_min": e.count_min,
            "b1_count_max": count,
            "test_selection": count,
            "selection_policy": "PROVISIONAL_MAXIMUM_TEST_COUNT_NOT_MANDATORY_MODULE_STOCKING",
        }
        scene = {
            "b1_source_id": e.source_id,
            "module_page": e.source_page,
            "stocking_optional": True,
            "actual_room_assignment": None,
            "initial_hostility": "UNRESOLVED",
            "surprise": "UNRESOLVED",
            "geometry": "UNRESOLVED",
            "equipment": "UNRESOLVED",
            "bon_source_approved": False,
            "verified_mechanics": False,
            "species_record_date": None,
        }
        # Do not duplicate private monster special mechanics or invent a scene.
        fields = [
            _sql(scenario), _sql(f"B1 {e.source_id} optional stock — {e.label}"),
            _sql("MentzerBECMI"), _sql(e.species), "1", _sql("Specified"), "0",
            _sql(e.source_ref), str(count), _sql(_json(party)),
            _sql(_json(e.roster())), _sql(_json(count_choice)),
            "NULL", _sql(_json(scene)), "NULL", "NULL",
            _sql("PROVISIONAL B1 source-authentic inventory. All source, approval, rules, "
                 "equipment, scene and engine gates must pass before ReadyForExecution=1."),
        ]
        lines.extend([
            f"    -- {e.source_id}: distinct B1 source option; {count} MAX test actors, not automatic stocking.",
            f"    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario] WHERE [ScenarioCode] = {_sql(scenario)})",
            "    BEGIN",
            "        INSERT INTO [Test].[MonsterTestScenario]",
            "        ([ScenarioCode],[ScenarioName],[RulesetCode],[PrimaryMonsterCode],",
            "         [FixtureRevision],[ScenarioStatus],[ReadyForExecution],[OriginReference],",
            "         [MonsterCount],[PartyRosterJson],[MonsterRosterJson],[CountRollJson],",
            "         [SurpriseJson],[SceneFactsJson],[ExpectedHandoffJson],[IllustrationPath],[Notes])",
            "        VALUES (" + ", ".join(fields) + ");",
            "    END",
            "    ELSE IF EXISTS (SELECT 1 FROM [Test].[MonsterTestScenario]",
            f"                   WHERE [ScenarioCode] = {_sql(scenario)} AND",
            f"                    ([PrimaryMonsterCode] <> {_sql(e.species)} OR [ReadyForExecution] <> 0 OR",
            "                     [ScenarioStatus] <> N'Specified' OR [MonsterCount] <> " + str(count) + "))",
            f"        THROW 57822, 'Conflicting existing draft B1 source row; manual review required', 1;",
        ])
        cases = [
            ("SRC", 1, "B1 original source entry, count and roster provenance",
             "ENCOUNTER", "Specified",
             "Verify owner-owned brown-cover printed p.25 option and edition variants before selecting count/room.",
             "Exact source entry ID, HP sequence, optional count range and source edition signed by BON."),
            ("HANDOFF", 2, "Resolved approved species and roster handoff",
             "COMBAT_HANDOFF", "Blocked",
             "Use explicitly Active/Approved version-pinned Rules.Monster, full resolved equipment and party.",
             "Missing RecordDate, rules, scene or unapproved source leaves state unchanged and fails closed."),
            ("ROUND", 3, "Deterministic combat round, conditions, morale and reset",
             "COMBAT", "Blocked",
             "After independently verified Combat special/morale/target rules, inject fixed dice and start battle.",
             "One or more real Python engine rounds, isolated reset, no ignored mechanics or forged UAT."),
        ]
        for suffix, seq, name, phase, status, given, expected in cases:
            case_code = f"{e.source_id}-{suffix}"
            vals = [
                _sql(scenario), _sql(case_code), str(seq), _sql(name),
                _sql(phase), _sql(status), "1", _sql(given), _sql(expected),
                "NULL", "NULL", _sql("AIDM-DES-001.7.12.1"), "NULL",
                _sql("SOURCE/READINESS SPECIFICATION ONLY; not an executed test"),
            ]
            lines.extend([
                f"    IF NOT EXISTS (SELECT 1 FROM [Test].[MonsterTestCase] WHERE [ScenarioCode] = {_sql(scenario)} AND [TestCaseCode] = {_sql(case_code)})",
                "        INSERT INTO [Test].[MonsterTestCase]",
                "        ([ScenarioCode],[TestCaseCode],[SequenceNo],[TestName],[TestPhase],",
                "         [TestStatus],[TestRevision],[GivenText],[ExpectedText],",
                "         [DiceFixtureJson],[AdditionalDataJson],[LinkedStoryRef],[AutomatedTestRef],[Notes])",
                "        VALUES (" + ", ".join(vals) + ");",
            ])
    lines.extend([
        "    COMMIT TRAN;",
        "END TRY",
        "BEGIN CATCH",
        "    IF XACT_STATE() <> 0 ROLLBACK TRAN;",
        "    THROW;",
        "END CATCH;",
        "GO",
        "",
    ])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="AIDM B1 candidate SQL seed generator (no DB I/O)")
    control = parser.add_mutually_exclusive_group(required=True)
    control.add_argument("--check", action="store_true", help="verify committed SQL matches source")
    control.add_argument("--write", action="store_true", help="regenerate committed REVIEW-ONLY SQL")
    args = parser.parse_args(argv)
    sql = render_seed_sql(read_candidates())
    if args.write:
        SEED_SQL.parent.mkdir(parents=True, exist_ok=True)
        SEED_SQL.write_text(sql, encoding="utf-8")
        print(f"Generated review-only SQL: {SEED_SQL}")
        return 0
    if not SEED_SQL.exists() or SEED_SQL.read_text(encoding="utf-8") != sql:
        print("B1 first-five SQL seed is absent or not source-matched")
        return 1
    print("B1 candidate SQL matches source manifest; still NOT READY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
