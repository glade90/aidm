# AI Dungeon Master

![Adventuring party confronting stirges in a purple-lit cavern](assets/images/expedition_13_B1_partyFacesStirgesInThePurpleCorridor.png)

AIDM is an agentic AI engineering project within **The Golden Braid**, Eric Kasper's personal journey through Agentic Engineering. It combines a browser-based conversational Dungeon Master, a model-agnostic Python agent framework, LLM-assisted orchestration, and deterministic, rules-verified game engines. Initial prototypes adapt **1983 Mentzer Basic D&D** and explicit approved house rules. The application is developed through an AI-assisted, multi-role engineering workflow using GitHub-based DevOps, automated regression testing, structured observability, and independent human acceptance testing.

## Mission

AIDM aims to bring the openness of an old-school tabletop campaign to a computer roleplaying game. Traditional deterministic-only games tend to be limited to interactions and paths authored in advance; AI can make play responsive to unexpected choices and let the story evolve at the table. AI does not replace the rules engine: it helps interpret intent, narrate and coordinate, while deterministic, ruleset-aware services resolve mechanics and authoritative game state.

## Status

This repository is an evolving **engineering foundation**, not yet a complete playable game. It includes a local Meta Service, a mocked player-turn demonstration, a thin DM gateway, a working deterministic combat prototype and a populated reference database of monsters, spells, weapons and other game content. The full multi-agent DM and the dungeon-, player- and artwork-generation workflows described above are not yet complete.

## How AI is used

- **Dungeon Master:** The DM narrates adventures and expeditions, coordinate specialist agents such as Combat, Encounter, Bookkeeper, Timekeeper, Referee and NPC agents, and adapt to sandbox exploration. Deterministic services remain authoritative for rules such as combat algorithm and game state.
- **Rules and narrative:** Select a gameplay ruleset and add explicit house rules. For example, Mentzer Basic can govern gameplay while 5e-inspired material adds descriptive color without complicating the gameplay.
- **Dungeon builder:** Offer three modes: upload a PDF module, generate a dungeon with AI assistance, or generate one entirely with AI. The two generation modes are intended to use a pretrained `aidm-x.x` model.
- **Player builder:** Help create characters and generate or assist with their backstories.
- **Artwork generation:** Create illustrations in selectable styles, such as 1980s fantasy, classic inked dungeon maps, painterly high fantasy and parchment-and-ink.
- **Encounters and combat:** AI agents can coordinate ruleset-aware deterministic tools for varied enemies and encounters, supporting large and changing rosters without hand-coding a separate agent for every enemy. Deterministic tools—not AI improvisation—determine legal actions and outcomes.
- **Application development:** A multi-agent `Braider` team supports development in a workflow inspired by the Maestro AI model: ALEK handles programme management, BON focuses on architecture and UAT, and COSTA, DAVOS and ESTER handle implementation and technical work. See the [Maestro AI capstone paper](https://github.com/glade90/maestro-harvard-capstone/blob/main/paper/MaestroAI-Capstone.pdf).

## Technologies and methodologies

| Area | Technologies and approaches |
| --- | --- |
| **Positioning** | **Agentic AI**, **Deterministic AI-Augmented Systems**, and **AI-Assisted Software Engineering** |
| **AI architecture** | Compound AI system: LLMs handle language and delegation; deterministic, rules-verified components remain authoritative for calculations and state changes. Includes provider-neutral `Braider` abstractions, specialised agent roles, tool delegation, and human-in-the-loop control |
| **Backend** | Python, FastAPI, Uvicorn, typed interfaces, and dependency injection |
| **Frontend** | Browser-based HTML and JavaScript conversational interface |
| **Rules engine** | Deterministic Python, source-grounded rule interpretation, injectable dice, and reproducible simulation fixtures |
| **Data** | Microsoft SQL Server, versioned rules catalogues, and structured JSON |
| **Testing** | pytest, pytest-cov, deterministic fixtures, JUnit XML, coverage gates, and independent UAT |
| **Observability** | Structured logging, correlation IDs, runtime diagnostics, and build identity |
| **Engineering workflow** | Git, GitHub, persistent developer branches, pull requests, Scrum-style iterations, and the Maestro AI-inspired roles ALEK (programme management), BON (architecture and UAT), and COSTA, DAVOS and ESTER (implementation and technical work) |
| **Governance** | Airtable work tracking, OneNote Engineering Standards, documented architecture decisions, and agent-evaluation criteria |
| **Future capabilities** | CrewAI integration, RAG-based retrieval, durable event-sourced game state, and more autonomous multi-agent orchestration are roadmap areas, not claims about the current implementation |

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

## CombatAgent mock (AIDM-DES-004.1)

The AIDM-only specialist `CombatAgent(Braider)` is available from `aidm.combat`, with `agent.handle(InternalRequest) -> InternalResult`. Inject a synthetic model runtime and already-approved encounter context. For the dedicated `mock_combat_intent` operation, it preserves the player's original statement and request/correlation IDs while returning a clearly **simulated** response (no dice, HP changes or committed events). The fake model's proposal is never promoted to a player-safe game result. This is a unit-testable adapter for future Combat Orchestrator use; it does not extend Meta's HTTP routes or implement the Mentzer combat procedure. See [CombatAgent mock adapter and tests](docs/COMBAT_AGENT_STUB.md).

## Thin DungeonMasterAgent gateway (AIDM-DES-015.2)

The AIDM-owned `DungeonMasterAgent(Braider)` in `aidm.dm` provides the first non-LLM player-facing **gateway**. It accepts a known, synthetic `I swing my sword at the orc!` input, calls one injected `CombatAgent.handle` through the existing DES-033.1 typed request/result contract, and relays the Combat stub's permitted narrative **unchanged**. Parent and child calls have distinct request IDs but share session/correlation; the DM itself never invokes a model, rolls dice, interprets combat rules, changes HP or writes events. Noncombat and missing-encounter inputs fail safely. The existing `POST /api/turn` accepts this DM via service injection; no new HTTP server or CLI was introduced. See [Thin DM gateway walkthrough and tests](docs/DM_GATEWAY.md). A real DM's intelligent delegation is still deferred to DES-016/041.

## Local HTML chat — real stub gateway (AIDM-DES-014.1)

Run **one** existing Meta FastAPI application with an injected `DungeonMasterAgent` → `CombatAgent` synthetic chain:

```bash
python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
```

Open **http://127.0.0.1:8000/chat** and submit `I swing my sword at the orc.`. The response explicitly says **Simulation only**: no real combat, die rolls, damage or hit-point changes occur. The browser uses only `POST /api/turn`, maintains ephemeral session/correlation IDs, renders text safely and prevents duplicate submissions. The page is served from the **same FastAPI app**, with no new game endpoint, third-party frontend framework, API key or separate backend. The scripted DM accepts this period-ending UAT phrase without rewriting the original words. See [HTML Chat implementation, tests and BON UAT](docs/HTML_CHAT.md). This is Functional work; human browser UAT is separately required before acceptance.

## Human-driven real combat roundtrip (AIDM-DES-025.2)

**In-development on DAVOS — developer tests and BON UAT still required.** The same browser chat and existing `POST /api/turn` can now connect to COSTA's deterministic source-backed CombatEngine through the DM's typed, in-memory combat-session handler. Run `python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000`, open **http://127.0.0.1:8000/chat**, click **Start 3 vs 3 combat** and follow Alho/Sho's human decision prompts. Evro and the visible orcs take conservative automatic intentions, with all combat legality/dice/modifiers/HP/terminal facts resolved exclusively by Python. Read the ordered player-safe combat log, including real raw dice/modifiers and terminal party HP. Earlier message-only synthetic replies still work independently and are explicitly labelled *simulated*.

The new optional `TurnRequest.combat` contract supports `START`, `ACTION` and read-only `VIEW_LOG` using the **existing** Meta endpoint, with session isolation, decision-token/version/action-ID replay guards and no direct browser-to-Combat API. The controller is encounter-local and loses its state on server restart (not the future Bookkeeper). Optional **explicitly enabled** live LLM interpretation/narration is separate from deterministic rules/HP; the default path needs no paid model or provider key. See [Human combat integration, developer checks and BON UAT](docs/HUMAN_COMBAT_ROUNDTRIP.md). BON will conduct independent integrated DES-001.2 + DES-025.2 Functional UAT in Sprint 2 Iteration 2.4, **not** Sprint 2.END (release only).

## Raw collectible dice (AIDM-DES-005.2)

The raw dice utility deliberately separates **what a Die is** from **rolling** and **the rules that interpret its face**. `from aidm.combat import Die, DiceRoller, FixedRollSource` supports `DiceRoller(FixedRollSource([12])).roll(Die("blue-d20", 20, "blue"), roll_id="attack-001")`, yielding the selected die's actual **unmodified face 12** with identity, source and queue provenance. `roll_many([blue_d8, red_d6, gold_d4])` returns distinct ordered raw faces with atomic fixed-source preflight, never an automatic sum or modifier. There are **no modifier/total fields or NdS±M parser** in this layer. The Combat Rules Engine (DES-001.2) decides applicable modifiers, hit/damage and state changes; DES-005.3 owns complete mixed-actor combat batch orchestration. The new contract **breaks the original DES-005.2 v0.3 interface intentionally** per the Owner's design correction; see [Raw Dice and migration notes](docs/DICE.md).

## Synthetic combat state fixtures (AIDM-DES-006.2)

An original, **in-memory-only** mock encounter state is available from `aidm.combat.state` and `aidm.combat.fixtures`. It uses the same immutable `Combatant` and `CombatSide` contracts for player characters, retainers and monsters, with explicit `EncounterParty`, `OpposingForce`/`MonsterGroup`, `BattlegroundDefinition`/`AreaRef`/`ActorPlacement` and source-labelled equipment/ability references. The fully synthetic two-round 2×2 fixtures verify versioned HP transitions and scripted win/loss; a variable 3×4 fixture verifies flexible rosters and zones, and the Owner-approved Alho/Evro/Sho-Rembo versus three orcs provides canonical 3×3 integration metadata with Evro's STR18 **scenario override** distinct from original STR16.

`MockEncounterState.start(fixture, session_id="demo", trusted_token=object())` creates a test-harness session. `snapshot()` returns immutable state; only an exactly fixture-approved, version-matched scripted effect from the trusted test harness may change HP. The player view redacts opponent HP, AC, traits and unrevealed actors. Raw dice association does **not** compute damage or commit an event. Spatial facts not explicitly authored remain UNKNOWN; no geometry, D&D attack rules, real campaign Bookkeeper writes or durable journal is implemented. See [Mock Battleground and Combat State Fixtures](docs/MOCK_COMBAT_STATE.md). Focused tests cover BON's F01–F23.

## Deterministic combat prototype (AIDM-DES-001.2)

**DRAFT / Functional Build routed to BON UAT Testing.** BON's separate 001.1 Design review does not block COSTA development; full PEQUOD tests, Owner integration approval and BON's joint Functional UAT with 025.2 remain pending. The bounded first-slice Python `aidm.combat.engine.CombatEngine` consumes owner-defined `CombatSide`/`Combatant` and battleground fixtures; typed **external Encounter Agent surprise**, explicit physical `DiceKit`, injected raw `DiceRoller`, versioned `RuleProfile` and a tiny replaceable `PrototypeReferenceProvider` (**TD-AIDM-DATA-001**, not a DB). It pauses for one HUMAN/AGENT typed decision at a time, tracks deterministic side initiative and ordered real/suppressed phase checkpoints, applies only supported ordinary melee and records source-labelled raw dice, Strength, AC, weapon/house-rule values, HP transitions and terminal outcomes. Approved **HR-WEAPON-FLAIL-001 v1.0** gives Alho's flail only 1d6 damage; Evro source STR16 remains unchanged beside fixture-only STR18. The 1983 Basic first-level character and 1-HD monster attack bands are independently encoded, not one shared table.

The full internal chronological journal can be exported as safe local `reports/combat-logs/*.jsonl`; player views exclude hidden creature HP/AC/traits and private controller information. **Not a claim of complete Mentzer combat:** tied initiative resolves as a deferred simultaneous damage batch for both sides (including eligible attacks from combatants slain in the same exchange), while due enabled morale checks safely block, missile/magic/movement mechanics have explicit disabled/unsupported statuses, Alho's unknown equipped AC cannot be invented, and conditional fixed damage-die exhaustion can consume the d20 without committing state (future transactional dice-source contract). The test-local HP/journal is **not** persistent Bookkeeper DES-017 or durable event DES-007, nor is it the HTML/DM orchestration. BON's functional UAT in Iteration 2.4, PEQUOD source-matched full regression and ALEK capacity review remain pending. The independent BON 001.1 design-stage workflow does not hold up the Build. See [Combat Controller: draft interfaces, fixed-roll examples, and limitations](docs/COMBAT_CONTROLLER.md).

## Shared internal communication contracts

The framework-neutral in-process contracts in `aidm.internal_messages` define `InternalRequest`, `InternalResult`, `SafeError`, `ErrorCode`, and the six `ResultStatus` outcomes. A child invocation receives its own request ID while preserving its workflow correlation ID. State-changing requests require a command ID and expected world version; event references are absent unless a trusted service supplies actual committed effects. Caller and knowledge-scope fields are **untrusted claims**, not permission grants. The small `safe_call` helper supports injected fake-tool tests without becoming a dispatcher, CrewAI replacement, HTTP server, or Bookkeeper. See [Internal request/result contracts](docs/INTERNAL_MESSAGES.md) (AIDM-DES-033.1). The mock-first FastAPI `/api/turn` integration is implemented under DES-013.2; real routing remains DES-016.

## Programme references

- [Airtable](https://airtable.com/appG1E9VVbXBS7ZB0/pagkLWL3XMiwNHuEl/edit?utm_source=chatgpt.com) is authoritative for Stories, ownership, scope, Test Results and Release Notes.
- OneNote: *Courses → Golden Braid → Engineering Standards*, particularly §4 (GitHub Repository and Commit Strategy).
- Architecture: *Courses → Golden Braid → AIDM - Architecture & Execution*, version 0.3 (12 November 2026), a planning rebaseline, not approved technical design.
- Sprint 1 transition: *Sprint Plan - 1.1 Transition*, baseline v1.2 (17 November 2026).

**Bootstrap story:** `AIDM-DES-026.1` (Technical Build). The approved `VERSION` target is implemented under `AIDM-DES-030.1`; release publication, CI and the application runtime remain separately scoped.
