# AIDM Internal Request and Result Contracts

**Story:** AIDM-DES-033.1 (Technical Build, COSTA)  
**Design authority:** Golden Braid Engineering Standards §11 / AIDM-DES-033  
**Changed:** 20 November 2026 — first framework-neutral in-process increment  
**How to run tests:** `python -m aidm.test_runner`, or `python -m pytest aidm/test/test_internal_messages.py -q`

## 1. What this does — and what it does not

This module defines the **meaning** of a component-boundary request or result, not how an agent is orchestrated. It is analogous to defining Python dataclasses for a Flask application’s domain layer, while Flask/FastAPI handles HTTP. In the first AIDM process, an orchestrator calls a tool **as an ordinary Python function**; the request/result types make it clear which call, which user turn, which outcome and whether any verified game effects occurred.

`aidm/internal_messages.py` depends only on the Python standard library. There is **no** FastAPI/Pydantic/CrewAI/LangGraph dependency, socket, message broker, agent scheduler, routing registry, tool retry engine, real state store, model invocation or HTTP endpoint. Only use this contract at meaningful boundaries—not every private helper or arithmetic function. DES-016 owns routing; DES-013.2 owns the FastAPI `/api/turn` adapter; DES-017/Bookkeeper owns authoritative state writes and idempotency.

## 2. Public types and helpers

| Type/helper | Responsibility |
|---|---|
| `ResultStatus` | Six precise statuses: `COMPLETED`, `NEEDS_PLAYER_INPUT`, `BLOCKED`, `NEEDS_RULING`, `ERROR`, `HANDOFF`. `HANDOFF` never means the work completed. |
| `ErrorCode` / `SafeError` | Stable public codes and a predefined redacted explanation. Includes source operation and correlation ID; no raw exception details. |
| `InternalRequest` | One invocation's ID, workflow correlation ID, claimed caller, capability, operation, mapping payload, optional session/campaign/expedition/encounter, parent ID and claimed knowledge scope. |
| `CommittedEffects` | **Only** explicit verified-looking commit metadata (command ID, event refs, new version) supplied by the trusted fixture/service. The type itself is *not* an authorization or cryptographic proof. |
| `InternalResult` | Same request/correlation IDs, status, player-safe summary, data, optional safe error and optional committed receipt. `event_refs` and `new_world_version` properties are empty unless a commit receipt was supplied. |
| `make_request` / `make_child_request` | Construct calls; child gets a distinct invocation ID, same correlation ID, explicit parent and inherited optional context. Mutation metadata is **not** automatically carried forward. |
| `make_result` / `safe_failure` / `safe_error` | Construct matching, validated responses and constant safe errors. |
| `safe_call` | Minimal **one-handler** exception mapping and response-ID validation for an injected fake tool. This is **not** a dispatcher, permissions check, retry system or future CrewAI replacement. |

Validation rejects missing or malformed IDs, operation names or payload keys with `ContractError` containing only field names, never rejected values. The outer mapping is copied; nested values remain the responsibility of the caller/tool, and a trusted adapter must validate the actual domain schema. `InternalRequest` and `InternalResult` are frozen dataclasses; they are not security boundaries or fully deep-immutable trees.

## 3. Read-only request and fake tool result

```python
from aidm.internal_messages import (
    InternalRequest, ResultStatus, make_child_request, make_result, safe_call,
)

request = InternalRequest(
    request_id="call-7", correlation_id="turn-42",
    caller="DM", capability="exploration", operation="inspect_area",
    payload={"space_id": "room-3"}, knowledge_scope="player",
)

def fake_inspector(req: InternalRequest):
    # Trusted projection: do NOT return hidden trap metadata or DM-only facts.
    return make_result(req, ResultStatus.COMPLETED,
                       safe_summary="You see two exits.",
                       data={"exits": ["north", "west"]})

child = make_child_request(
    request, caller="Expedition", capability="exploration",
    operation="inspect_area", payload=request.payload,
    request_id="call-8",  # or omit to generate a unique call ID
)
result = safe_call(child, fake_inspector, supported_operations={"inspect_area"})
assert result.status is ResultStatus.COMPLETED
assert result.request_id == "call-8"
assert result.correlation_id == "turn-42"
assert result.event_refs == ()  # No authoritative world change happened.
```

The tool result is deliberately a *player-safe projection*. The word `player` in an **incoming** `knowledge_scope` is merely a request claim. A caller can also claim to be `DM`: neither statement grants permissions. A trusted service/adapter must obtain and enforce actual identity and scopes, and build an allowlisted player-facing result. Never send raw canonical or DM-only data to the browser or LLM.

## 4. Commands, committed effects and errors

```python
from aidm.internal_messages import (
    CommittedEffects, InternalRequest, ResultStatus, make_result,
)

cmd = InternalRequest(
    request_id="call-9", correlation_id="turn-42",
    caller="Combat", capability="combat", operation="apply_damage",
    payload={"target_id": "orc-1", "points": 2},
    is_mutation=True, command_id="command-123", expected_world_version=7,
)

# Illustrative ONLY: assume the independent authoritative service confirmed
# the command committed and returned this receipt. Do not construct it from
# a proposed action, narration, or untrusted HTTP data.
receipt = CommittedEffects("command-123", ("event-91",), 8)
result = make_result(cmd, ResultStatus.COMPLETED, committed_effects=receipt)
assert result.event_refs == ("event-91",)
assert result.new_world_version == 8
```

A mutating request **must** include `command_id` and `expected_world_version`. A read-only request needs neither. The contract checks syntax, matching command identity, monotonically increasing committed version, and ensures no event refs appear for a `HANDOFF`, error, unsupported call or an uncommitted proposal. It **does not** lock the world, make IDs globally unique, persist command deduplication or authenticate receipts. The Bookkeeper later provides those guarantees. Never automatically retry an uncertain state-changing command; after a timeout, query the authoritative ledger/command record.

Error example:

```python
from aidm.internal_messages import ErrorCode, ResultStatus, safe_failure
blocked = safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY,
                       status=ResultStatus.BLOCKED)
assert blocked.error.code == ErrorCode.UNKNOWN_CAPABILITY
assert blocked.event_refs == ()
```

The one-handler helper maps an unsupported capability to `BLOCKED`, missing player clarification to `NEEDS_PLAYER_INPUT`, rules ambiguity to `NEEDS_RULING`, dependency/timeout/unexpected exceptions to `ERROR`, and permission denial to `BLOCKED`. Messages are fixed and do **not** interpolate raw exception text, arguments, stack traces, API keys or hidden state. Timeout explicitly means **unknown outcome**, not proof of rollback. The fake tool may be replaced by an implementation of the same typed Python callable.

## 5. Later integrations and ownership boundaries

- **DES-013.2 / FastAPI:** validate inbound HTTP JSON with Pydantic, authenticate the caller/knowledge scope using trusted application context, convert to `InternalRequest`, and convert an approved `InternalResult` player projection into HTTP response. Do not expose raw dataclass dumps of hidden game data. Reuse the current `/api/turn`, not a new route.
- **DES-016 / orchestration:** choose registered capabilities and handlers. CrewAI or another orchestration framework can call a thin adapter; the contract is framework-neutral. `safe_call` is not a full dispatcher or substitute for CrewAI.
- **DES-017 / Bookkeeper:** independently enforce authorization, command uniqueness, world-version concurrency, persistence, authoritative `CommittedEffects`, and event ledger. This module does not mutate game state.
- **DES-035 / logging:** wire correlation and command IDs to existing trace instrumentation where appropriate. No message bus, automatic retries or global logging changes in this Story.
- **DES-014 / browser:** may only see the player-safe response generated by a trusted projector once the HTTP/UI layers exist.

The six statuses and `ErrorCode` values are Python enums. When an actual wire contract is introduced, DES-013.2 should encode them consistently, e.g. JSON strings with a consciously versioned boundary schema. No premature schema-version field is required in every internal Python call.

**Tests:** deterministic pytest fixtures cover nesting, ID propagation, all statuses, missing/invalid command metadata, known/unknown fake operations, sanitized exceptions and timeout, stale/duplicate fake authority, player projection/hidden facts and refusal to manufacture committed events. No live LLM, network, API credentials or real database required.