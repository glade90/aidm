# AIDM-DES-006.4 — Shared Actor Condition State Engine

**COSTA Technical Build · Sprint 3 / Iteration 3.1 · Owner reassigned from DAVOS on 25 Nov 2026.**

## Authority, reuse, and boundaries

`aidm.combat.conditions.ConditionStateService` is a deterministic **condition-only ledger** attached to existing DES-006.2 immutable `Combatant` references. `EncounterActorIndex` points at actual actor instances and never copies or modifies HP, equipment, positions, base AC, or combat phases. Each actor owns an immutable list of condition instances and a condition-specific optimistic version. Live `CombatEngine` remains authoritative for HP and combat; future DES-006.5 integrates the transition service at verified combat action boundaries. The initial library is deliberately **not automatically installed into the live 3v3 session**.

A trusted Python Combat/Rules orchestrator validates hits, saving throws, spell applicability, source rules and immunities **before** minting `VerifiedConditionEvent` through its private `ConditionEventAuthority`. The service accepts only typed `ApplyCondition` / `RemoveCondition` commands with a matching capability-attested event, cause ID, rule provenance, target actor, action ID, correlation and expected actor version. An LLM proposal or a raw browser request is not authorised to mutate the state engine. The authority object must not be exposed in any web/LLM/plugin interface.

The initial registry has distinct status-flag codes **POISONED**, **NAUSEATED** and **ASLEEP**. Custom definitions may be injected with an explicit `independent_instances=True` rule policy to allow multiple simultaneously active instances of the same status. Otherwise same-code stacking is rejected rather than silently merged or duplicated. Conditions have stable instance IDs, source actor/rule/overlay provenance, optional integer application and expiry game times, immutable typed parameters and ACTIVE/REMOVED/EXPIRED lifecycle. No poison damage, nausea duration, sleep immunity, sleep attack prohibition, spell AC modifiers, disease progression or cures are inferred here.

### Operations

| Operation | Contract |
|---|---|
| `service.apply(ApplyCondition(...))` | Atomic condition addition after trusted source proof, valid type and actor-local expected version. Returns immutable `ConditionReceipt`. |
| `service.remove(RemoveCondition(...))` | Explicit authorised, versioned removal of an active instance only. |
| `service.get_active(actor_id)` | Trusted controller immutable full audit view; not a browser endpoint. |
| `service.get_player_safe(actor_id, visible_actor_ids=(...))` | Safe names only; prevents secret enemy-state visibility and excludes provenance/parameters. Caller supplies a **trusted** player-visibility allowlist. |
| `service.read_action_receipt(id)` | Query original receipt to resolve uncertain commits without a blind retry. |
| `service.get_due(now_game_seconds)` | Read-only scan of rule-validated integer deadlines. Undated conditions never expire automatically. |
| `service.process_due(clock_receipt, authority=issuer)` | Consume a complete typed DES-017.2.1 `ClockAdvanceReceipt` in monotonic version/time sequence. Expire all due independent instances atomically with auditable `ExpiryReceipt` values; repeat identical receipt returns identical result and does not expire twice. |
| `service.snapshot()` / `ConditionStateService.restore(...)` | Immutable in-memory snapshot with applied action/event index, actor version history and consumed clock advances; restore into an isolated instance. No SQL/files or cross-process durability promised. |

`process_due` is an **in-process tested adapter seam**, not yet a working Combat→GameClock→ConditionState subscription; DES-006.5 is responsible for the verified orchestration, safe replay and GUI handoff. It rejects receipt ID conflicts, missing earlier clock receipts, stale version and mismatched clock, and never uses wall time.

## Development tests and caveats

The source-equivalent isolated Python 3.13 fixture suite (compatible `Combatant` test shim and the DES-017.2.1 GameClock implementation) reports:

```
python -m pytest aidm/combat/test/test_conditions.py -q \
    --cov=aidm.combat.conditions --cov-branch --cov-report=term-missing
17 passed; condition service 92% branch-aware coverage
```

Tests exercise statuses across character/orc actors, the real 3v3 **fixture API** (the local fixture shim has matching expected member IDs), source authentication, stale/duplicate events, same-code stacking policy, removal, safe projections, deadline boundary, real typed GameClock `ClockAdvanceReceipt`, replay after restore, corruption, and HP isolation. The temporary local fixture shim is **not a deliverable**. Source-matched PEQUOD regression of the actual existing `state.py` / 3v3, Python3.12 compatibility, full app >=90% coverage and Node TAP are NOT YET PROVEN; do not close the Story on the standalone fixture receipt alone.

**PR #25 is merged.** On 25 November 2026, `costa` was fast-forwarded to the merged `main` SHA `8b6d7209c04ca17cab7f19d74b1dbd64ba9f6287` *before* this separate Story was added. This Technical Build is now committed on persistent `costa` as exactly three source/test/documentation files. No patch application or second branch is required; do not apply the earlier downloaded patch again.

### PEQUOD source-matched developer acceptance

Run tests in a **clean detached worktree** matching the current `costa` remote SHA; do not disturb the existing `aidm`, `aidm-0042-check` or `aidm-0172-check` folders:

```bash
cd /c/Development/aidm
git fetch origin
git worktree add --detach ../aidm-0064-check origin/costa
cd ../aidm-0064-check
git rev-parse HEAD
git status --short
python -m pytest aidm/combat/test/test_conditions.py -q
focused_exit=$?
python -m aidm.test_runner
python_exit=$?
node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs
node_exit=$?
printf 'FOCUSED=%s PYTHON=%s NODE=%s\n' "$focused_exit" "$python_exit" "$node_exit"
git rev-parse HEAD
git status --short
```

Obtain focused results, full Python JUnit run ID and measured >=90% coverage, and Node TAP exits from the SAME clean source SHA. Tests must run on actual PEQUOD Python 3.12/Windows; the earlier 17-test standalone Python 3.13 fixture is a preliminary local receipt, not that gate. Record exact tested SHA in Airtable and the PR before requesting ALEK Technical closure. No BON Functional UAT is required. Confirm actual developer time with the Project Owner before setting Stage Complete.
