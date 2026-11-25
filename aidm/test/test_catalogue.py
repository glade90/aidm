"""DES-001.7.9: real schema v0.4/v0.3/v0.2 offline provider and handoff tests.

Usage: python -m pytest aidm/test/test_catalogue.py -q
No SQL Server, secrets, network, UI or provider driver dependency.
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from dataclasses import FrozenInstanceError, replace
import json
import pytest

from aidm.catalogue import (
    CatalogueError, CatalogueUnavailable, MonsterCatalogue,
    MonsterTestScenarios, NotPlayable, SqlServerReader,
    build_test_handoff, public_monster_asset, _MONSTER_COLS, _SCENARIO_COLS, _CASE_COLS,
)


def monster_row(*, code="ORC", status="Approved", active=1, record="2026-11-21", **overrides):
    row = {name: None for name in _MONSTER_COLS}
    row.update({
        "RecordDate": record, "RulesetCode": "MentzerBECMI", "MonsterCode": code,
        "Active": active, "SourceStatus": status, "MonsterName": "Orc",
        "SourceReference": "Mentzer 1983 DMRB p. x", "ArmorClass": 6,
        "HitDiceText": "1", "AttackPattern": "1", "DamagePattern": "1d6",
        "SaveAs": "F1", "Morale": 8, "MovementTurnFeet": Decimal("90"),
        "MovementRoundFeet": Decimal("30"), "GeneralDescription": "Humanoid.",
        "SpecialAttacksFeatures": "Daylight: -1 to Hit, not damage.",
        "SpecialEncounterFeatures": "May stand off and negotiate; no fixed hostility.",
        "D1Feet": Decimal("2.5"), "D2Feet": Decimal("1.5"),
        "ZFeet": Decimal("5.0"), "SizeBasis": "illustrative",
        "HouseRuleOverlayRefs": None,
        "IllustrationPath": "assets/monsters/orc.png",
        "MapIconPath": "assets/monsters/orc_icon.png",
    })
    row.update(overrides)
    return row


def scenario_row(*, ready=0, status="Specified", monster_hp=6,
                 code="ORC-T001-A", **overrides):
    row = {key: None for key in _SCENARIO_COLS}
    row.update({
        "ScenarioCode": code, "ScenarioName": "Orc patrol",
        "RulesetCode": "MentzerBECMI", "PrimaryMonsterCode": "ORC",
        "FixtureRevision": 1, "ScenarioStatus": status, "ReadyForExecution": ready,
        "OriginReference": "Synthetic test, NOT a B1 HP source",
        "MonsterCount": 1,
        "PartyRosterJson": json.dumps([{"actor_id": "PC-T", "hp_start": 20}]),
        "MonsterRosterJson": json.dumps([{
            "actor_id": "ORC-A", "species": "ORC", "role": "ordinary",
            "hp_start": monster_hp, "armor_class": 6, "weapon": "shortsword",
        }]),
        "SceneFactsJson": json.dumps({"daylight": True, "hostility": "not predetermined"}),
    })
    row.update(overrides)
    return row


def case_row(*, code="ORC-T001-A", status="Specified", number=1, **overrides):
    row = {key: None for key in _CASE_COLS}
    row.update({
        "ScenarioCode": code, "TestCaseCode": "ORC-T01",
        "SequenceNo": number, "TestName": "Daylight hit penalty",
        "TestPhase": "COMBAT", "TestStatus": status, "TestRevision": 1,
        "GivenText": "Given Orc in daylight", "ExpectedText": "-1 to Hit only",
        "DiceFixtureJson": '{"attack_d20":12}',
    })
    row.update(overrides)
    return row


class FakeQuery:
    def __init__(self, monsters=(), scenarios=(), cases=()):
        self.monsters = list(monsters)
        self.scenarios = list(scenarios)
        self.cases = list(cases)
        self.calls = []

    def __call__(self, sql, parameters):
        self.calls.append((sql, parameters))
        if "[Rules].[Monster]" in sql:
            rows = [r for r in self.monsters
                    if r["RulesetCode"] == parameters[0] and r["MonsterCode"] == parameters[1]]
            if "[SourceStatus] = N'Approved'" in sql:
                rows = [r for r in rows if r["Active"] == 1 and r["SourceStatus"] == "Approved"]
            elif "[SourceStatus] = N'SourceChecked'" in sql:
                rows = [r for r in rows if r["Active"] == 0 and r["SourceStatus"] == "SourceChecked"]
            if len(parameters) == 3:
                rows = [r for r in rows if str(r["RecordDate"]) == parameters[2]]
            return rows
        if "[Test].[MonsterTestScenario]" in sql:
            return [r for r in self.scenarios if r["ScenarioCode"] == parameters[0]]
        if "[Test].[MonsterTestCase]" in sql:
            return [r for r in self.cases if r["ScenarioCode"] == parameters[0]]
        raise AssertionError("Unexpected SQL table")


def test_catalogue_preserves_all_mapped_v04_fields_and_separates_guidance():
    fake = FakeQuery(monsters=[monster_row()])
    catalogue = MonsterCatalogue(fake)
    monster = catalogue.resolve("MentzerBECMI", "ORC")
    assert monster.identity == ("MentzerBECMI", "ORC", "2026-11-21")
    assert monster.schema_version == "Rules.Monster.v0.4"
    assert monster.reference_complete
    assert monster.armor_class == 6
    assert monster.hit_dice_text == "1" and monster.attack_pattern == "1"
    assert monster.morale == 8
    assert (monster.movement_turn_feet, monster.movement_round_feet) == (90, 30)
    assert (monster.d1_feet, monster.d2_feet, monster.z_feet) == (
        Decimal("2.5"), Decimal("1.5"), Decimal("5")
    )
    assert "Daylight" in monster.special_attacks_features
    assert "negotiate" in monster.special_encounter_features
    assert monster.special_encounter_features != monster.general_description
    assert "[Rules].[Monster]" in fake.calls[0][0]
    assert "[SpecialEncounterFeatures]" in fake.calls[0][0]
    assert "[D1Feet]" in fake.calls[0][0]
    assert fake.calls[0][1] == ("MentzerBECMI", "ORC")
    with pytest.raises(FrozenInstanceError):
        monster.armor_class = 5


@pytest.mark.parametrize("change", [
    {"ArmorClass": None}, {"HitDiceText": None}, {"AttackPattern": None},
    {"DamagePattern": None}, {"SaveAs": None}, {"Morale": None},
])
def test_nullable_unknown_core_stats_are_not_imputed_as_playable(change):
    row = monster_row(**change)
    snap = MonsterCatalogue(FakeQuery(monsters=[row])).resolve("MentzerBECMI", "ORC")
    assert not snap.reference_complete


def test_unapproved_seed_is_hidden_by_default_and_test_only_opt_in_never_approves():
    fake = FakeQuery(monsters=[monster_row(status="SourceChecked", active=0)])
    c = MonsterCatalogue(fake)
    with pytest.raises(CatalogueError):
        c.resolve("MentzerBECMI", "ORC")
    draft = c.resolve("MentzerBECMI", "ORC", source_checked_test_only=True)
    assert not draft.active and draft.source_status == "SourceChecked"
    assert public_monster_asset(draft, revealed=True) == {}
    assert "[Active] = 0" in fake.calls[-1][0]


@pytest.mark.parametrize("bad", [
    "OTHER", "ORC;DROP TABLE Rules.Monster", "", "a"*81,
])
def test_unknown_or_unsafe_ruleset_monster_lookups_fail_before_database(bad):
    q = FakeQuery(monsters=[monster_row()])
    c = MonsterCatalogue(q)
    with pytest.raises(CatalogueError):
        c.resolve(bad, "ORC")
    assert not q.calls


def test_invalid_monster_code_date_and_duplicate_keys_fail_closed():
    q = FakeQuery(monsters=[monster_row()])
    c = MonsterCatalogue(q)
    with pytest.raises(CatalogueError):
        c.resolve("MentzerBECMI", "ORC;DELETE")
    with pytest.raises(CatalogueError):
        c.resolve("MentzerBECMI", "ORC", record_date="2026-11-40")
    with pytest.raises(CatalogueError):
        c.resolve_many([("MentzerBECMI", "ORC", None)] * 2)
    assert not q.calls


def test_explicit_version_guard_and_missing_version():
    q = FakeQuery(monsters=[monster_row()])
    c = MonsterCatalogue(q)
    assert c.resolve("MentzerBECMI", "ORC", record_date="2026-11-21").record_date == "2026-11-21"
    with pytest.raises(CatalogueError):
        c.resolve("MentzerBECMI", "ORC", record_date="2026-11-22")
    q.monsters.append(monster_row(record="2026-11-22"))
    with pytest.raises(CatalogueError):
        c.resolve("MentzerBECMI", "ORC")  # two approved active rows, illegal but fail-safe


def test_missing_column_unexpected_approval_wrong_version_rejected():
    row = monster_row()
    del row["SpecialEncounterFeatures"]
    with pytest.raises(CatalogueError):
        MonsterCatalogue(FakeQuery(monsters=[row])).resolve("MentzerBECMI", "ORC")
    wrong = monster_row(status="Draft", active=1)
    with pytest.raises(CatalogueError):
        # Force an untrusted provider to return a row violating SQL's WHERE.
        MonsterCatalogue(lambda sql, args: [wrong]).resolve("MentzerBECMI", "ORC")
    with pytest.raises(CatalogueError):
        MonsterCatalogue(lambda sql, args: [monster_row(code="GOBLIN")]).resolve(
            "MentzerBECMI", "ORC"
        )


@pytest.mark.parametrize("dimensions", [
    {"D1Feet": Decimal("1"), "D2Feet": Decimal("2")},
    {"ZFeet": Decimal("-1")}, {"D2Feet": "NaN"},
])
def test_invalid_dimensions_rejected_without_geometry_inference(dimensions):
    q = FakeQuery(monsters=[monster_row(**dimensions)])
    with pytest.raises(CatalogueError):
        MonsterCatalogue(q).resolve("MentzerBECMI", "ORC")


def test_readonly_dbapi_adapter_is_parameterised_bounded_closes_and_masks_errors():
    class Cursor:
        description = (("MonsterCode",), ("RecordDate",))
        timeout = None
        def __init__(self): self.calls = []; self.closed = False
        def execute(self, sql, *params): self.calls.append((sql, params))
        def fetchmany(self, n):
            assert n == 101
            return [("ORC", date(2026, 11, 21))]
        def close(self): self.closed = True
    class Connection:
        def __init__(self): self.cur = Cursor(); self.closed = False
        def cursor(self): return self.cur
        def close(self): self.closed = True
    obj = Connection()
    reader = SqlServerReader(lambda: obj)
    rows = reader("SELECT [MonsterCode], [RecordDate] FROM [Rules].[Monster] WHERE [MonsterCode] = ?", ("ORC",))
    assert rows == [{"MonsterCode": "ORC", "RecordDate": date(2026, 11, 21)}]
    assert obj.cur.calls[0][1] == ("ORC",) and obj.cur.timeout == 10
    assert obj.closed and obj.cur.closed
    with pytest.raises(CatalogueError):
        reader("DELETE FROM [Rules].[Monster]", ())
    with pytest.raises(CatalogueUnavailable) as error:
        SqlServerReader(lambda: (_ for _ in ()).throw(RuntimeError("password=secret")))(
            "SELECT 1", ()
        )
    assert "secret" not in str(error.value)


def test_normalized_scenario_and_cases_remain_specification_not_results():
    fake = FakeQuery(
        scenarios=[scenario_row()],
        cases=[case_row(), case_row(number=2, TestCaseCode="ORC-T02", TestStatus="Deferred")],
    )
    repository = MonsterTestScenarios(fake)
    with pytest.raises(NotPlayable):
        repository.resolve("ORC-T001-A")
    scenario = repository.resolve("ORC-T001-A", include_unready_test_only=True)
    assert scenario.code == "ORC-T001-A"
    assert scenario.monster_count == 1
    assert scenario.status == "Specified" and not scenario.ready
    assert [c.case_code for c in scenario.cases] == ["ORC-T01", "ORC-T02"]
    assert scenario.cases[0].phase == "COMBAT"
    assert not scenario.cases[0].executable
    assert scenario.cases[0].dice_json == '{"attack_d20":12}'
    assert "[Test].[MonsterTestScenario]" in fake.calls[0][0]
    assert "[Test].[MonsterTestCase]" in fake.calls[1][0]
    assert "TestCasesJson" not in fake.calls[0][0]
    assert "TestCasesJson" not in fake.calls[1][0]
    with pytest.raises(NotPlayable):
        build_test_handoff(scenario, MonsterCatalogue(FakeQuery(monsters=[monster_row()])),
                           mechanics_verified_ref="verified.rules.1")


@pytest.mark.parametrize("change", [
    {"ScenarioStatus": "Specified", "ReadyForExecution": 1},
    {"PartyRosterJson": "{"}, {"MonsterRosterJson": "{}"},
    {"SceneFactsJson": "[]"},
])
def test_invalid_test_scenario_shapes_fail_closed(change):
    q = FakeQuery(scenarios=[scenario_row(**change)], cases=[case_row()])
    with pytest.raises(CatalogueError):
        MonsterTestScenarios(q).resolve("ORC-T001-A", include_unready_test_only=True)


def test_duplicate_case_sequence_parent_or_invalid_case_phase_blocks_resolution():
    base = scenario_row()
    variants = [
        [case_row(), case_row(TestCaseCode="ORC-T02")],  # same SequenceNo
        [case_row(), case_row(number=2)],  # duplicate CaseCode
        [case_row(ScenarioCode="WRONG")],  # wrong foreign key
        [case_row(TestPhase="UNSUPPORTED")],
    ]
    for children in variants:
        q = FakeQuery(scenarios=[base], cases=children)
        # Wrong-parent row does not survive ordinary FakeQuery filter;
        # it must still fail because the scenario has no valid child rows.
        with pytest.raises(CatalogueError):
            MonsterTestScenarios(q).resolve("ORC-T001-A", include_unready_test_only=True)


def test_readiness_requires_all_child_case_statuses_ready():
    q = FakeQuery(scenarios=[scenario_row(status="Ready", ready=1)],
                  cases=[case_row(status="Specified")])
    with pytest.raises(NotPlayable):
        MonsterTestScenarios(q).resolve("ORC-T001-A")
    q.cases = [case_row(status="Ready")]
    assert MonsterTestScenarios(q).resolve("ORC-T001-A").ready


def test_roster_requires_real_hp_and_separate_mechanics_approval():
    m = MonsterCatalogue(FakeQuery(monsters=[monster_row()]))
    repo = MonsterTestScenarios(FakeQuery(
        scenarios=[scenario_row(status="Ready", ready=1, monster_hp=None)],
        cases=[case_row(status="Ready")],
    ))
    scenario = repo.resolve("ORC-T001-A")
    with pytest.raises(NotPlayable):
        build_test_handoff(scenario, m, mechanics_verified_ref="verified.rules.1")
    ready = MonsterTestScenarios(FakeQuery(
        scenarios=[scenario_row(status="Ready", ready=1)],
        cases=[case_row(status="Ready")],
    )).resolve("ORC-T001-A")
    with pytest.raises(NotPlayable):
        build_test_handoff(ready, m)
    with pytest.raises(NotPlayable):
        build_test_handoff(ready, m, mechanics_verified_ref="arbitrary bad\nvalue")


def test_two_rosters_distinct_hp_same_version_and_no_combat_or_db_dependency():
    q = FakeQuery(monsters=[monster_row()])
    catalogue = MonsterCatalogue(q)
    a = MonsterTestScenarios(FakeQuery(
        scenarios=[scenario_row(ready=1, status="Ready", monster_hp=6, code="ORC-T001-A")],
        cases=[case_row(status="Ready", code="ORC-T001-A")],
    )).resolve("ORC-T001-A")
    b = MonsterTestScenarios(FakeQuery(
        scenarios=[scenario_row(ready=1, status="Ready", monster_hp=4, code="ORC-T001-B")],
        cases=[case_row(status="Ready", code="ORC-T001-B")],
    )).resolve("ORC-T001-B")
    x = build_test_handoff(a, catalogue, mechanics_verified_ref="owner.rules.checked")
    y = build_test_handoff(b, catalogue, mechanics_verified_ref="owner.rules.checked")
    assert x.actors[0].starting_hp == 6 and y.actors[0].starting_hp == 4
    assert x.actors[0].source_version == y.actors[0].source_version
    assert x.sources[0].identity == y.sources[0].identity
    assert "Daylight" in x.sources[0].special_attacks_features
    assert "negotiate" in x.sources[0].special_encounter_features
    assert x.origin_reference.startswith("Synthetic test")
    assert not hasattr(x, "combat_engine")
    with pytest.raises(FrozenInstanceError):
        x.actors[0].starting_hp = 12
    assert all("[Rules].[Monster]" in sql for sql, _ in q.calls)


def test_public_asset_projection_hide_secrets_until_approved_and_revealed():
    c = MonsterCatalogue(FakeQuery(monsters=[monster_row()]))
    monster = c.resolve("MentzerBECMI", "ORC")
    assert public_monster_asset(monster, revealed=False) == {}
    public = public_monster_asset(monster, revealed=True)
    assert public == {
        "name": "Orc", "illustration_path": "assets/monsters/orc.png",
        "map_icon_path": "assets/monsters/orc_icon.png",
    }
    assert "Daylight" not in repr(public)
    assert "SourceReference" not in repr(public)
