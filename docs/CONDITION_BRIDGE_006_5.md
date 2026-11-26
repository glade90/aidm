# AIDM-DES-006.5 — Trusted Combat Condition Bridge (first increment)

**COSTA | Functional Build | Sprint 3 | 26 November 2026**

## Purpose and implemented scope

The new aidm/combat/condition_bridge.py connects a non-authoritative typed
condition proposal to an independently verified, trusted rules result; only
then may DES-006.4 ConditionStateService change a condition. Verified
DES-017.2.1 GameClock receipts can drive rule-certified expiry exactly once.
No second mutable actor/HP store, model-controlled rule, or world clock is added.

The current CombatSessionService handles deterministic melee but does not
yet emit verified poison, nausea or Sleep spell effect events. The positive
tests use explicitly **synthetic approved rule-effect facts** to demonstrate
the integration seam. This does NOT demonstrate any published Mentzer status
mechanics, successful poison attack, Sleep spell, healing or condition immunity.

## Proposed intent versus authoritative outcome

- ConditionChangeProposal: actor, code, operation, source completion event ID,
  expected actor condition-version, action and correlation IDs, rule reference
  and privately retained original player utterance. It cannot author expiry
  dates or instance identity.
- RuleEventSource: trusted injected server-side rules/Combat event provider.
  It may return VerifiedConditionEffect ONLY after the deterministic engine
  validates target, phase, source rule and legal effect/result. This source
  must never be sourced from raw LLM/browser JSON. The first tests use a
  scripted verified fixture; a production rules-event producer is NOT built.
- CombatConditionBridge: requires that the source result exactly matches the
  proposal, mints ConditionEventAuthority evidence, delegates typed APPLY/
  REMOVE to DES-006.4 and emits a player-safe projection. Rejected proposals
  are non-mutating. The model cannot write HP, arbitrary statuses or timers.
- ConditionBridgeResult: SERVER-INTERNAL. Only player_safe_message and
  player_safe_codes may be exposed to the Dungeon Master/Meta. Do not
  serialise private original utterance or source-rule details to browser.

## Single authoritative game-time source

on_clock_advance accepts only the original immutable ClockAdvanceReceipt
held in the same GameClock action ledger, then calls DES-006.4 process_due.
The State Engine handles exactly-once expiry, version checks and stable
instance identity; the clock does not cure statuses or change actor data.
Indefinite conditions never expire by inference. reconcile_clock replays
verified unseen clock receipts in order after a handoff. Direct live service
subscription still requires Combat/Expedition composition wiring and is
not represented as completed by this first developer slice.

## Functional acceptance matrix and open gates

| Test | First technical demonstration | Remaining full acceptance |
|---|---|---|
| F01 | Typed model suggestion without mutation authority; private input trace | BON final provider/tool interface approval |
| F02 | Unverified/mismatched facts blocked; synthetic verified facts allowed | Source-backed production rule/effect event provider |
| F03 | PC/Orc condition isolation, receipt and player-safe status | Live Combat Agent to Engine to DM/Meta gameplay integration |
| F04 | Authentic GameClock receipt expiry once; distinct deadlines, indefinite | Live shared-clock subscription in ordinary gameplay |
| F05 | Scripted synthetic model proposal/clock and negative replay cases | Provider-backed demo if feasible; source-backed scenario |
| F06 | Offline developer tests added | Full PEQUOD test receipt, BON independent Functional UAT, ALEK acceptance |

The authoritative Story F01–F06 in Airtable remains PROVISIONAL pending
BON/owner interface, use-case and time/iteration decisions; no Functional
UAT has happened. DES-004.2's BON UAT also remains distinct. Six-spell,
monster-source nuances and saves belong to DES-006.3, 001.7.4 and 001.7.3.
Never claim full poison or Sleep spell is playable merely from typed flags.
No SQL/world-event scheduler in this Story.

## Run on PEQUOD before developer handoff

Run against the actual GitHub costa SHA in a NEW detached worktree:

~~~bash
cd /c/Development/aidm
git fetch origin
git worktree add --detach ../aidm-0065-check origin/costa
cd ../aidm-0065-check
git rev-parse HEAD
git status --short
python -m pytest aidm/combat/test/test_condition_bridge.py -q
focused_exit=$?
python -m aidm.test_runner
python_exit=$?
node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs
node_exit=$?
printf 'FOCUSED=%s PYTHON=%s NODE=%s\n' "$focused_exit" "$python_exit" "$node_exit"
git rev-parse HEAD
git status --short
~~~

The clean source SHA, canonical run ID, JUnit total, exact covered/valid
line count, enforced >=90% gate and independent Node TAP result must be
recorded. This story must remain In Progress until the missing integration
and BON Functional UAT gates are satisfied. Current owner actual time and
Sprint allowance have NOT been confirmed.
