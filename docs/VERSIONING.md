# AIDM — Version and Runtime Build Identity

**Story:** AIDM-DES-030.1  
**Authority:** Golden Braid Engineering Standards §8  
**Developer:** COSTA  
**Status:** Implementation prepared; root VERSION is gated on Project Owner/ALEK approval of the Sprint 1 release target  
**Change Log:** 2026-11-18 COSTA — first source/build-identity implementation.

## 1. Why VERSION is not yet in this PR

The currently approved Sprint Plan - 1.2 Transition (v1.3) says the proposed Sprint 1 application version is `v0.1.0`, **pending explicit approval**. Do not seed a root VERSION until ALEK records approval of that target in the Sprint Plan. The value `0.1.0` appears in synthetic tests only; it is not a release decision. When approved, commit a root file named `VERSION` containing **only** the approved `MAJOR.MINOR.PATCH` value (without leading `v`), followed by a newline. No secondary runtime version constant is permitted.

Missing or malformed VERSION causes `read_version()` to raise `VersionError` with a value-free message. A runnable developer identity may report `version=UNKNOWN` rather than claiming a version prematurely. A Git checkout still exposes its exact full SHA if Git is available.

## 2. Runtime public API

```python
from aidm.versioning import get_build_identity, diagnostics, startup_banner

identity = get_build_identity()
print(startup_banner(identity))
print(diagnostics())  # version, full source_sha, type, build ID/time, dirty
```

The future Meta Service (AIDM-DES-013) must print `startup_banner()` during startup, expose the same `diagnostics()` contract through its status API and pass the identity to the browser About/status view (AIDM-DES-014) when those surfaces exist. This Story does **not** create the runtime or browser.

The immediately available CLI is:

```powershell
python -m aidm --version
python -m aidm
```

`python -m aidm` prints the banner and explicitly says that the Meta Service is not implemented; it does **not** launch a game.

## 3. Identity precedence and truthfulness

- In a Git checkout, read the root VERSION if valid, inspect the **full** 40/64-character Git SHA and dirty status, and set `build_type=development`. Even when VERSION matches a planned release, a developer checkout is **never** labelled an official release.
- In a packaged distribution **without `.git`**, read generated `aidm/_build_manifest.json` (schema 1) for the VERSION, full SHA, build type, unique build ID, UTC timestamp and clean flag. A matching root VERSION is required when that file is present. Invalid or contradictory manifests are ignored, not trusted.
- Without sufficient metadata, show `UNKNOWN` instead of manufacturing an identifier or release state. If Git is unavailable but `.git` exists, the checkout cannot assume a packaged release label.
- No release tag, GitHub Release or Sprint closure is produced by this Story.

## 4. Generated manifest, never committed

A development packaging helper is available after VERSION approval and a final, **clean** source commit:

```powershell
python -m aidm.versioning --generate-development-manifest
```

This refuses dirty or missing-Git worktrees, refuses an absent/invalid VERSION, and writes one immutable `aidm/_build_manifest.json` containing the **final** full SHA. The file is Git-ignored and must be included in a distribution package but never committed to the source tree. Re-running while the file exists raises an error rather than silently overwriting. Build IDs and UTC build times are generated, not hard-coded. A distributable package need not have Git installed to read it.

**Release qualification and tag publishing** belong to **AIDM-DES-030.2**. Its controlled process must verify the approved Sprint target, accepted main SHA, test/UAT and CI evidence before issuing a `release` manifest, `vX.Y.Z` tag or GitHub Release. The packaging helper in this first increment deliberately creates only `development` manifests. A synthetic `release` manifest is used in offline tests to verify the read-only runtime contract, **not** as authority to publish.

## 5. Technical logs and test reports

Every log record emitted through `aidm.logging.log` receives `version`, **full** `source_sha`, `build_id`, `release_kind`, `build_timestamp`, and `dirty` through the central identity provider, with `UNKNOWN` wherever unavailable. The human-readable line remains ISO-8601 → severity emoji → caller → message. To opt into machine-readable JSONL alongside the rotating human log:

```python
from aidm.logging import configure_logging, log
configure_logging(json_path="logs/technical.jsonl")
log.info("Safe startup notice")
```

Each JSONL line includes `version`, `source_sha`, `build_type`, `build_id`, `build_timestamp`, and `dirty`, plus correlation/caller and severity metadata. Logs stay Git-ignored. Do not put secrets, raw exception messages or player-hidden content into the log message. Current implementation is single-process; cross-process rotation remains AIDM-DES-035 integration scope.

The standard `python -m aidm.test_runner` produces `reports/test-runs/<run-id>/run.json` containing the same central `build_identity` fields. It also stamps every generated JUnit `<testsuite>` with full `aidm.*` identity properties, including failure reports, and prints the identity in `summary.txt`. Reports remain Git-ignored and uniquely identified. Python unit tests mock Git and use synthetic manifests; no live APIs or credentials are used.

## 6. Integration and limitations

Implementation is an **increment**, not the whole release mechanism. AIDM-DES-030.2 owns release approval/tag/manifest designation; AIDM-DES-013 owns actual service startup and diagnostic endpoint; AIDM-DES-014 owns the future browser view; AIDM-DES-035 owns log format/routing; AIDM-DES-027.1 owns CI. Acceptance criterion requiring a seeded root VERSION cannot be satisfied until the Sprint release target is approved. Document that blocker in Airtable; do not mark this Story Complete prematurely.