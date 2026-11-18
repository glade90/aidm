"""AIDM's one-command, durable fast-unit-test runner.

Purpose: Run pytest with coverage and preserve distinct PASS/FAIL reports.
Usage: python -m aidm.test_runner [--demonstrate-failure]
Change Log: 2026-11-17 COSTA — AIDM-DES-028.1 initial reporter.
            2026-11-18 COSTA — AIDM-DES-030.1 build identity in reports.
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
                ElementTree.SubElement(properties, "property", name="aidm." + key,
                                       value="UNKNOWN" if value is None else str(value))
        tree.write(path, encoding="utf-8", xml_declaration=True)
    except (ValueError, OSError, ElementTree.ParseError):
        # The existing report will still be preserved; summary/run.json remain.
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
        total = sum(int(s.get("tests", "0")) for s in suites)
        failed = sum(int(s.get("failures", "0")) for s in suites)
        skipped = sum(int(s.get("skipped", "0")) for s in suites)
        errors = sum(int(s.get("errors", "0")) for s in suites)
        duration = sum(float(s.get("time", "0")) for s in suites)
        result.update(
            total=total, failed=failed, skipped=skipped, errors=errors,
            passed=max(0, total - failed - skipped - errors),
            junit_duration_seconds=round(duration, 3),
        )
    except (ValueError, ElementTree.ParseError, OSError):
        pass  # Preserve incomplete report and label counts as UNKNOWN.
    return result


def _coverage_percent(path: Path) -> tuple[float | None, str | None]:
    if not path.is_file():
        return None, "coverage.xml was not generated"
    try:
        root = ElementTree.parse(path).getroot()
        covered = int(root.attrib["lines-covered"])
        valid = int(root.attrib["lines-valid"])
        return (round(100 * covered / valid, 2) if valid else None), (
            None if valid else "No executable application lines were measured"
        )
    except (ValueError, KeyError, ElementTree.ParseError, OSError):
        return None, "coverage.xml could not be parsed"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="AIDM fast tests with retained, unique reports")
    parser.add_argument(
        "--demonstrate-failure", action="store_true",
        help="Intentionally fail one example assertion to verify nonzero status and JUnit diagnostics",
    )
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    started = datetime.now(timezone.utc)
    # UTC microseconds plus a random suffix means parallel/repeated runs cannot overwrite reports.
    run_id = started.strftime("%Y%m%dT%H%M%S%fZ") + "-" + uuid4().hex[:8]
    report_dir = root / "reports" / "test-runs" / run_id
    report_dir.mkdir(parents=True, exist_ok=False)
    identity = get_build_identity(root)
    source_sha, dirty = identity.source_sha, identity.dirty
    cmd = [
        sys.executable, "-m", "pytest", "aidm", "-q",
        "--junitxml", str(report_dir / "junit.xml"),
        "--cov=aidm", "--cov-report=term-missing",
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
        exit_code, output = completed.returncode, completed.stdout
    except OSError as exc:
        exit_code = 127
        output = f"Test runner could not execute Python/pytest: {type(exc).__name__}"
    elapsed = round(time.monotonic() - started_mono, 3)
    finished = datetime.now(timezone.utc)
    (report_dir / "pytest-output.txt").write_text(output, encoding="utf-8")
    _stamp_junit(report_dir / "junit.xml", identity)
    counts = _junit_counts(report_dir / "junit.xml")
    coverage, coverage_problem = _coverage_percent(report_dir / "coverage.xml")
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
        "result": "PASS" if exit_code == 0 else "FAIL",
        "pytest_exit_code": exit_code,
        "counts": counts,
        "count_source": "JUnit test-suite totals (includes unittest subtests)",
        "line_coverage_percent": coverage,
        "coverage_note": coverage_problem,
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
        f"Result: {manifest['result']} (pytest exit code {exit_code})\n"
        f"Started UTC: {manifest['started_at']}\n"
        f"Duration: {elapsed:.3f}s\n"
        f"Source SHA: {source_sha}\n"
        f"Version: {identity.version} | build type: {identity.build_type} | "
        f"build ID: {identity.build_id} | timestamp: {identity.build_timestamp}\n"
        f"Git working tree dirty: {dirty}\n"
        f"JUnit outcomes (including subtests): {counts['passed']} passed, {counts['failed']} failed, "
        f"{counts['skipped']} skipped, {counts['errors']} errors\n"
        f"Line coverage: {str(coverage) + '%' if coverage is not None else 'UNKNOWN'}\n"
        f"Coverage note: {coverage_problem or 'measured'}\n"
        f"Reports: {report_dir}\n"
    )
    (report_dir / "summary.txt").write_text(summary, encoding="utf-8")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    print("\n" + summary, flush=True)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())