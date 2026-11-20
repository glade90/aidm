"""AIDM-DES-028.3 G01-G07/G11/G12: exact Python gate and durable reports.

Purpose: Exercise runner in memory with controlled pytest/JUnit/coverage XML;
         no subprocess, browser, model, database, API key or network required.
Usage: python -m pytest aidm/test/test_coverage_gate.py -q
Change Log: 2026-11-20 COSTA — first exact-threshold regression suite.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tomllib
from xml.etree import ElementTree

import pytest

import aidm.test_runner as runner
from aidm.versioning import BuildIdentity


@pytest.fixture
def fake_suite(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Create distinct real reports from simulated test commands in a temp root."""
    package = tmp_path / "aidm"
    package.mkdir()
    monkeypatch.setattr(runner, "__file__", str(package / "test_runner.py"))
    identity = BuildIdentity(
        "0.1.0", "a" * 40, "development", "dev-aaaaaaaaaaaa", "UNKNOWN", False,
    )
    monkeypatch.setattr(runner, "get_build_identity", lambda root: identity)
    state = {"covered": 90, "valid": 100, "exit": 0, "xml": "valid",
             "junit": "valid", "calls": [], "raise": False}

    def fake_run(cmd, **kwargs):
        assert cmd[:4] == [runner.sys.executable, "-m", "pytest", "aidm"]
        assert "--cov=aidm" in cmd
        assert "--cov-fail-under=90" in cmd
        assert "--cov-report=term-missing" in cmd
        assert kwargs["cwd"] == tmp_path
        assert kwargs["env"]["COVERAGE_FILE"].endswith(".coverage")
        state["calls"].append((tuple(cmd), kwargs["env"].copy()))
        if state["raise"]:
            raise OSError("the executable cannot run")
        report = Path(cmd[cmd.index("--junitxml") + 1])
        if state["junit"] == "valid":
            ElementTree.ElementTree(ElementTree.Element(
                "testsuite", name="aidm", tests="2", failures="1" if state["exit"] == 1 else "0",
                skipped="0", errors="0", time="0.01",
            )).write(report, encoding="utf-8", xml_declaration=True)
        elif state["junit"] == "malformed":
            report.write_text("<testsuite", encoding="utf-8")
        cov_path = next(Path(arg.split("=xml:", 1)[1]) for arg in cmd if arg.startswith("--cov-report=xml:"))
        if state["xml"] == "valid":
            ElementTree.ElementTree(ElementTree.Element(
                "coverage", **{"lines-covered": str(state["covered"]),
                                "lines-valid": str(state["valid"])}
            )).write(cov_path, encoding="utf-8")
        elif state["xml"] == "malformed":
            cov_path.write_text("<coverage", encoding="utf-8")
        elif state["xml"] == "wrong_root":
            cov_path.write_text('<notcoverage lines-covered="90" lines-valid="100"/>', encoding="utf-8")
        return subprocess.CompletedProcess(cmd, int(state["exit"]), "simulated pytest output\n")

    monkeypatch.setattr(runner.subprocess, "run", fake_run)

    def execute(*, covered=90, valid=100, pytest_exit=0, xml="valid", junit="valid", raise_spawn=False,
                demonstrate_failure=False):
        state.update(covered=covered, valid=valid, exit=pytest_exit, xml=xml,
                     junit=junit)
        state["raise"] = raise_spawn
        result = runner.main(["--demonstrate-failure"] if demonstrate_failure else [])
        dirs = sorted((tmp_path / "reports" / "test-runs").iterdir())
        directory = dirs[-1]
        # Return the newest run by unique timestamped directory rather than relying on system time.
        manifest = json.loads((directory / "run.json").read_text(encoding="utf-8"))
        return result, manifest, directory

    return execute, state


def test_g01_89_of_100_returns_failure_with_complete_reports(fake_suite):
    execute, _ = fake_suite
    exit_code, manifest, directory = execute(covered=89, valid=100)
    assert exit_code != 0 and manifest["result"] == "FAIL"
    assert manifest["pytest_exit_code"] == 0  # Independent safeguard; even mocked pytest success fails.
    assert manifest["runner_exit_code"] == 1
    assert manifest["line_coverage_percent"] == 89.0
    assert manifest["coverage_gate"]["covered_lines"] == 89
    assert manifest["coverage_gate"]["valid_lines"] == 100
    assert manifest["coverage_gate"]["passed"] is False
    assert "below" in manifest["coverage_gate"]["reason"]
    assert (directory / "coverage.xml").is_file()
    assert (directory / "junit.xml").is_file()
    assert "Coverage gate >= 90.00%: FAIL" in (directory / "summary.txt").read_text()


def test_g02_exact_90_of_100_returns_success(fake_suite):
    execute, _ = fake_suite
    exit_code, manifest, directory = execute(covered=90, valid=100)
    assert exit_code == 0 and manifest["result"] == "PASS"
    assert manifest["coverage_gate"]["passed"] is True
    assert manifest["line_coverage_covered"] == 90
    assert manifest["line_coverage_valid"] == 100
    assert manifest["failure_reasons"] == []
    assert "Coverage gate >= 90.00%: PASS" in (directory / "summary.txt").read_text()


@pytest.mark.parametrize("covered,valid", [
    (899999, 1000000),  # 89.9999%, looks like 90.00% displayed
    (89999, 100000),
    (899, 1000),
    (0, 1),
])
def test_g03_exact_integer_comparison_rejects_rounded_90(fake_suite, covered, valid):
    execute, _ = fake_suite
    exit_code, manifest, _ = execute(covered=covered, valid=valid)
    assert exit_code != 0 and manifest["coverage_gate"]["passed"] is False
    assert covered * 100 < valid * 90
    if covered == 899999:
        assert manifest["line_coverage_percent"] == 90.0  # Display may round, gate may not.


@pytest.mark.parametrize("case", ["missing", "malformed", "wrong_root"])
def test_g04_missing_or_malformed_xml_is_fail_closed(fake_suite, case):
    execute, _ = fake_suite
    code, manifest, directory = execute(xml=case)
    assert code != 0 and manifest["result"] == "FAIL"
    assert manifest["coverage_gate"]["passed"] is False
    assert manifest["line_coverage_percent"] is None
    assert manifest["coverage_note"]
    assert (directory / "run.json").is_file() and (directory / "summary.txt").is_file()


@pytest.mark.parametrize("covered,valid", [(0, 0), (12, -1), (-1, 100), (101, 100), (12, 0)])
def test_g04_invalid_integer_bounds_fail_closed(fake_suite, covered, valid):
    code, manifest, _ = fake_suite[0](covered=covered, valid=valid)
    assert code != 0 and manifest["coverage_gate"]["passed"] is False
    assert manifest["line_coverage_percent"] is None


def test_g04_unparseable_noninteger_counts_fail_closed(fake_suite):
    code, manifest, _ = fake_suite[0](covered="nope", valid=100)
    assert code != 0 and "malformed" in manifest["coverage_gate"]["reason"]


def test_g05_failing_pytest_does_not_pass_even_with_full_coverage(fake_suite):
    execute, _ = fake_suite
    code, manifest, directory = execute(covered=100, valid=100, pytest_exit=1)
    assert code == 1 and manifest["pytest_exit_code"] == 1
    assert manifest["runner_exit_code"] == 1 and manifest["result"] == "FAIL"
    assert manifest["coverage_gate"]["passed"] is True
    assert manifest["counts"]["failed"] == 1
    assert "pytest exited with code 1" in manifest["failure_reasons"]
    assert (directory / "junit.xml").is_file()


def test_g04_junit_missing_or_malformed_cannot_claim_runner_pass(fake_suite):
    for case in ("missing", "malformed"):
        code, manifest, _ = fake_suite[0](junit=case, covered=100, valid=100)
        assert code != 0 and manifest["result"] == "FAIL"
        assert "JUnit report missing, invalid, empty or has failures" in manifest["failure_reasons"]


def test_g06_source_and_exclusions_are_unchanged():
    project = Path(__file__).resolve().parents[2]
    pyproject = tomllib.loads((project / "pyproject.toml").read_text(encoding="utf-8"))
    coverage = pyproject["tool"]["coverage"]["run"]
    assert coverage["source"] == ["aidm"]
    assert coverage["omit"] == ["*/test/*", "*/conftest.py", "*/test_runner.py"]
    assert "pytest-cov==7.0.0" in (project / "requirements-dev.txt").read_text(encoding="utf-8")


def test_g07_exact_sha_build_metadata_and_junit_identity_are_preserved(fake_suite):
    execute, state = fake_suite
    code, manifest, directory = execute(covered=90, valid=100)
    assert code == 0
    assert manifest["source_revision"] == "a" * 40
    assert manifest["git_worktree_dirty"] is False
    assert manifest["build_identity"]["source_sha"] == "a" * 40
    assert manifest["build_identity"]["version"] == "0.1.0"
    assert manifest["build_identity"]["build_id"] == "dev-aaaaaaaaaaaa"
    assert manifest["run_id"] and manifest["started_at"].endswith("+00:00")
    assert manifest["counts"]["passed"] == 2 and manifest["counts"]["total"] == 2
    root = ElementTree.parse(directory / "junit.xml").getroot()
    props = {p.get("name"):p.get("value") for p in root.findall("properties/property")}
    assert props["aidm.source_sha"] == "a" * 40
    assert props["aidm.version"] == "0.1.0"
    assert state["calls"][0][0].count("--cov-fail-under=90") == 1


def test_g11_success_failure_and_success_preserve_three_distinct_receipts(fake_suite):
    execute, state = fake_suite
    first = execute(covered=91, valid=100)
    second = execute(covered=89, valid=100)
    third = execute(covered=95, valid=100)
    assert [r[0] for r in (first, second, third)] == [0, 1, 0]
    ids = {r[1]["run_id"] for r in (first, second, third)}
    assert len(ids) == 3
    assert len({str(r[2]) for r in (first, second, third)}) == 3
    for _, manifest, directory in (first, second, third):
        assert (directory / "run.json").is_file()
        assert (directory / "pytest-output.txt").is_file()
        assert (directory / "coverage.xml").is_file()
        assert (directory / "junit.xml").is_file()
        assert "Source SHA: " in (directory / "summary.txt").read_text()
    assert len(state["calls"]) == 3


def test_g11_demonstration_marker_only_in_subprocess_environment(fake_suite, monkeypatch):
    execute, state = fake_suite
    monkeypatch.setenv("AIDM_TEST_DEMO_FAILURE", "inherited")
    code, manifest, _ = execute(covered=100, valid=100)
    assert code == 0 and manifest["result"] == "PASS"
    assert "AIDM_TEST_DEMO_FAILURE" not in state["calls"][-1][1]
    code2, manifest2, _ = execute(covered=100, valid=100, pytest_exit=1, demonstrate_failure=True)
    assert code2 != 0 and manifest2["result"] == "FAIL"
    assert state["calls"][-1][1]["AIDM_TEST_DEMO_FAILURE"] == "1"


def test_missing_pytest_executable_preserves_failure_receipt(fake_suite):
    code, manifest, directory = fake_suite[0](raise_spawn=True)
    assert code == 127 and manifest["result"] == "FAIL"
    assert manifest["pytest_exit_code"] == 127
    assert manifest["coverage_gate"]["passed"] is False
    assert "could not execute" in (directory / "pytest-output.txt").read_text()


def test_g12_browser_js_not_tested_not_inflated_into_python_coverage(fake_suite):
    code, manifest, directory = fake_suite[0](covered=90, valid=100)
    assert code == 0
    assert manifest["browser_js"]["status"] == "NOT_TESTED"
    assert "DES-014.1" in manifest["browser_js"]["reason"]
    assert "JavaScript/browser: NOT_TESTED" in (directory / "summary.txt").read_text()
    assert manifest["line_coverage_percent"] == 90


def test_exact_xml_compatibility_helper_uses_raw_counts(tmp_path):
    path = tmp_path / "coverage.xml"
    path.write_text('<coverage lines-covered="899999" lines-valid="1000000"/>', encoding="utf-8")
    displayed, problem = runner._coverage_percent(path)
    assert problem is None and displayed == 90.0
    assert runner._coverage_gate(path)["passed"] is False