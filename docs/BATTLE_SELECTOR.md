# AIDM-DES-001.7.1 — Select Battle, first increment

Status: DAVOS developer BUILD/TEST in Sprint 3 Iteration 3.1. This is **not** full B1 selector acceptance and **not** BON functional UAT.

## Aim and boundaries

The browser test/admin prototype offers a keyboard-accessible **Select Battle** button and a choice of fixture. The first playable candidate is the existing owner-approved synthetic 3-v-3 encounter (Alho, Evro, Sho versus three orcs). Its canonical source fixture identifier is `owner-canonical-3v3-fixture-v1`. It uses the existing deterministic Python CombatEngine, approved house-rule overlay and optional independent live LLM intent/narration. Selection itself cannot change mechanics, HP, dice or an active session.

The UI also inventories **39 B1 source entry IDs** without inferring species composition or combat statistics: six upper wandering `b1.upper.wandering.01..06`, six lower wandering `b1.lower.wandering.01..06`, 25 optional stock entries `b1.stock.01..25`, and `b1.room.r53`/`b1.room.r54`. They are explicitly **UNSUPPORTED** in the current source, and their options are disabled. These are identifiers/placeholder labels only; they are *not* the module's verified roster, player-facing adventure content or authoritative combat fixtures. The actual B1 source matrix will be supplied by AIDM-DES-001.7.12. The eligible database scenario/test-case provider (AIDM-DES-001.7.9) is not built here; browser and CombatEngine do not access SQL.

## Trusted request/response boundary

The existing POST `/api/turn` accepts an optional typed `fixture_id` ONLY on combat `START` and `RESET`. Omitting it preserves the legacy default 3-v-3 behaviour. The fixture registry currently allows **only** the exact approved synthetic identifier. An arbitrary B1 code or an incomplete Test.MonsterTestScenario code is blocked at the server *before* constructing a new encounter or consuming dice; the browser's disabled options are a convenience, not security. `ACTION` and `VIEW_LOG` reject fixture selection fields (422). `START` remains idempotent for the active encounter, and `RESET` requires a matching server-issued encounter ID and replaces only that session's engine/HP/RNG/journal/action ledger. Wrong or unsupported selection during reset leaves the existing encounter untouched.

The typed player-safe combat view may include `fixture_id`, `fixture_label` and `fixture_status`. It reports `TEST_ONLY` for the synthetic 3-v-3. It never projects B1 secrets, hidden monster HP/AC or unsupported abilities. The client displays the server's verified fixture label using `textContent`. It does not construct a monster roster or calculate attacks.

The `Select Battle` control only expands/collapses the fixture picker; it does not issue a combat request. `Start selected battle` submits the selected fixture via existing Meta. `Reset selected battle` prompts for confirmation and, on acceptance, uses the same verified RESET flow already used by the browser. On an uncertain or failed reset, the previous log and transcript are preserved; stale-action/replay protections remain in the service. No new HTTP endpoint or Web→Combat bypass is introduced.

## Test coverage and acceptance boundaries

New source-colocated tests cover: known synthetic START, idempotent START and fresh RESET, server view source labels, all representative B1 upper/lower/stock/exceptional IDs and specified test scenarios blocked, unsupported RESET not mutating an existing encounter, forbidden `fixture_id` on ACTION/VIEW_LOG, 39 visually disabled placeholders, only the Meta endpoint receiving browser requests, selector expansion, reset confirmation/cancellation and preservation of the baseline 3-v-3. Existing Python/Node suites remain the main regression oracle.

The isolated JavaScript V8 harness runs directly fetched latest source/tests but is **not** the required real PEQUOD Node CLI or full Python regression. Before developer acceptance, run from the precise DAVOS SHA on PEQUOD:

```bash
git switch davos
git pull --ff-only origin davos
git rev-parse HEAD
git status --porcelain
python -m pytest aidm/combat/test/test_combat_session.py aidm/web/test/test_web_chat.py -q
python -m aidm.test_runner
node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs
```

Record exact SHA, clean/dirty status, Python JUnit counts, measured >=90% coverage gate, full runner report directory and Node totals. Then perform a real browser walkthrough: select/test synthetic 3-v-3, verify real engine effects, reset, reject invalid fixtures, ensure text-only and keyboard operation, confirm no spoiler disclosure. BON functional UAT within the sprint iteration follows developer evidence.

## Explicitly deferred

- **AIDM-DES-001.7.12:** verified B1 39-source-entry matrix, precise source variants, roster, counts, HP and rules eligibility.
- **AIDM-DES-001.7.9:** validated read-only `[Test].[MonsterTestScenario]`/`[Test].[MonsterTestCase]` provider; `ReadyForExecution=0` must block execution.
- Rules-backed special monster actions, B1 Room 53/54 behaviours, movement, spell effects, source-complete lower/upper/stock scenario execution and artwork.
- No full AIDM-DES-001.7.1 completion or release readiness is claimed until at least two distinct genuinely READY B1 scenarios and their applicable test/provider/Combat mechanics satisfy the independently defined BON UAT.
