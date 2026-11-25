# AIDM-DES-017.2.1 — Shared deterministic GameClock

**Technical Build** · COSTA · Sprint 3 / Iteration 3.1 · Owner revised allocation **0.50 h** (25 November 2026).

## Authority and scope

The authoritative clock for a campaign is a single in-memory `GameClock` with one monotonic integer `elapsed_game_seconds` and optimistic `version`. Its supported mutation operations consume only authoritative verified domain-completion events. A browser, LLM, phase transition, attack, or raw player declaration cannot advance clock time.

The implementation is an independently testable **timekeeping primitive**. It is **not yet wired into live Combat/Expedition sessions**. The app's current 3v3 combat behavior is unchanged; the orchestrator must later inject this clock and attest truly completed rounds / battle endings. The `ClockEventAuthority` class is an *in-process capability* supplied to trusted Python domain orchestrators; it is **not a network-authentication system**. Never pass the authority to models, the browser, plugins, or a public API.

### Supported typed operations

- `GameClock.create_clock(campaign_id, profile, issuer, clock_id=...)` — one authoritative clock object for a campaign; do not create competing instances for a session.
- `read_clock()`, `read_action_receipt(action_id)`, `handoff_clock(expected_version)` — pure/read-only, no time increments.
- `complete_combat_round(ClockRoundCompleted)` — **10 seconds** per verified completed round under Mentzer Basic. An incomplete/paused round cannot mint trusted completion evidence. A round is never charged per attack or per phase.
- `settle_combat(ClockCombatSettled)` — only verified **normal** battle close, adding `max(0, normal_battle_minimum_seconds - accounted_round_seconds)` once for that encounter.
- `close_exceptional_combat(ClockCombatClosedExceptional)` — explicit trusted pursuit/interrupted/aborted close, zero additional recovery time, preserving already elapsed completed rounds.
- `complete_exploration_turn(ClockExplorationTurnCompleted)` — **600 seconds** per distinct verified exploration-turn completion, not on a mere module handoff.
- `snapshot()` and `GameClock.restore(snapshot, issuer)` — immutable in-memory snapshot value, restoring the complete receipt/action/event/round/turn deduplication ledger into a **new** clock object. No durable file/SQL persistence is implied.

A `ClockCommand` carries `clock_id`, `caller_service`, `action_id`, `source_event_id`, `expected_version`, `rules_profile_ref` and `correlation_id`. A `VerifiedClockEvent` must be minted by the trusted capability issuer for the *same* event, domain, encounter/round or expedition/turn. The clock validates ID, caller, evidence, profile, expected version, ordering, encounter state and duplicate event identity. Accepted new actions yield immutable `ClockAdvanceReceipt` objects (including valid **zero-delta** close events). Identical action replay returns the original receipt, even after later changes. Conflicting action reuse, stale requests and duplicate source/round/turn events fail closed.

To avoid unsupported interleaving, initial one-party build rejects concurrent unsettled encounters and exploration advances while an encounter remains unresolved. Combat remains responsible for the actual end-of-round/end-of-battle verification; GameClock only checks trusted attestation.

## Source-based examples

Under `MENTZER_BASIC_1983` (Mentzer 1983 Basic Player's Manual printed p.56, owner-approved ADR-017.2-01 and -03):

| Verified operations | Elapsed time |
|---|---:|
| Five distinct combat round completion receipts | 50 seconds |
| Verified **normal** battle settlement after those rounds | +550 = **600 seconds** |
| An additional separately verified exploration turn | +600 = **1,200 seconds** |
| 60 combat rounds, normal settlement | 600 + 0 seconds |
| 70 combat rounds, normal settlement | 700 + 0 seconds |
| Five rounds + verified **pursuit** close + separate exploration turn | 50 + 0 + 600 = **650 seconds** |

The last arithmetic case is *not* a normally concluded battle. Other rule profiles must provide explicit positive integer durations and source labels; a synthetic alternate is exercised in tests.

## Excluded and deferred work

No real-world/wall time; configurable world-calendar display, travel/week/downtime skipping, mid-skip event scheduler, expired status effects, SQL/Bookkeeper storage, combat status mutation, global multi-party orchestration, user interface, or live Combat integration. DES-006.5 consumes verified receipts for condition handling in a separate story. The existing Combat Engine's initiative/phase/HP logic is untouched.

## Verification

Local standalone source-compatible fixture on Python 3.13/Linux (not a full checkout of AIDM):

```bash
python -m pytest aidm/timekeeping/test -q --cov=aidm.timekeeping --cov-branch
# 21 passed; new timekeeping package 93% branch-aware coverage
```

The standalone test environment does **not** establish the full AIDM merged-main regression, Windows Python 3.12 compatibility, combined application >=90% coverage, or JavaScript/browser TAP. Required PEQUOD source-matched checks before Technical Story closure:

```bash
# In C:/Development/aidm; preserve local Database files.
git fetch origin
git switch costa
git pull --ff-only origin costa
git status --short
git rev-parse HEAD
python -m pytest aidm/timekeeping/test -q
python -m aidm.test_runner
python_exit=$?
node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs
node_exit=$?
printf 'PYTHON_EXIT=%s NODE_EXIT=%s\n' "$python_exit" "$node_exit"
git rev-parse HEAD
git status --short
```

On a worktree conflict, avoid force switching or rebasing a shared persistent branch; instead run tests from a clean new detached worktree at the specific commit. Obtain source SHA, canonical run ID/JUnit counts, measured coverage and Node exit before declaring T15 PASS. No completed whole-repository regression or BON UAT is claimed.

**Development class:** Technical, so developer tests and source receipt → Complete/assigned ALEK; no independent BON Functional UAT. Owner must confirm actual development time before closure.