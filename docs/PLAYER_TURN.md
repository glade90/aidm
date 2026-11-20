# AIDM-DES-013.2 — Local request-to-mock-tool vertical slice

**Developer:** DAVOS · **20 November 2026** · **Status:** developer BUILD/TEST; independent BON UAT follows.

## How the pieces fit

There is still only **one** FastAPI application and Uvicorn server: COSTA's `aidm.meta.http.create_app`. The new `aidm.meta.turn.router` mounts `POST /api/turn` on that app. FastAPI checks incoming JSON against Pydantic `TurnRequest`, and the handler converts the message, optional session ID and correlation ID to COSTA's `InternalRequest` via `make_request`. It does **not** create its own internal message classes or accept player-provided `caller`, `knowledge_scope`, permissions or world-state fields.

The route retrieves the registered `dm` callable from COSTA's `ServiceRegistry`. It invokes the handler once using the shared `safe_call` boundary, bounded by the configured `AIDM_REQUEST_TIMEOUT_SECONDS`. A registered DM returns an `InternalResult`, which is projected into Pydantic `TurnResponse`. Only the status, IDs, safe message, a fixed mock outcome and approved error code/message are exposed; arbitrary internal `data`, hidden world information, committed events and exception text never appear in the HTTP response. A `HANDOFF` remains a handoff, not a claimed completed action.

`aidm.meta.mock_turn` supplies a **demonstration-only** DM and dispatcher. Its DM constructs a child `InternalRequest` via `make_child_request`, the dispatcher invokes the single registered COSTA `MockTool` using `safe_call`, then the DM returns an accurately worded mock summary. For the phrase “What happens if I attack the orc?” the response explicitly states that no roll, damage or HP change was calculated. A test-only `tool:teleport` message demonstrates a blocked unknown action: the dispatcher never calls the mock tool for it. No real LLM, combat engine, Bookkeeper, dice or persistent state is involved.

## Start, try, inspect, and stop

From the repository root on Python 3.11+:

```bash
python -m pip install -r requirements-dev.txt
python -m uvicorn aidm.meta.mock_turn:create_mock_app --factory --host 127.0.0.1 --port 8000
```

In development mode, open `http://127.0.0.1:8000/docs` for FastAPI's interactive request/response schema and `POST /api/turn`. In a separate terminal:

```bash
curl -X POST http://127.0.0.1:8000/api/turn -H "Content-Type: application/json" -d '{"message":"What happens if I attack the orc?","session_id":"local-1","correlation_id":"demo-1"}'
```

The response has `status: COMPLETED` **only for the mock operation**, `simulated: true`, `tool_outcome: {"mock":true}`, the supplied correlation and session IDs, a new request ID, and the sentence that no real combat calculation occurred. Do not interpret this as a successfully executed attack. Use `tool:teleport` for an expected `BLOCKED / UNKNOWN_CAPABILITY` response; empty JSON or a blank message yields `422 / NEEDS_PLAYER_INPUT / INVALID_INPUT`. A fake adapter failure returns a sanitized `ERROR`; timeout yields HTTP 504 and a safe `TIMEOUT` code.

The original command `python -m uvicorn aidm.meta.http:create_app --factory --host 127.0.0.1 --port 8000` still runs COSTA's minimal health-only composition with the **route present** but no registered DM: `/api/turn` returns safe HTTP 503 `DEPENDENCY_UNAVAILABLE` until a DM is injected. Both compositions expose the existing `/health` and `/status`. Stop with **Ctrl+C**, allowing the established Meta lifecycle to close owned resources. Bind only to 127.0.0.1 for this local prototype; do not use reload/workers as an authentication or access mechanism.

## Tests and handover

```bash
python -m pytest aidm/meta/test/test_turn.py -q
python -m aidm.test_runner
```

Tests cover the six BON UAT cases: valid turn and IDs; honest mock attack; malformed/empty/unknown inputs; sanitized exception and timeout followed by healthy requests; exactly-one-tool invocation and request isolation; health/status/docs and clean lifecycle shutdown. The normal runner retains unique reports and measures line coverage. Do not mark this Functional Story complete until BON independently performs its UAT and ALEK records actual hours.

**Limitations:** `asyncio.wait_for(asyncio.to_thread(...))` bounds HTTP waiting for these **read-only fakes**, but Python cannot forcibly stop a synchronous worker thread once it has started. Actual mutation-capable components must implement cancellation/deadline checks and Bookkeeper reconciliation; this demo is **not** permission to put authoritative state-changing operations behind a detached timed-out thread. No persistent memory, model calls, authenticated remote access, final DM protocol, or Combat integration is implemented here. Future DES-015.2 DM/Combat stubs should be injected under the same registry key `dm` and return the existing typed `InternalResult`, leaving the `/api/turn` route unchanged.
