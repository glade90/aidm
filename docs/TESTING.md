# AIDM Automated Test Runner — AIDM-DES-028.1 and AIDM-DES-028.3

**Owner:** COSTA  
**Engineering authority:** Golden Braid Engineering Standards §6  
**Updated:** 20 November 2026  
**Scope:** offline pytest, retained source-identified reports and Sprint 2's exact Python ≥90% coverage gate. GitHub Actions integration remains DES-027.1.

## 1. Installation and Python support

Run from the repository root using Python **3.11 or newer**, preferably from an isolated virtual environment.

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
```

Top-level development dependencies are exactly version-pinned; transitive dependencies are resolved by pip at installation. No app version is selected by this Story. Standard tests require no LLM key or internet access after installation.

## 2. Standard command (entire fast unit suite)

```powershell
python -m aidm.test_runner
```

The runner executes `python -m pytest aidm` with discovery defined in `pyproject.toml`. It runs all `test_*.py` files in colocated `test/` directories beneath `aidm/`. For example, an eventual `aidm/combat/engine.py` should have `aidm/combat/test/test_engine.py`. Tests use regular package imports, without sys.path hacks. The existing `unittest.TestCase` tests in `aidm/test/test_config.py` run under pytest too.

Each invocation creates a **new** ignored directory `reports/test-runs/<UTC-unique-id>/` containing:

- `summary.txt`: human-readable PASS/FAIL, duration, run ID, exact source SHA when run from Git, dirty-worktree flag, JUnit case counts (including unittest subtests) and line coverage
- `run.json`: machine-readable manifest with the same data, coverage availability and relative report paths
- `pytest-output.txt`: complete pytest output, including failure information
- `junit.xml`: machine-readable test results including failed assertions, when pytest can generate it
- `coverage.xml`: machine-readable application line coverage, when measurement succeeds
- `htmlcov/index.html`: browsable coverage details, when generated

Coverage excludes test fixtures and the test runner itself; it measures application code. A missing tool/report is explicitly marked UNKNOWN rather than falsely reporting zero coverage. All reports live locally and are Git-ignored. Record report locations, run IDs and observed results in Airtable at Story handoff; reports are not automatically uploaded.

## 2.1 Sprint 2 measured Python coverage gate — DES-028.3

The standard runner now enforces **at least 90.00% measured Python application line coverage**; it is not merely a printed target. It passes `--cov-fail-under=90` to pinned `pytest-cov==7.0.0`, then **independently** parses the `lines-covered` and `lines-valid` integers from `coverage.xml`. The exact comparison is:

```text
covered_lines * 100 >= valid_lines * 90
```

The runner rejects a measured **89.9999%** even if the displayed percentage rounds to **90.00%**. Missing, malformed, out-of-bounds or zero-denominator coverage XML **fails closed** with a nonzero runner exit code and an explanatory failure reason. A failing pytest run or missing/invalid JUnit report also fails regardless of coverage percentage. There is **no** override to skip the gate or silently treat missing measurements as passing.

The existing `pyproject.toml` coverage scope remains unchanged: `[tool.coverage.run] source = ["aidm"]` and `omit = ["*/test/*", "*/conftest.py", "*/test_runner.py"]`. Production Python modules are **not** excluded to raise measured coverage. Test and reporting code is excluded according to the pre-existing baseline; external `braider` is not claimed as included. Do not interpret 90% as proof of Mentzer rules correctness or successful browser tests.

Every run still creates a unique timestamped directory, including failures. Alongside previous fields, `run.json` now records `runner_exit_code` separately from `pytest_exit_code`, `failure_reasons`, `line_coverage_covered`, `line_coverage_valid` and the `coverage_gate` object (`passed`, `threshold_percent`, measured counts, displayed percent, reason). `summary.txt` prints the same precise numerator/denominator and gate result. The existing full Git SHA, clean/dirty source status, build/version metadata, JUnit results and XML/HTML locations remain available.

To check the exit code on Windows PowerShell:

```powershell
python -m aidm.test_runner
$LASTEXITCODE
```

**Python versus browser:** `run.json.browser_js.status` is `NOT_TESTED` unless a separately scoped browser suite has actually executed. Browser JavaScript and future DAVOS smoke tests are tracked independently under DES-014.1/DES-025.2; they are not invented as Python outcomes or silently included in the Python denominator. There is no GitHub Actions CI execution until DES-027.1 delivers it.

**Contract tests:** `aidm/test/test_coverage_gate.py` checks G01–G07 and G11–G12 using isolated mocked pytest subprocesses and real temporary XML/JSON receipts. Existing `aidm/meta/test/test_turn.py` and `test_http.py` cover the injected fake `/api/turn` positive, malformed JSON, missing DM, rejection, exception, timeout and multi-session behavior (G08–G09); `aidm/combat/test/test_dice.py` covers raw selected die identity, deterministic fixed queue and invalid source (G10). No real LLM, API key, network or database is required.

## 3. Intentional failure verification

For a controlled **negative** test, run:

```powershell
python -m aidm.test_runner --demonstrate-failure
```

The runner passes a synthetic marker **only to this subprocess** and triggers one clearly labelled deliberately incorrect assertion in the example tests. Expect a nonzero exit status and a **new** report directory with `junit.xml` failure details. This is an opt-in report-system test, not a production combat rule or test failure to merge. Then run the normal command again and verify PASS with a third unique run ID and no overwritten files.

If installing dev dependencies fails, fix the environment before calling the change tested. The runner should still create a manifest and summary if it cannot launch pytest, but JUnit/coverage may be unavailable.

## 4. Fixtures, CI and responsibilities

A reusable `scripted_die` pytest fixture lives in `aidm/test/conftest.py` and is injected into the adjacent example tests. It supplies known roll outcomes, without implementing any D&D mechanics. Share fixtures higher in the tree only after multiple colocated modules need them.

No real LLM, network request, database, credential or random source is required for these tests. GitHub Actions will invoke the same command and retain artifacts under DES-027.1. Sprint 2 requires the exact ≥90.00% Python line-coverage gate described above; failed runs remain valid retained development evidence but must not be integrated into `main` as passing work. The repository's existing `.gitignore` ignores `reports/` and pytest/coverage outputs.

**Change history:** 2026-11-17 COSTA — Initial runner, deterministic fixture and retained reports. 2026-11-20 COSTA — DES-028.3 enforce exact Python 90% gate with missing-measurement rejection, preserved receipts and explicit browser status.