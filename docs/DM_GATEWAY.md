# AIDM-DES-015.2 — Thin DungeonMasterAgent Gateway

**Owner:** DAVOS · **Iteration:** Sprint 2 / 2.2 · **Development Class:** Technical

## Why this is a stub

The eventual Dungeon Master is the *single player-facing conversational agent*. This increment proves only the service boundary. `DungeonMasterAgent` subclasses the project-neutral `Braider`, but **never calls its inherited `invoke()`**. There is no DM LLM, prompt-based routing, memory, game state, combat resolution or independent narration. An explicitly approved synthetic combat line is a temporary exception to future LLM-directed delegation (DES-016/041).

The existing `CombatAgent(Braider)` is injected as a handler, not instantiated inside the DM. Its *own* synthetic fake model receives the original player text and pre-authorised encounter context and returns a typed `InternalResult`. The DM forwards the resulting player-safe narrative **verbatim**, without adding dice, damage, HP or claimed committed events.

## Files and responsibilities

- `aidm/dm/agent.py`: `DungeonMasterAgent(Braider)`, synchronously callable via `handle(request)` or `__call__(request)`. It accepts injected generic Braider runtime/model mapping (unused for DM inference), an injected Combat handler, and a trusted `approved_encounter_id` fixture.
- `aidm/dm/__init__.py`: package export.
- `aidm/dm/test/test_dm_agent.py`: offline gateway, error, ID, no-DM-LLM, sequential-isolation and real FastAPI integration checks.

No new HTTP endpoint or CLI harness is created. The CLI prototype belongs to DES-015.3 and the HTML chat to DES-014.1.

## Message flow

1. Meta `POST /api/turn` validates JSON with the existing `TurnRequest`, calls shared `make_request(caller="Meta", capability="dm", operation="player_turn", ...)`, and obtains the injected `dm` from COSTA's registry.
2. `DungeonMasterAgent.handle` accepts **only** the agreed scripted synthetic `I swing my sword at the orc!` line (case-insensitive; outer whitespace is irrelevant for *selection*). It forwards the original input unmodified. Anything else is explicitly BLOCKED; blank input requests clarification. This is deliberately **not** a general combat-intent parser.
3. The encounter ID comes from trusted constructor injection, not from player-controlled JSON. If the input claims a different encounter, the call is BLOCKED. Without a configured encounter, the DM returns NEEDS_PLAYER_INPUT rather than inventing a location.
4. `make_child_request` gives the Combat call a **new** request ID and a parent-request link while preserving correlation and session. It sets `capability="combat"`, `operation=MOCK_COMBAT_OPERATION` and `payload={"player_text": <exact original words>}`. The incoming claimed knowledge scope is cleared; authority is not inferred from a scope label.
5. `safe_call` invokes the injected handler once, catches failures, and verifies child identifiers. The DM then returns a parent-bound `InternalResult` with the Combat result's **unchanged status and safe_summary**. Error codes are re-enveloped safely against the parent's operation. Only the fixed demonstrative `mock/simulated/combat_resolved` flags pass through; private proposals or unverified specialist data do not.
6. The existing Meta adapter projects the parent result into `TurnResponse` and returns it to the player. The shared parent request ID and correlation ID are preserved. A specialist HANDOFF is never presented as an executed action.

**Important:** COMPLETED here means *mock processing completed*, not that the attack was executed. A completed fake result must state `simulated=True`, `combat_resolved=False`, supply a permitted safe narrative, and contain no committed effects. Otherwise the DM reports ERROR. No real world-event record can be synthesised.

## Reproduce locally

Run from the AIDM repository root with installed dev dependencies:

```bash
python -m pip install -r requirements-dev.txt
python -m pytest aidm/dm/test/test_dm_agent.py -q
python -m aidm.test_runner
```

A minimal **without-server** demonstration of the tested interface:

```python
from braider import FakeModelRuntime, ModelChoice, ModelTarget
from aidm.combat import CombatAgent
from aidm.dm import DungeonMasterAgent
from aidm.internal_messages import make_request

targets = {ModelChoice.BALANCED: ModelTarget("offline-fake", "synthetic")}
combat = CombatAgent(
    runtime=FakeModelRuntime("private proposal"),
    model_targets=targets,
    approved_encounter_context="An approved synthetic training encounter",
)
dm = DungeonMasterAgent(
    runtime=FakeModelRuntime(), model_targets=targets,
    combat_handler=combat.handle,
    approved_encounter_id="training-encounter",
)
request = make_request(
    caller="Meta", capability="dm", operation="player_turn",
    payload={"message": "I swing my sword at the orc!"},
    session_id="local-1", correlation_id="turn-1",
)
result = dm.handle(request)
print(result.status.value, result.safe_summary, result.correlation_id)
# COMPLETED Simulation only: ... no dice ... no damage ... turn-1
```

For the actual HTTP seam, create a `ServiceRegistry(required=("dm",))`, register `dm` with the same injected instance, and call COSTA's `aidm.meta.http.create_app(registry=registry)`; the focused integration test demonstrates that this works without changing `POST /api/turn` or starting another server. The upcoming browser/UI Story owns runnable HTML composition. In local `development` mode, FastAPI exposes its existing Swagger `/docs`; `test` mode hides docs.

## Known limitations and later work

No genuine free-text intent recognition, broader action routing, multi-turn dialogue state, approved dynamic encounter selection, model/provider usage by DM, narrated revoice, combat engine, Bookkeeper or persistent history. The synthetic CombatAgent makes one *fake model* proposal and returns a safe constant narration; it never rolls dice or changes game state. Real world mutations will require Bookkeeper verification and must not be handled as detached timeout threads. The default `aidm.meta.mock_turn:create_mock_app` remains the earlier DES-013.2 mock-tool composition; this Story supplies the injectable real `DungeonMasterAgent` class rather than replacing that factory.

DES-015.3 owns a separate CLI roundtrip; DES-014.1 owns the browser chat and composition; DES-016/041 own intelligent delegation and complete DM behaviour; DES-001–012 own actual combat rules/sequence. This **Technical** Build proceeds from developer TEST to ALEK, without BON Functional UAT. Record source-matched full regression coverage and actual time before completion.
