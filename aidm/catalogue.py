"""AIDM-DES-001.7.9: read-only, versioned monster/test fixture repository.

Purpose: Resolve source-backed SQL row contracts without importing SQL into
        Combat, Browser, DM, or the eventual Encounter orchestrator.
Usage: catalogue = MonsterCatalogue(query=SqlServerReader(connection_factory))
       monster = catalogue.resolve("MentzerBECMI", "ORC")
Change Log: 2026-11-25 DAVOS — first safe provider/roster boundary.

This module NEVER opens a connection on import, performs any SQL mutation,
generates missing HP, executes test cases, or approves a SourceChecked row.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
import json
import re
from types import MappingProxyType
from typing import Any, Callable, Mapping, Protocol, Sequence

_ID = re.compile(r"[A-Za-z][A-Za-z0-9._-]{0,79}\Z")
_DATE = re.compile(r"\d{4}-\d\d-\d\d\Z")
_RULESET = "MentzerBECMI"
_MONSTER_COLS = (
    "RecordDate", "RulesetCode", "MonsterCode", "Active", "MonsterName",
    "ParentMonsterCode", "SourceStatus", "SourceReference", "HouseRuleOverlayRefs",
    "ArmorClass", "HitDiceText", "AttackPattern", "DamagePattern", "SaveAs",
    "Morale", "MovementTurnFeet", "MovementRoundFeet", "MovementSpecialText",
    "Alignment", "XPValue", "NumberAppearingText", "TreasureType",
    "GeneralDescription", "SpecialAttacksFeatures", "SpecialEncounterFeatures",
    "D1Feet", "D2Feet", "ZFeet", "SizeBasis", "IllustrationPath", "MapIconPath",
    "NotesMarkdown",
)
_SCENARIO_COLS = (
    "ScenarioCode", "ScenarioName", "RulesetCode", "PrimaryMonsterCode",
    "FixtureRevision", "ScenarioStatus", "ReadyForExecution", "OriginReference",
    "MonsterCount", "PartyRosterJson", "MonsterRosterJson", "CountRollJson",
    "SurpriseJson", "SceneFactsJson", "ExpectedHandoffJson", "IllustrationPath",
    "Notes",
)
_CASE_COLS = (
    "ScenarioCode", "TestCaseCode", "SequenceNo", "TestName", "TestPhase",
    "TestStatus", "TestRevision", "GivenText", "ExpectedText", "DiceFixtureJson",
    "AdditionalDataJson", "LinkedStoryRef", "AutomatedTestRef", "Notes",
)


class CatalogueError(ValueError):
    """Safe public error: no SQL, DB connection strings, or source prose."""


class NotPlayable(CatalogueError):
    """A requested fixture is not approved/complete or mechanics not verified."""


class CatalogueUnavailable(CatalogueError):
    """Database unavailable; do not forward provider driver exception."""


class RowReader(Protocol):
    def __call__(self, sql: str, parameters: tuple[object, ...]) -> list[dict[str, Any]]: ...


def _id(value: object, label: str) -> str:
    if not isinstance(value, str) or _ID.fullmatch(value) is None:
        raise CatalogueError(f"Invalid {label}")
    return value


def _text(value: object, label: str, *, nullable: bool = False) -> str | None:
    if value is None and nullable:
        return None
    if not isinstance(value, str) or (not nullable and not value.strip()):
        raise CatalogueError(f"Invalid {label}")
    return value


def _date(value: object) -> str:
    if isinstance(value, (datetime, date)):
        return value.date().isoformat() if isinstance(value, datetime) else value.isoformat()
    if not isinstance(value, str) or _DATE.fullmatch(value) is None:
        raise CatalogueError("Invalid RecordDate")
    try:
        return date.fromisoformat(value).isoformat()
    except ValueError:
        raise CatalogueError("Invalid RecordDate") from None


def _int(value: object, label: str, *, minimum: int = 0, maximum: int = 10000) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise CatalogueError(f"Invalid {label}")
    return value


def _bit(value: object, label: str) -> bool:
    if type(value) not in (int, bool) or value not in (0, 1):
        raise CatalogueError(f"Invalid {label}")
    return bool(value)


def _number(value: object, label: str, *, nullable: bool = True,
            allow_zero: bool = False) -> Decimal | None:
    if value is None and nullable:
        return None
    if type(value) is bool or not isinstance(value, (Decimal, int, float, str)):
        raise CatalogueError(f"Invalid {label}")
    try:
        number = Decimal(str(value))
    except Exception:
        raise CatalogueError(f"Invalid {label}") from None
    if not number.is_finite() or number < 0 or (number == 0 and not allow_zero):
        raise CatalogueError(f"Invalid {label}")
    return number


def _json(value: object, label: str, *, required_type: type | None = None,
          nullable: bool = False) -> str | None:
    if value is None and nullable:
        return None
    if not isinstance(value, str) or len(value) > 131072:
        raise CatalogueError(f"Invalid {label}")
    try:
        decoded = json.loads(value)
    except (ValueError, TypeError):
        raise CatalogueError(f"Invalid {label}") from None
    if required_type is not None and type(decoded) is not required_type:
        raise CatalogueError(f"Invalid {label}")
    # Canonical immutable representation. Consumer decodes a fresh copy.
    return json.dumps(decoded, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def _fields(row: Mapping[str, Any], required: tuple[str, ...]) -> None:
    if not isinstance(row, Mapping) or any(x not in row for x in required):
        raise CatalogueError("Incompatible provider schema")


def _select(columns: tuple[str, ...], table: str, tail: str) -> str:
    # SQL identifiers come ONLY from audited module constants, not user input.
    return f"SELECT {', '.join('[' + c + ']' for c in columns)} FROM {table} WHERE {tail}"


def _reviewed_read_contracts() -> dict[str, tuple[str, ...]]:
    """Exactly SIX fixed provider SELECTs: no SQL grammar/prefix acceptance.

    These are the only statements the trusted catalogue/scenario repositories
    construct. A caller cannot pass a second statement, SELECT INTO, alternative
    table/columns, joins, hints or extra predicates to the DB-API adapter.
    The SQL text itself is NOT parameterised by the requesting player or LLM.
    """
    contracts: dict[str, tuple[str, ...]] = {}
    for gate in (
        "[Active] = 1 AND [SourceStatus] = N'Approved'",
        "[Active] = 0 AND [SourceStatus] = N'SourceChecked'",
    ):
        tail = "[RulesetCode] = ? AND [MonsterCode] = ? AND " + gate
        contracts[_select(_MONSTER_COLS, "[Rules].[Monster]", tail)] = (
            "RulesetCode", "MonsterCode",
        )
        contracts[_select(_MONSTER_COLS, "[Rules].[Monster]",
                          tail + " AND [RecordDate] = ?")] = (
            "RulesetCode", "MonsterCode", "RecordDate",
        )
    contracts[_select(_SCENARIO_COLS, "[Test].[MonsterTestScenario]",
                      "[ScenarioCode] = ?")] = ("ScenarioCode",)
    contracts[_select(_CASE_COLS, "[Test].[MonsterTestCase]",
                      "[ScenarioCode] = ?")] = ("ScenarioCode",)
    assert len(contracts) == 6, "Reviewed read-only contract must remain explicit"
    return contracts


# Immutable mapping protects the reviewed query family against later mutation.
_REVIEWED_SQL_READS = MappingProxyType(_reviewed_read_contracts())


def _check_reviewed_read(sql: object, parameters: object) -> None:
    """Validate exact query text AND expected bound values before opening ODBC.

    A genuine SQL SELECT-only login is still mandatory: an allowlist is a
    defence-in-depth boundary and does not confer database privileges.
    """
    if type(sql) is not str or type(parameters) is not tuple:
        raise CatalogueError("Only reviewed parameterised catalogue reads permitted")
    contract = _REVIEWED_SQL_READS.get(sql)
    if contract is None or len(parameters) != len(contract):
        raise CatalogueError("Only reviewed parameterised catalogue reads permitted")
    for name, value in zip(contract, parameters, strict=True):
        if name == "RecordDate":
            if type(value) is not str or _date(value) != value:
                raise CatalogueError("Invalid query parameter")
        else:
            _id(value, "query parameter")


class SqlServerReader:
    """PEP-249 SQL Server adapter. Caller injects a READ-ONLY account/factory.

    Inject connection_factory=lambda: pyodbc.connect(..., timeout=5) in local
    bootstrap. No pyodbc or secrets required at import/test time.
    """

    def __init__(self, connection_factory: Callable[[], Any], *, timeout_seconds: int = 10):
        if not callable(connection_factory) or type(timeout_seconds) is not int or not 1 <= timeout_seconds <= 30:
            raise ValueError("Invalid SQL reader configuration")
        self._open = connection_factory
        self._timeout = timeout_seconds

    def __call__(self, sql: str, parameters: tuple[object, ...]) -> list[dict[str, Any]]:
        # No connection is opened until this exact reviewed query contract is
        # accepted. A SELECT prefix is not a security boundary (SELECT INTO,
        # SELECT; DELETE, and arbitrary table access could otherwise pass).
        _check_reviewed_read(sql, parameters)
        connection = None
        cursor = None
        try:
            connection = self._open()
            # pyodbc sets statement query timeouts on Connection, before
            # opening a Cursor. Cursor.timeout is not a pyodbc attribute.
            connection.timeout = self._timeout
            cursor = connection.cursor()
            cursor.execute(sql, *parameters)
            names = tuple(column[0] for column in cursor.description)
            # Fetch limited, not unbounded results (case list capped at 100).
            rows = cursor.fetchmany(101)
            if len(rows) > 100 or len(names) != len(set(names)):
                raise CatalogueError("Provider result limit exceeded")
            return [dict(zip(names, row, strict=True)) for row in rows]
        except CatalogueError:
            raise
        except Exception:
            raise CatalogueUnavailable("Read-only monster data unavailable") from None
        finally:
            if cursor is not None:
                try: cursor.close()
                except Exception: pass
            if connection is not None:
                try: connection.close()
                except Exception: pass


@dataclass(frozen=True, slots=True)
class MonsterSnapshot:
    ruleset_code: str
    monster_code: str
    record_date: str
    active: bool
    source_status: str
    monster_name: str
    parent_code: str | None
    source_reference: str
    house_rule_overlay_refs: str | None
    armor_class: int | None
    hit_dice_text: str | None
    attack_pattern: str | None
    damage_pattern: str | None
    save_as: str | None
    morale: int | None
    movement_turn_feet: Decimal | None
    movement_round_feet: Decimal | None
    movement_special_text: str | None
    alignment: str | None
    xp_value: int | None
    number_appearing_text: str | None
    treasure_type: str | None
    general_description: str
    special_attacks_features: str
    special_encounter_features: str
    d1_feet: Decimal | None
    d2_feet: Decimal | None
    z_feet: Decimal | None
    size_basis: str | None
    illustration_path: str | None
    map_icon_path: str | None
    notes_markdown: str | None
    schema_version: str = "Rules.Monster.v0.4"

    @property
    def identity(self) -> tuple[str, str, str]:
        return self.ruleset_code, self.monster_code, self.record_date

    @property
    def reference_complete(self) -> bool:
        return all((self.armor_class is not None, bool(self.hit_dice_text),
                    bool(self.attack_pattern), bool(self.damage_pattern),
                    bool(self.save_as), self.morale is not None))


def _monster(row: Mapping[str, Any]) -> MonsterSnapshot:
    _fields(row, _MONSTER_COLS)
    active = _bit(row["Active"], "Active")
    status = _text(row["SourceStatus"], "SourceStatus")
    if status not in ("Draft", "SourceChecked", "Approved", "Superseded"):
        raise CatalogueError("Invalid SourceStatus")
    if active and status != "Approved":
        raise CatalogueError("Inconsistent approval flags")
    def nullable(name: str) -> str | None: return _text(row[name], name, nullable=True)
    def optional_int(name: str, minimum: int = 0, maximum: int = 10000) -> int | None:
        return None if row[name] is None else _int(row[name], name, minimum=minimum, maximum=maximum)
    dims = tuple(_number(row[name], name) for name in ("D1Feet", "D2Feet", "ZFeet"))
    if dims[0] is not None and dims[1] is not None and dims[0] < dims[1]:
        raise CatalogueError("Incompatible diameter data")
    return MonsterSnapshot(
        _id(row["RulesetCode"], "RulesetCode"), _id(row["MonsterCode"], "MonsterCode"),
        _date(row["RecordDate"]), active, status, _text(row["MonsterName"], "MonsterName"),
        nullable("ParentMonsterCode"), _text(row["SourceReference"], "SourceReference"),
        nullable("HouseRuleOverlayRefs"), optional_int("ArmorClass", -50, 50),
        nullable("HitDiceText"), nullable("AttackPattern"), nullable("DamagePattern"),
        nullable("SaveAs"), optional_int("Morale", 2, 12),
        _number(row["MovementTurnFeet"], "MovementTurnFeet", allow_zero=True) if row["MovementTurnFeet"] is not None else None,
        _number(row["MovementRoundFeet"], "MovementRoundFeet", allow_zero=True) if row["MovementRoundFeet"] is not None else None,
        nullable("MovementSpecialText"), nullable("Alignment"), optional_int("XPValue", 0, 1000000000),
        nullable("NumberAppearingText"), nullable("TreasureType"),
        _text(row["GeneralDescription"], "GeneralDescription", nullable=True) or "",
        _text(row["SpecialAttacksFeatures"], "SpecialAttacksFeatures", nullable=True) or "",
        _text(row["SpecialEncounterFeatures"], "SpecialEncounterFeatures", nullable=True) or "",
        *dims, nullable("SizeBasis"), nullable("IllustrationPath"),
        nullable("MapIconPath"), nullable("NotesMarkdown"),
    )


class MonsterCatalogue:
    """Version-pinned lookups. Default production access is Approved+Active only."""

    def __init__(self, query: RowReader, *, rulesets: frozenset[str] = frozenset({_RULESET})):
        if not callable(query) or not rulesets:
            raise ValueError("Missing catalogue provider or allowed rulesets")
        self._query = query
        self._rulesets = rulesets

    def resolve(self, ruleset: str, monster: str, *, record_date: str | None = None,
                source_checked_test_only: bool = False) -> MonsterSnapshot:
        _id(ruleset, "RulesetCode")
        _id(monster, "MonsterCode")
        if ruleset not in self._rulesets:
            raise CatalogueError("Unsupported ruleset")
        if record_date is not None:
            record_date = _date(record_date)
        # Explicit flag is a local development/test opt-in, NEVER a request
        # from Browser or a way to declare a source-checked row playable.
        gate = ("[Active] = 0 AND [SourceStatus] = N'SourceChecked'"
                if source_checked_test_only else "[Active] = 1 AND [SourceStatus] = N'Approved'")
        sql = _select(_MONSTER_COLS, "[Rules].[Monster]",
                      "[RulesetCode] = ? AND [MonsterCode] = ? AND " + gate +
                      (" AND [RecordDate] = ?" if record_date else ""))
        params: tuple[object, ...] = (ruleset, monster) + ((record_date,) if record_date else ())
        rows = self._query(sql, params)
        if len(rows) != 1:
            raise CatalogueError("Monster version missing or ambiguous")
        snap = _monster(rows[0])
        if (snap.ruleset_code != ruleset or snap.monster_code != monster
                or (record_date is not None and snap.record_date != record_date)
                or snap.active == source_checked_test_only
                or snap.source_status != ("SourceChecked" if source_checked_test_only else "Approved")):
            raise CatalogueError("Monster provider returned wrong version/approval")
        return snap

    def resolve_many(self, keys: Sequence[tuple[str, str, str | None]], *,
                     source_checked_test_only: bool = False) -> tuple[MonsterSnapshot, ...]:
        if not 1 <= len(keys) <= 25 or len(set(keys)) != len(keys):
            raise CatalogueError("Invalid or duplicate monster lookup keys")
        return tuple(self.resolve(r, m, record_date=d,
                                  source_checked_test_only=source_checked_test_only)
                     for r, m, d in keys)


@dataclass(frozen=True, slots=True)
class TestCaseDefinition:
    scenario_code: str
    case_code: str
    sequence: int
    name: str
    phase: str
    status: str
    revision: int
    given: str
    expected: str
    dice_json: str | None
    additional_json: str | None
    linked_story: str | None
    automated_test_ref: str | None
    notes: str | None

    @property
    def executable(self) -> bool:
        # Readiness of a definition is NOT an execution result.
        return self.status == "Ready"


@dataclass(frozen=True, slots=True)
class TestScenarioDefinition:
    code: str
    name: str
    ruleset_code: str
    primary_monster_code: str
    revision: int
    status: str
    ready_for_execution: bool
    origin_reference: str
    monster_count: int
    party_roster_json: str
    monster_roster_json: str
    count_roll_json: str | None
    surprise_json: str | None
    scene_facts_json: str
    expected_handoff_json: str | None
    illustration_path: str | None
    notes: str | None
    cases: tuple[TestCaseDefinition, ...]

    @property
    def ready(self) -> bool:
        return (self.ready_for_execution and self.status in ("Ready", "Executed", "PassedUAT")
                and bool(self.cases) and all(case.executable for case in self.cases))


class MonsterTestScenarios:
    """Read the *normalized* [Test] parent and child tables (no legacy JSON)."""

    def __init__(self, query: RowReader):
        if not callable(query):
            raise ValueError("Missing scenario provider")
        self._query = query

    def resolve(self, code: str, *, include_unready_test_only: bool = False) -> TestScenarioDefinition:
        code = _id(code, "ScenarioCode")
        sql = _select(_SCENARIO_COLS, "[Test].[MonsterTestScenario]", "[ScenarioCode] = ?")
        rows = self._query(sql, (code,))
        if len(rows) != 1:
            raise CatalogueError("Test scenario missing or ambiguous")
        row = rows[0]
        _fields(row, _SCENARIO_COLS)
        if row["ScenarioCode"] != code:
            raise CatalogueError("Wrong test scenario")
        ready = _bit(row["ReadyForExecution"], "ReadyForExecution")
        status = _text(row["ScenarioStatus"], "ScenarioStatus")
        if status not in ("Specified", "Ready", "Executed", "PassedUAT", "Superseded"):
            raise CatalogueError("Unknown scenario status")
        if ready and status not in ("Ready", "Executed", "PassedUAT"):
            raise CatalogueError("Contradictory test readiness")
        if not include_unready_test_only and not ready:
            raise NotPlayable("Test scenario not ready for execution")
        case_sql = _select(_CASE_COLS, "[Test].[MonsterTestCase]", "[ScenarioCode] = ?")
        children = self._query(case_sql, (code,))
        if not 1 <= len(children) <= 100:
            raise CatalogueError("Missing or unbounded normalized tests")
        cases = []
        seen_codes: set[str] = set()
        seen_sequences: set[int] = set()
        for child in children:
            _fields(child, _CASE_COLS)
            cc = _id(child["TestCaseCode"], "TestCaseCode")
            seq = _int(child["SequenceNo"], "SequenceNo", minimum=1)
            if child["ScenarioCode"] != code or cc in seen_codes or seq in seen_sequences:
                raise CatalogueError("Duplicate or orphan test case")
            seen_codes.add(cc)
            seen_sequences.add(seq)
            phase = _text(child["TestPhase"], "TestPhase")
            state = _text(child["TestStatus"], "TestStatus")
            if phase not in ("ENCOUNTER", "COMBAT", "COMBAT_HANDOFF", "DEFERRED_LIFECYCLE"):
                raise CatalogueError("Invalid test phase")
            if state not in ("Specified", "Ready", "Deferred", "Blocked", "Superseded"):
                raise CatalogueError("Invalid test status")
            cases.append(TestCaseDefinition(
                code, cc, seq, _text(child["TestName"], "TestName"), phase, state,
                _int(child["TestRevision"], "TestRevision", minimum=1),
                _text(child["GivenText"], "GivenText"),
                _text(child["ExpectedText"], "ExpectedText"),
                _json(child["DiceFixtureJson"], "DiceFixtureJson", nullable=True),
                _json(child["AdditionalDataJson"], "AdditionalDataJson", nullable=True),
                _text(child["LinkedStoryRef"], "LinkedStoryRef", nullable=True),
                _text(child["AutomatedTestRef"], "AutomatedTestRef", nullable=True),
                _text(child["Notes"], "Notes", nullable=True),
            ))
        result = TestScenarioDefinition(
            code, _text(row["ScenarioName"], "ScenarioName"),
            _id(row["RulesetCode"], "RulesetCode"), _id(row["PrimaryMonsterCode"], "PrimaryMonsterCode"),
            _int(row["FixtureRevision"], "FixtureRevision", minimum=1), status, ready,
            _text(row["OriginReference"], "OriginReference"),
            _int(row["MonsterCount"], "MonsterCount", minimum=1, maximum=100),
            _json(row["PartyRosterJson"], "PartyRosterJson", required_type=list),
            _json(row["MonsterRosterJson"], "MonsterRosterJson", required_type=list),
            _json(row["CountRollJson"], "CountRollJson", nullable=True),
            _json(row["SurpriseJson"], "SurpriseJson", nullable=True),
            _json(row["SceneFactsJson"], "SceneFactsJson", required_type=dict),
            _json(row["ExpectedHandoffJson"], "ExpectedHandoffJson", nullable=True),
            _text(row["IllustrationPath"], "IllustrationPath", nullable=True),
            _text(row["Notes"], "Notes", nullable=True),
            tuple(sorted(cases, key=lambda x: x.sequence)),
        )
        if not include_unready_test_only and not result.ready:
            raise NotPlayable("Test case readiness is not verified")
        return result


@dataclass(frozen=True, slots=True)
class ActorSeed:
    """Precombat instance, NOT a species and NOT an authoritative mutable actor."""
    actor_id: str
    species_code: str
    role: str
    starting_hp: int
    source_version: tuple[str, str, str]
    equipment: str | None


@dataclass(frozen=True, slots=True)
class CombatMonsterProfile:
    """Only COMBAT-approved rules are handed off; Encounter guidance stays private."""
    identity: tuple[str, str, str]
    armor_class: int
    hit_dice_text: str
    attack_pattern: str
    damage_pattern: str
    save_as: str
    morale: int
    special_attacks_features: str


@dataclass(frozen=True, slots=True)
class CombatRosterHandoff:
    """Self-contained candidate for future Encounter→Combat; no SQL link."""
    scenario_code: str
    fixture_revision: int
    origin_reference: str
    party_roster_json: str
    scene_facts_json: str
    actors: tuple[ActorSeed, ...]
    sources: tuple[CombatMonsterProfile, ...]
    mechanics_verified_ref: str


def build_test_handoff(scenario: TestScenarioDefinition,
                       catalogue: MonsterCatalogue, *,
                       mechanics_verified_ref: str | None = None) -> CombatRosterHandoff:
    """Explicit trusted test-bootstrap step, not Encounter dispatch.

    A separate rules/owner-verified capability receipt MUST be provided.
    This does not instantiate CombatEngine; DES-020/.7.12.1 own that wiring.
    """
    if not scenario.ready:
        raise NotPlayable("Scenario/test cases not execution ready")
    if not mechanics_verified_ref or _ID.fullmatch(mechanics_verified_ref) is None:
        raise NotPlayable("Mechanics approval receipt required")
    roster = json.loads(scenario.monster_roster_json)
    party = json.loads(scenario.party_roster_json)
    if (not isinstance(roster, list) or len(roster) != scenario.monster_count
            or not isinstance(party, list) or not party):
        raise NotPlayable("Incomplete scenario roster")
    keys = []
    seen: set[str] = set()
    actor_info = []
    for entry in roster:
        if not isinstance(entry, dict):
            raise NotPlayable("Invalid actor")
        ident = _id(entry.get("actor_id"), "actor_id")
        species = _id(entry.get("species"), "species")
        role = _id(entry.get("role"), "role")
        hp = entry.get("hp_start")
        if ident in seen or type(hp) is not int or not 1 <= hp <= 10000:
            raise NotPlayable("Missing, duplicate or invalid actor HP")
        seen.add(ident)
        equipment = entry.get("weapon")
        if equipment is not None and not isinstance(equipment, str):
            raise NotPlayable("Invalid actor equipment")
        # An authored optional RecordDate must be honoured, never replaced
        # by a different active version just because its species matches.
        pinned_date = entry.get("species_record_date")
        if pinned_date is not None:
            pinned_date = _date(pinned_date)
        actor_info.append((ident, species, role, hp, equipment, pinned_date))
        keys.append((scenario.ruleset_code, species, pinned_date))
    if scenario.primary_monster_code not in {species for _, species, _, _, _, _ in actor_info}:
        raise NotPlayable("Primary species missing from roster")
    for entry in party:
        if not isinstance(entry, dict) or _id(entry.get("actor_id"), "party actor_id") in seen:
            raise NotPlayable("Duplicate or invalid party actor")
        ident = entry["actor_id"]
        seen.add(ident)
        if type(entry.get("hp_start")) is not int or entry["hp_start"] < 1:
            raise NotPlayable("Missing party HP")
    versions: dict[str, MonsterSnapshot] = {}
    requested_dates: dict[str, set[str | None]] = {}
    for _, species, record_date in keys:
        requested_dates.setdefault(species, set()).add(record_date)
    if any(len(dates) > 1 for dates in requested_dates.values()):
        raise NotPlayable("Conflicting or partially pinned source version within species")
    for _, species, record_date in dict.fromkeys(keys):
        snapshot = catalogue.resolve(scenario.ruleset_code, species,
                                     record_date=record_date)
        if not snapshot.reference_complete:
            raise NotPlayable("Species rules incomplete")
        versions[species] = snapshot
    actors = tuple(ActorSeed(ident, species, role, hp, versions[species].identity, equip)
                   for ident, species, role, hp, equip, _ in actor_info)
    # The Combat handoff must NEVER include GeneralDescription or
    # SpecialEncounterFeatures. Encounter alone consumes negotiation,
    # camouflage, ecology and other non-combat guidance from full snapshots.
    profiles = tuple(CombatMonsterProfile(
        m.identity, m.armor_class, m.hit_dice_text, m.attack_pattern,
        m.damage_pattern, m.save_as, m.morale, m.special_attacks_features
    ) for m in versions.values())
    return CombatRosterHandoff(
        scenario.code, scenario.revision, scenario.origin_reference,
        scenario.party_roster_json, scenario.scene_facts_json,
        actors, profiles, mechanics_verified_ref,
    )


def public_monster_asset(monster: MonsterSnapshot, *, revealed: bool) -> dict[str, str]:
    """Small explicitly revealed public projection; never sends source secrets."""
    if not revealed or not monster.active or monster.source_status != "Approved":
        return {}
    def safe_asset(value: str | None) -> str:
        if not value or not re.fullmatch(r"(?:assets|static)/[A-Za-z0-9._/-]+", value):
            return ""
        return value if ".." not in value.split("/") else ""

    return {"name": monster.monster_name,
            "illustration_path": safe_asset(monster.illustration_path),
            "map_icon_path": safe_asset(monster.map_icon_path)}
