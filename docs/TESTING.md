# AIDM Automated Test Runner — AIDM-DES-028.1

**Owner:** COSTA  
**Engineering authority:** Golden Braid Engineering Standards §6  
**Updated:** 17 November 2026  
**Scope:** fast, offline pytest unit tests and retained developer reports; GitHub Actions integration is DES-027.1.

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

## 3. Intentional failure verification

For a controlled **negative** test, run:

```powershell
python -m aidm.test_runner --demonstrate-failure
```

The runner passes a synthetic marker **only to this subprocess** and triggers one clearly labelled deliberately incorrect assertion in the example tests. Expect a nonzero exit status and a **new** report directory with `junit.xml` failure details. This is an opt-in report-system test, not a production combat rule or test failure to merge. Then run the normal command again and verify PASS with a third unique run ID and no overwritten files.

If installing dev dependencies fails, fix the environment before calling the change tested. The runner should still create a manifest and summary if it cannot launch pytest, but JUnit/coverage may be unavailable.

## 4. Fixtures, CI and responsibilities

A reusable `scripted_die` pytest fixture lives in `aidm/test/conftest.py` and is injected into the adjacent example tests. It supplies known roll outcomes, without implementing any D&D mechanics. Share fixtures higher in the tree only after multiple colocated modules need them.

No real LLM, network request, database, credential or random source is required for these tests. GitHub Actions will invoke the same command and retain artifacts under DES-027.1. No minimum coverage gate is imposed yet; failed runs are valid development evidence but must not be integrated into `main` as passing work. The repository's existing `.gitignore` ignores `reports/` and pytest/coverage outputs.

**Change history:** 2026-11-17 COSTA — Initial standard runner, deterministic fixture, failure demonstration and result format.