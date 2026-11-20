# AIDM-DES-004.1 — CombatAgent Stub Behind Combat Orchestrator Contract

**Status:** AIDM-DES-042.1 Braider dependency merged through PR #8. This document accompanies the separate AIDM-DES-004.1 CombatAgent implementation PR. The first increment is a synthetic mock, not a combat resolution.

## What is built and why

A small AIDM-owned `CombatAgent(Braider)` and injected handler `combat_agent.handle(request)` that takes AIDM DES-033.1 `InternalRequest` and returns `InternalResult`. Braider does not import AIDM; the CombatAgent method is the project-specific bridge. This is a scripted mock to exercise integration before any real encounter engine, dice logic, Mentzer rules, HP or Bookkeeper.

### Example

```python
from braider import FakeModelRuntime, ModelChoice, ModelTarget
from aidm.combat import CombatAgent, MOCK_COMBAT_OPERATION
from aidm.internal_messages import make_request

agent = CombatAgent(
    runtime=FakeModelRuntime("Non-authoritative synthetic intention"),
    model_targets={ModelChoice.BALANCED: ModelTarget("fake", "training")},
    approved_encounter_context="Synthetic training actors only",
)
request = make_request(
    caller="DM", capability="combat", operation=MOCK_COMBAT_OPERATION,
    payload={"player_text": "I swing my sword at the orc!"},
    request_id="call-1", correlation_id="turn-1",
)
result = agent.handle(request)
assert result.status.value == "COMPLETED"
assert result.data["simulated"] is True
assert result.data["combat_resolved"] is False
assert result.event_refs == ()
```

Only a fake *invocation* completed; combat **was not executed**. The player-safe `safe_summary` explicitly discloses this. Original player text and correlation/request IDs are preserved. The agent ignores untrusted `payload['context']`: permitted encounter context must be explicitly injected by a trusted caller, not inferred from a claimed knowledge scope or supplied JSON. A fake model output is not forwarded directly to player-safe narration or general response `data`, as it is still an untrusted proposal.

Unknown operation/capability returns `BLOCKED` and a safe `UNKNOWN_CAPABILITY` error; missing player text returns `NEEDS_PLAYER_INPUT`/`INVALID_INPUT`; runtime failure returns `ERROR`/`DEPENDENCY_UNAVAILABLE`; any attempted world-mutation command is blocked. No raw exception/hidden content, dice results, damage, game-state writes, authoritative event references, HTTP endpoint or direct player UI integration.

`agent.handle` is the handler method to inject in a future Combat Orchestrator or service registry, e.g. `registry.register('combat', agent.handle)`. The real dispatcher policy (DES-016), combat sequence/rules/source verification (DES-001–012), and DM gateway (DES-015.2) are separate Stories. The production agent must later deliver a validated, typed non-authoritative intention proposal and player-safe narration derived from verified events; this first stub **does not** attempt that.

## Developer checks and limitations

Run `python -m pytest aidm/combat/test/test_agent.py -q --cov=aidm.combat --cov-report=term-missing` and the normal `python -m aidm.test_runner` from the actual 004.1 PR commit to confirm the integrated application. An earlier staged isolated focused check passed 20 cases with 100% combat-stub module coverage; **that check is not a complete accepted-main regression**, which still requires owner verification on PEQUOD. File locations: `aidm/combat/__init__.py`, `aidm/combat/agent.py`, `aidm/combat/test/test_agent.py`, `docs/COMBAT_AGENT_STUB.md`.

The fixture/implementation deliberately does not use commercial rulebook/module content. Functional end-to-end browser/DM integration and BON UAT remain independent Stories. The Technical Story requires developer TEST and owner-confirmed actual hours before ALEK closure.