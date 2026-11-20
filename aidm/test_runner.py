"""AIDM's one-command, fail-closed fast test and coverage runner.

Purpose: Preserve unique PASS/FAIL reports, exact build identity and >=90% gate.
Usage: python -m aidm.test_runner [--demonstrate-failure]
Change Log: 2026-11-17 COSTA — AIDM-DES-028.1 initial reporter.
            2026-11-18 COSTA — AIDM-DES-030.1 build identity.
            2026-11-20 COSTA — AIDM-DES-028.3 exact 90% Python coverage gate.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from uuid import uuid4
from xml.etree import ElementTree

from .versioning import BuildIdentity, get_build_identity


MIN_PYTHON_LINE_COVERAGE_PERCENT = 90


def _stamp_junit(path: Path, identity: BuildIdentity) -> None:
    """Add source/build provenance to each generated JUnit suite, including failures."""
    if not path.is_file():
        return
    try:
        tree = ElementTree.parse(path)
        root = tree.getroot()
        suites = [root] if root.tag == "testsuite" else list(root.findall("testsuite"))
        for suite in suites:
            properties = suite.find("properties")
            if properties is None:
                properties = ElementTree.Element("properties")
                suite.insert(0, properties)
            for key, value in identity.as_dict().items():
                ElementTree.SubElement(
                    properties, "property", name="aidm." + key,
                    value="UNKNOWN" if value is None else str(value),
                )
        tree.write(path, encoding="utf-8", xml_declaration=True)
    except (ValueError, OSError, ElementTree.ParseError):
        # Report is retained; downstream integrity gate will reject invalid JUnit.
        return


def _junit_counts(path: Path) -> dict[str, int | float | None]:
    result: dict[str, int | float | None] = {
        "passed": None, "failed": None, "skipped": None,
        "errors": None, "total": None, "junit_duration_seconds": None,
    }
    if not path.is_file():
        return result
    try:
        root = ElementTree.parse(path).getroot()
        suites = [root] if root.tag == "testsuite" else list(root.findall("testsuite"))
        if not suites:
            return result
        total = sum(int(s.get("tests", "-1")) for s in suites)
        failed = sum(int(s.get("failures", "-1")) for s in suites)
        skipped = sum(int(s.get("skipped", "-1")) for s in suites)
        errors = sum(int(s.get("errors", "-1")) for s in suites)
        duration = sum(float(s.get("time", "0")) for s in suites)
        if (total < 0 or any(v < 0 for v in (failed, skipped, errors))
                or failed + skipped + errors > total):
            return result
        result.update(
            total=total, failed=failed, skipped=skipped, errors=errors,
            passed=total - failed - skipped - errors,
            junit_duration_seconds=round(duration, 3),
        )
    except (ValueError, ElementTree.ParseError, OSError):
        pass
    return result


def _coverage_counts(path: Path) -> tuple[int | None, int | None, str | None]:
    """Read genuine coverage XML integer counts; never substitute a rounded rate."""
    if not path.is_file():
        return None, None, "coverage.xml was not generated"
    try:
        root = ElementTree.parse(path).getroot()
        if root.tag != "coverage":
            return None, None, "coverage.xml has unexpected root element"
        covered = int(root.attrib["lines-covered"])
        valid = int(root.attrib["lines-valid"])
        if valid <= 0:
            return None, None, "No executable application lines were measured"
        if covered < 0 or covered > valid:
            return None, None, "coverage.xml has invalid covered/valid line counts"
        return covered, valid, None
    except (ValueError, KeyError, ElementTree.ParseError, OSError, OverflowError):
        return None, None, "coverage.xml is malformed or could not be parsed"


def _coverage_percent(path: Path) -> tuple[float | None, str | None]:
    """Backwards-compatible display helper, not the source of the gate result."""
    covered, valid, problem = _coverage_counts(path)
    if problem is not None:
        return None, problem
    assert covered is not None and valid is not None
    return round(100 * covered / valid, 2), None


def _coverage_gate(path: Path) -> dict[str, int | float | bool | str | None]:
    """Validate XML and compare exact integers, avoiding 89.999% -> 90.00 rounding."""
    covered, valid, problem = _coverage_counts(path)
    if problem is not None:
        return {
            "passed": False, "threshold_percent": MIN_PYTHON_LINE_COVERAGE_PERCENT,
            "covered_lines": None, "valid_lines": None, "percent": None,
            "reason": problem,
        }
    assert covered is not None and valid is not None
    exact_pass = covered * 100 >= valid * MIN_PYTHON_LINE_COVERAGE_PERCENT
    return {
        "passed": exact_pass,
        "threshold_percent": MIN_PYTHON_LINE_COVERAGE_PERCENT,
        "covered_lines": covered,
        "valid_lines": valid,
        "percent": round(100 * covered / valid, 2),
        "reason": (
            "Measured coverage meets the exact 90.00% threshold"
            if exact_pass else "Measured coverage is below the exact 90.00% threshold"
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="AIDM fast tests with enforced 90% application coverage")
    parser.add_argument(
        "--demonstrate-failure", action="store_true",
        help="Intentionally fail a synthetic assertion to verify nonzero status and retained diagnostics",
    )
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    started = datetime.now(timezone.utc)
    run_id = started.strftime("%Y%m%dT%H%M%S%fZ") + "-" + uuid4().hex[:8]
    report_dir = root / "reports" / "test-runs" / run_id
    report_dir.mkdir(parents=True, exist_ok=False)
    identity = get_build_identity(root)
    source_sha, dirty = identity.source_sha, identity.dirty
    cmd = [
        sys.executable, "-m", "pytest", "aidm", "-q",
        "--junitxml", str(report_dir / "junit.xml"),
        "--cov=aidm", "--cov-fail-under=90", "--cov-report=term-missing",
        "--cov-report=xml:" + str(report_dir / "coverage.xml"),
        "--cov-report=html:" + str(report_dir / "htmlcov"),
    ]
    env = os.environ.copy()
    env["COVERAGE_FILE"] = str(report_dir / ".coverage")
    if args.demonstrate_failure:
        env["AIDM_TEST_DEMO_FAILURE"] = "1"
    else:
        env.pop("AIDM_TEST_DEMO_FAILURE", None)
    started_mono = time.monotonic()
    try:
        completed = subprocess.run(
            cmd, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", check=False,
        )
        pytest_exit_code, output = completed.returncode, completed.stdout
    except OSError as exc:
        pytest_exit_code = 127
        output = f"Test runner could not execute Python/pytest: {type(exc).__name__}"
    elapsed = round(time.monotonic() - started_mono, 3)
    finished = datetime.now(timezone.utc)
    (report_dir / "pytest-output.txt").write_text(output, encoding="utf-8")
    _stamp_junit(report_dir / "junit.xml", identity)
    counts = _junit_counts(report_dir / "junit.xml")
    coverage_gate = _coverage_gate(report_dir / "coverage.xml")
    coverage = coverage_gate["percent"]
    coverage_problem = None if coverage_gate["covered_lines"] is not None else str(coverage_gate["reason"])
    junit_ok = (counts["total"] is not None and counts["total"] > 0
                and counts["failed"] == 0 and counts["errors"] == 0)
    passed = pytest_exit_code == 0 and bool(coverage_gate["passed"]) and junit_ok
    runner_exit_code = 0 if passed else (pytest_exit_code or 1)
    failures = []
    if pytest_exit_code != 0:
        failures.append(f"pytest exited with code {pytest_exit_code}")
    if not coverage_gate["passed"]:
        failures.append(str(coverage_gate["reason"]))
    if not junit_ok:
        failures.append("JUnit report missing, invalid, empty or has failures")
    manifest = {
        "run_id": run_id,
        "started_at": started.isoformat(),
        "finished_at": finished.isoformat(),
        "duration_seconds": elapsed,
        "source_revision": source_sha,
        "build_identity": identity.as_dict(),
        "git_worktree_dirty": dirty,
        "python": sys.version.split()[0],
        "command": "python -m aidm.test_runner" + (" --demonstrate-failure" if args.demonstrate_failure else ""),
        "result": "PASS" if passed else "FAIL",
        "pytest_exit_code": pytest_exit_code,
        "runner_exit_code": runner_exit_code,
        "failure_reasons": failures,
        "counts": counts,
        "count_source": "JUnit test-suite totals (includes unittest subtests)",
        "line_coverage_percent": coverage,
        "line_coverage_covered": coverage_gate["covered_lines"],
        "line_coverage_valid": coverage_gate["valid_lines"],
        "coverage_note": coverage_problem,
        "coverage_gate": coverage_gate,
        "browser_js": {
            "status": "NOT_TESTED",
            "reason": "JavaScript/browser smoke tests are tracked separately under DES-014.1/025.2",
        },
        "reports": {
            "junit_xml": "junit.xml" if (report_dir / "junit.xml").exists() else None,
            "coverage_xml": "coverage.xml" if (report_dir / "coverage.xml").exists() else None,
            "coverage_html": "htmlcov/index.html" if (report_dir / "htmlcov/index.html").exists() else None,
            "test_output": "pytest-output.txt",
            "summary": "summary.txt",
        },
    }
    (report_dir / "run.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8",
    )
    summary = (
        f"Run: {run_id}\n"
        f"Result: {manifest['result']} (pytest exit code {pytest_exit_code}; runner exit code {runner_exit_code})\n"
        f"Started UTC: {manifest['started_at']}\n"
        f"Duration: {elapsed:.3f}s\n"
        f"Source SHA: {source_sha}\n"
        f"Version: {identity.version} | build type: {identity.build_type} | "
        f"build ID: {identity.build_id} | timestamp: {identity.build_timestamp}\n"
        f"Git working tree dirty: {dirty}\n"
        f"JUnit outcomes (including subtests): {counts['passed']} passed, {counts['failed']} failed, "
        f"{counts['skipped']} skipped, {counts['errors']} errors\n"
        f"Line coverage: {str(coverage) + '%' if coverage is not None else 'UNKNOWN'} "
        f"(covered {coverage_gate['covered_lines']} / valid {coverage_gate['valid_lines']})\n"
        f"Coverage gate >= {MIN_PYTHON_LINE_COVERAGE_PERCENT:.2f}%: "
        f"{'PASS' if coverage_gate['passed'] else 'FAIL'} — {coverage_gate['reason']}\n"
        f"Coverage note: {coverage_problem or 'measured'}\n"
        f"JavaScript/browser: NOT_TESTED (separate DES-014.1/025.2)\n"
        f"Failure reasons: {'; '.join(failures) if failures else 'none'}\n"
        f"Reports: {report_dir}\n"
    )
    (report_dir / "summary.txt").write_text(summary, encoding="utf-8")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    print("\n" + summary, flush=True)
    return runner_exit_code


if __name__ == "__main__":
    sys.exit(main())