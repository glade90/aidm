# AI Dungeon Master

![Adventuring party confronting stirges in a purple-lit cavern](assets/images/expedition_13_B1_partyFacesStirgesInThePurpleCorridor.png)

AIDM is the AI Dungeon Master project part of the **The Golden Braid**, Eric Kasper's personal journey through Agentic Engineering. The planned application combines a single player-facing conversational LLM Dungeon Master with Python orchestrators and authoritative deterministic services. It targets **1983 Mentzer Basic D&D** and explicit approved house rules, without inventing additional game mechanics.

The architectural direction includes a persistent runtime, browser interface, conversational DM, and orchestrators for adventure, expedition, character creation, geometry, rules, bookkeeping, encounters, combat, and cartography. Rules, dice, geometry and game-state changes are validated by tools and services—not made authoritative by LLM narration. Framework selection remains open.

This repository is an evolving **engineering foundation**, not yet a playable game. A local Meta Service and mocked player-turn HTTP demonstration exist, but there is no real DM, combat execution, authoritative game state, CI or controlled release publication.

## Branch workflow

- `main` — stable, accepted integration baseline.
- `costa`, `davos`, `ester` — persistent developer branches, **not** feature or release branches.
- Developers normally integrate one completed Developer Story at a time. Pull requests target `main`, include the Airtable JiraID and verification evidence, and are reviewed before squash merge.
- After integration, synchronise the developer branch to the accepted `main` baseline before starting the next Story. Do not rewrite accepted `main` history or force-push it.

## Commit convention

Use `type(scope): description` (e.g. `test(repo): AIDM-DES-028.1 add pytest smoke checks`). Include the Airtable JiraID in the commit message **or** associated pull request. Preferred types: `feat`, `fix`, `test`, `docs`, `refactor`, `chore`.

## Security and content

Never commit passwords, API keys, `.env` files, private keys, or confidential or restricted content. The committed `.env.example` documents placeholder settings only, never working credentials. The B1 module, rulebook material and other potentially copyrighted content must not be redistributed without permission. See `.gitignore` for local artefact exclusions.

## Local configuration

AIDM uses a single, offline Python settings loader: `from aidm.config import load_config`. For local development, copy `.env.example` to `.env` (optional); a setting already present in the process environment **always overrides** its `.env` value. Test, CI and production modes never read developer `.env` files. Do not commit keys or credentials.

Run the isolated configuration tests from the repository root:

```powershell
python -m unittest discover -s aidm/test -p 'test_*.py' -v
```

See [Configuration and secure settings](docs/CONFIGURATION.md) for Windows setup, supported keys, protected CI/deployment injection, error redaction, and integrating the loader with the future Meta Service (`AIDM-DES-013`). If any credential is exposed, revoke/rotate it immediately.

## Automated tests

Install the pinned development dependencies with `python -m pip install -r requirements-dev.txt`, then run the complete offline unit-test suite from the repository root:

```powershell
python -m aidm.test_runner
```

Every execution retains a uniquely identified human-readable summary, JUnit XML and line-coverage reports in the Git-ignored `reports/test-runs/` directory. Run `python -m aidm.test_runner --demonstrate-failure` to verify failure reporting deliberately; follow with a normal passing run. The standard command runs all colocated `test/` directories. See [Testing guide](docs/TESTING.md) for fixtures, results and CI handoff under AIDM-DES-027.1.

## Technical logging

The reusable AIDM logger is available as `from aidm.logging import log, configure_logging`. It writes to the Git-ignored, size-rotating `logs/technical.log` by default, with UTC ISO timestamps, emoji severity, originating class/function and messages. For example:

```python
from aidm.config import load_config
from aidm.logging import configure_logging, log

configure_logging(level=load_config().log_level)
log.info("AIDM runtime configuration loaded")
```

Use `@log.trace_calls` for opt-in method timing, `log.correlation("turn-42")` for cross-event context, and `execute_logged(fake_cursor, "SELECT ... WHERE id=?", (51,))` for the first fake-driver SQL hook. Do **not** log credentials, raw exception messages, raw SQL bind values or hidden game-state data. See [Technical logging guide](docs/LOGGING.md) for rotation, filters, safe integration, tests and intentionally deferred real-database/LLM/replay work (AIDM-DES-035.1).

## Version and build identity

Run `python -m aidm --version` to view the declared application version, **full** Git source SHA, development/release classification, build ID, timestamp and dirty state. `python -m aidm` prints the same startup identity hook, but **does not launch a game**. Start the local Meta Service separately with Uvicorn. The shared status contract is `from aidm.versioning import diagnostics`.

**Governance:** The Project Owner approved Sprint 1's application target **`v0.1.0` on 18 November 2026**, now recorded in the Sprint Plan's approval addendum. The authoritative root [`VERSION`](VERSION) contains **`0.1.0`**, without a leading `v`. This is the planned version—not evidence of a published release. Developer checkouts identify as **development** builds regardless of that target.

An optional build-time helper generates a Git-ignored manifest against the final clean Git commit so packaged code can identify itself without Git. Only the separate controlled release Story **AIDM-DES-030.2** may approve a release build, tag or GitHub Release. The logger's optional structured JSONL and standard test reports consume the same build identity. See [Version and Runtime Build Identity](docs/VERSIONING.md) for usage and remaining approval/integration tasks.

## Meta Service runtime

AIDM-DES-013.1 provides a local single-process FastAPI/Uvicorn Meta Service with explicit dependency injection and lifecycle; there is no real Dungeon Master or live LLM. Run `python -m pip install -r requirements-dev.txt` then `python -m uvicorn aidm.meta.http:create_app --factory --host 127.0.0.1 --port 8000`, inspect `/health`, `/status` and development `/docs`, and use Ctrl+C to stop gracefully. The factory `from aidm.meta.http import create_app` accepts `settings`, `registry`, and `logger` injected dependencies. `from aidm.meta.runtime import ServiceRegistry` supplies `register(name, service)` and `get(name)` for the `POST /api/turn` integration (DES-013.2). See [Meta Service Runtime — Bootstrap & Handoff](docs/META_RUNTIME.md). Only loopback binding is approved for the initial demo.

**Mock player-turn demonstration (DES-013.2):** Run `python -m uvicorn aidm.meta.mock_turn:create_mock_app --factory --host 127.0.0.1 --port 8000`, then open development `/docs` to submit `POST /api/turn` with a JSON `message`. The response is explicitly simulated and never calculates real attack rolls, damage or HP. The default Meta factory leaves `dm` unregistered and its turn endpoint returns a safe 503 until a DM is injected. The HTTP route consumes the existing typed internal message contract without a second server. See [Local player-turn demonstration and tests](docs/PLAYER_TURN.md).

## Generic Braider (Golden Braid-wide)

The standalone top-level `braider/` package provides `Braider`, a small reusable superclass with injected `ModelRuntime`, logical `ModelChoice`, generic `ContextItem`, safe `BraiderOutput`, and an offline `FakeModelRuntime`. It does not import AIDM or CrewAI, execute tools, retrieve context, or claim state changes. It is the approved DES-042.1 foundation for future specialist `CombatAgent(Braider)` (DES-004.1) and DungeonMasterAgent consumers; AIDM translates to/from DES-033.1 request/result types only **at the AIDM consumer boundary**. See [Braider Generic Agent Core](docs/BRAIDER.md).

## Shared internal communication contracts

The framework-neutral in-process contracts in `aidm.internal_messages` define `InternalRequest`, `InternalResult`, `SafeError`, `ErrorCode`, and the six `ResultStatus` outcomes. A child invocation receives its own request ID while preserving its workflow correlation ID. State-changing requests require a command ID and expected world version; event references are absent unless a trusted service supplies actual committed effects. Caller and knowledge-scope fields are **untrusted claims**, not permission grants. The small `safe_call` helper supports injected fake-tool tests without becoming a dispatcher, CrewAI replacement, HTTP server, or Bookkeeper. See [Internal request/result contracts](docs/INTERNAL_MESSAGES.md) (AIDM-DES-033.1). The mock-first FastAPI `/api/turn` integration is implemented under DES-013.2; real routing remains DES-016.

## Programme references

- [Airtable](https://airtable.com/appG1E9VVbXBS7ZB0/pagkLWL3XMiwNHuEl/edit?utm_source=chatgpt.com) is authoritative for Stories, ownership, scope, Test Results and Release Notes.
- OneNote: *Courses → Golden Braid → Engineering Standards*, particularly §4 (GitHub Repository and Commit Strategy).
- Architecture: *Courses → Golden Braid → AIDM - Architecture & Execution*, version 0.3 (12 November 2026), a planning rebaseline, not approved technical design.
- Sprint 1 transition: *Sprint Plan - 1.1 Transition*, baseline v1.2 (17 November 2026).

**Bootstrap story:** `AIDM-DES-026.1` (Technical Build). The approved `VERSION` target is implemented under `AIDM-DES-030.1`; release publication, CI and the application runtime remain separately scoped.
