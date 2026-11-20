# Braider — Generic Agent Core (DES-042.1)

**Scope:** Golden Braid-wide reusable superclass; first increment under AIDM's sprint. Normative design: *AIDM - Generic Agent* §6, accepted by Project Owner on 20 November 2026. This module is **not** an agent dispatcher or CrewAI replacement.

## Imports and roles

`from braider import Braider, ModelChoice, ContextItem, ModelTarget, FakeModelRuntime` works without importing `aidm`, FastAPI, provider SDKs, project settings, logger, D&D rules or Bookkeeper.

`Braider` owns exactly one synchronous invocation of its injected `ModelRuntime`. `ModelChoice` offers logical `ECONOMY`, `BALANCED` (default) and `CAPABLE`; an injected `model_targets` mapping chooses synthetic provider/model identifiers without modifying a subclass. Context categories are `RECENT_CONVERSATION`, `TASK_CONTEXT`, `REFERENCE_MATERIAL`, `WORKING_STATE`; **none grants permission**. The caller must explicitly allow categories and provide already-authorised text. No context retrieval occurs here.

`BraiderOutput` contains only generic proposed text or safe error, logical model choice, selected target and opaque `trace_id`. In particular, a successful model response is **not an executed service action**. There is no HTTP, game state, event/HP change, autonomous loop, automatic retry, tool call, network request, memory or domain permission check. Errors redact provider exception details.

## Reproducible offline example

```python
from braider import Braider, ContextItem, FakeModelRuntime, ModelTarget, ModelChoice

class ResearchBraider(Braider):
    def __init__(self):
        super().__init__(
            runtime=FakeModelRuntime("Synthetic research summary."),
            model_targets={ModelChoice.BALANCED: ModelTarget("fake", "synthetic-model")},
            allowed_context=frozenset({ContextItem.REFERENCE_MATERIAL}),
            instructions="Summarise only the supplied approved context.",
        )

out = ResearchBraider().invoke(
    "Summarise the note", approved_context={ContextItem.REFERENCE_MATERIAL: "A public training note"},
    trace_id="sample-01",
)
assert out.succeeded and out.text == "Synthetic research summary."
```

Cross-project tests define two **test-only** specialisations (game-like and research-like) in `aidm/test/test_braider.py`, because the existing standard `python -m aidm.test_runner` discovers test files under `aidm/`. They use no `aidm` production module; the standalone `braider` package remains extractable. Run `python -m pytest aidm/test/test_braider.py -q --cov=braider --cov-report=term-missing` to measure *Braider* coverage specifically; standard project runner provides overall AIDM coverage and tests all cases.

## AIDM consumer contract, after 042.1 merges

A future `aidm/combat/agent.py` will implement `class CombatAgent(Braider)`. The **AIDM adapter** accepts `aidm.internal_messages.InternalRequest` with its `request_id` and `correlation_id`, passes approved context into `Braider.invoke(...)`, and produces `aidm.internal_messages.InternalResult`. It maps a rejected or unavailable inference to a safe AIDM status. It must not pretend the model's text is an authoritative combat event, dice roll or state mutation. Likewise the DM consumer uses its own adapter. None of those DES-033.1 types enters `braider/`.

**Excluded:** actual Combat/DM specialist, CrewAIAdapter, credential configuration, provider SDK, agent graph, reusable distribution/new repository, remote calls or new game rules. This Build neither authorises an agent to see hidden facts nor claims an LLM has made a game decision.