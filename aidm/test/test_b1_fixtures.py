"""DES-001.7.12.1: source candidate, 39-entry allocation and SQL seed regressions.

Usage: python -m pytest aidm/test/test_b1_fixtures.py -q

The first five are explicit SPECIFICATIONS, not approved/READY combat fixtures.
"""
from __future__ import annotations

from dataclasses import FrozenInstanceError
import json
from pathlib import Path

import pytest

from aidm.b1_fixtures import (
    B1CandidateError, MANIFEST, SEED_SQL, _sql, main, read_candidates, render_seed_sql,
)


def test_first_five_are_real_distinct_b1_source_ids_not_species_stubs():
    entries = read_candidates()
    assert tuple(e.source_id for e in entries) == ("S12", "S15", "S16", "S20", "S25")
    assert len({e.scenario_code for e in entries}) == len({e.fixture_id for e in entries}) == 5
    assert [e.species for e in entries] == [
        "GNOLL", "HOBGOBLIN", "GOBLIN", "BANDIT", "GOBLIN"
    ]
    assert all(e.source_page == 25 and e.source_ref.endswith(e.source_id) for e in entries)
    assert all(e.mechanics_questions for e in entries)
    # S16 / S25 are *independent original B1 options*, not two aliases.
    s16, s25 = entries[2], entries[4]
    assert s16.source_hp == (7, 5, 4, 3, 3, 3, 2, 1)
    assert (s16.count_min, s16.count_max) == (1, 8)
    assert s25.source_hp == (6, 5, 5, 4, 3, 2)
    assert (s25.count_min, s25.count_max) == (1, 6)
    with pytest.raises(FrozenInstanceError):
        s16.species = "ORC"


def test_b1_hp_and_number_are_explicit_source_variants_not_rolled_by_code():
    entries = read_candidates()
    assert {e.source_id: e.source_hp for e in entries} == {
        "S12": (13, 7, 6, 3),
        "S15": (9, 8, 6, 4, 3),
        "S16": (7, 5, 4, 3, 3, 3, 2, 1),
        "S20": (7, 5, 4, 2),
        "S25": (6, 5, 5, 4, 3, 2),
    }
    for e in entries:
        actors = e.roster()
        assert len(actors) == e.count_max
        assert [actor["hp_start"] for actor in actors] == list(e.source_hp)
        assert len({a["actor_id"] for a in actors}) == e.count_max
        assert all(a["species_record_date"] is None for a in actors)
        assert all(a["equipment"] is None for a in actors)
        assert all(a["role"] == "SOURCE_UNDESIGNATED" for a in actors)


def test_entire_39_source_ids_allocated_once_and_remaining_34_not_falsely_in_slice():
    allocation_path = MANIFEST.with_name("B1_Source_Allocation_Proposal.json")
    data = json.loads(allocation_path.read_text(encoding="utf-8"))
    assert data["status"] == "DAVOS_PROPOSAL_ONLY_PENDING_BON_ALEK_APPROVAL"
    children = data["children"]
    assert set(children) == {
        f"AIDM-DES-001.7.12.{n}" for n in range(1, 9)
    }
    assert [len(children[f"AIDM-DES-001.7.12.{n}"]) for n in range(1, 9)] == [
        5, 5, 5, 5, 5, 5, 5, 4
    ]
    all_ids = [entry for choices in children.values() for entry in choices]
    expected = (
        {f"S{i:02d}" for i in range(1, 26)}
        | {f"U{i:02d}" for i in range(1, 7)}
        | {f"L{i:02d}" for i in range(1, 7)}
        | {"R53", "R54"}
    )
    assert len(all_ids) == 39
    assert len(set(all_ids)) == 39
    assert set(all_ids) == expected
    assert children["AIDM-DES-001.7.12.1"] == [e.source_id for e in read_candidates()]


def _bad_manifest(tmp_path: Path, transform):
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    transform(data)
    path = tmp_path / "invalid.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


@pytest.mark.parametrize("transform", [
    lambda d: d.update({"ready_for_execution": True}),
    lambda d: d.update({"allocation_status": "APPROVED"}),
    lambda d: d.update({"record_date_policy": "DATE_GUESSED"}),
    lambda d: d.update({"schema": "wrong.version"}),
    lambda d: d["entries"].pop(),
    lambda d: d["entries"][1].update({"source_id": "S12"}),
    lambda d: d["entries"][1].update({"fixture_id": "b1.stock.12"}),
    lambda d: d["entries"][0].update({"source_hp": [13, 7, 6]}),
    lambda d: d["entries"][2].update({"count_max": 7}),
    lambda d: d["entries"][0].update({"source_hp": [13, None, 6, 3]}),
    lambda d: d["entries"][0].update({"armor_class": True}),
    lambda d: d["entries"][0].update({"mechanics_questions": []}),
    lambda d: d["entries"][0].update({"species": "ORC;DROP"}),
])
def test_manifest_invalid_source_or_premature_approval_fails_closed(tmp_path, transform):
    with pytest.raises(B1CandidateError):
        read_candidates(_bad_manifest(tmp_path, transform))


def test_nonexistent_or_invalid_json_manifest_rejected(tmp_path):
    with pytest.raises(B1CandidateError):
        read_candidates(tmp_path / "absent.json")
    (tmp_path / "bad.json").write_text("[wrong", encoding="utf-8")
    with pytest.raises(B1CandidateError):
        read_candidates(tmp_path / "bad.json")


def test_generated_sql_seed_exactly_matches_source_and_never_makes_ready():
    sql = render_seed_sql(read_candidates())
    assert sql == SEED_SQL.read_text(encoding="utf-8")
    assert "BEGIN TRAN;" in sql and "COMMIT TRAN;" in sql
    assert "IF XACT_STATE() <> 0 ROLLBACK TRAN;" in sql
    assert sql.count("INSERT INTO [Test].[MonsterTestScenario]") == 5
    assert sql.count("INSERT INTO [Test].[MonsterTestCase]") == 15
    assert sql.count("N'Specified', 0,") == 5
    assert sql.count("N'Blocked'") == 10
    assert "ReadyForExecution] = 1" not in sql
    assert "UPDATE [Rules].[Monster]" not in sql
    assert "CREATE TABLE" not in sql and "DROP TABLE" not in sql
    assert "B1-S12" in sql and "B1-S25" in sql
    assert "source_hp_ordinal" in sql
    assert "bon_source_approved" in sql
    assert '"species_record_date":null' in sql


def test_sql_escapes_source_text_but_rejects_control_characters():
    assert _sql("Gnoll's lair") == "N'Gnoll''s lair'"
    with pytest.raises(B1CandidateError):
        _sql("bad\nrecord")
    with pytest.raises(B1CandidateError):
        render_seed_sql(read_candidates()[:4])


def test_developer_cli_fails_closed_on_outdated_seed_and_can_regenerate(tmp_path, monkeypatch):
    import aidm.b1_fixtures as module
    target = tmp_path / "regenerated.sql"
    monkeypatch.setattr(module, "SEED_SQL", target)
    assert main(["--check"]) == 1
    assert main(["--write"]) == 0
    assert target.read_text(encoding="utf-8") == render_seed_sql(read_candidates())
    assert main(["--check"]) == 0
    target.write_text("WRONG", encoding="utf-8")
    assert main(["--check"]) == 1


def test_b1_source_candidates_cannot_be_started_by_original_selector_yet():
    html = (MANIFEST.parents[1] / "aidm" / "web" / "static" / "index.html").read_text(
        encoding="utf-8"
    )
    for entry in read_candidates():
        assert f'<option value="{entry.fixture_id}" disabled>' in html
