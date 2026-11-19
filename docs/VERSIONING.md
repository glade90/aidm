# AIDM — Version and Runtime Build Identity

**Story:** AIDM-DES-030.1  
**Authority:** Golden Braid Engineering Standards §8  
**Developer:** COSTA  
**Status:** Sprint 1 application release target v0.1.0 approved by Project Owner 18 November 2026; root VERSION seeded. This is not a published release.  
**Change Log:** 2026-11-18 COSTA — first source/build-identity implementation.

## 1. Authoritative VERSION — Sprint 1 target approved

On **18 November 2026**, the Project Owner explicitly approved **v0.1.0** as the Sprint 1 application release target. ALEK's Sprint Plan - 1.2 Transition v1.3 now has an approval addendum preserving that decision. The repository root `VERSION` is seeded to **`0.1.0`** (without a leading v); it is the **only** hand-maintained declared application version.

Version approval **does not** mean Sprint 1 is released. A developer checkout remains `development` even if VERSION declares the approved target. Release verification, tagged release publication and Sprint closure are governed by **AIDM-DES-030.2** and **PLAN-010**. No tag or GitHub Release has been created in this Story.

Missing or malformed VERSION causes `read_version()` to raise a value-safe `VersionError`; absent version metadata cannot be silently converted into a released version. A Git checkout still exposes its full SHA when Git is available.

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

A development packaging helper is available after the accepted final, **clean** source commit:

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

Implementation is an **increment**, not the whole release mechanism. AIDM-DES-030.2 owns release approval/tag/manifest designation; AIDM-DES-013 owns actual service startup and diagnostic endpoint; AIDM-DES-014 owns the future browser view; AIDM-DES-035 owns log format/routing; AIDM-DES-027.1 owns CI. The root VERSION prerequisite is now satisfied by explicit Project Owner approval. Before marking the Technical Story Complete, rerun the full test suite against the exact committed revision and record verifiable results in Airtable. Release publication remains separate under DES-030.2.