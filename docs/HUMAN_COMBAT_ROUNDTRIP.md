# AIDM-DES-025.2 — Human-driven combat through the existing HTML chat

**Story:** AIDM-DES-025.2 · **Class:** Functional · **DAVOS:** Sprint 2 Iteration 2.3 BUILD/TEST · **BON:** independent integrated Functional UAT in Iteration 2.4 (NOT 2.END).

**Source design:** BON AIDM-INT-COMBAT-001 v0.2, tests U01–U13, joint DES-001.2/025.2 acceptance. This is a first, in-memory, **real deterministic melee** integration using COSTA's merged source-backed CombatEngine. It is neither a full Mentzer ruleset nor the persistent Bookkeeper.

## Launch without API keys

From repo root:

```bash
python -m pip install -r requirements-dev.txt
python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
```

Open **http://127.0.0.1:8000/chat**, click **Start 3 vs 3 combat**, and follow the explicit human prompt. The first actor is determined by the actual combat controller, not assumed from button order. A legitimate example is:

- **Alho** when prompted: `HOLD` or `Alho attacks Orc 1 with his flail`
- **Sho-Rembo** when prompted: `HOLD` or `Sho attacks Orc 2`

When a human is prompted to pick a melee target, the conservative offline
intent interpreter also accepts **`Orc 1`**, **`1`**, **`Orc 2`** or
**`2`** as an attack against that *single currently legal visible target*.
Those are not global commands: they only mean "attack that target" at a
server-verified human melee decision. Unknown/dead/ambiguous targets safely ask
for clarification; they never trigger an unvalidated attack. `HOLD` is the
explicit non-attack action.

Evro (retainer) and visible orcs receive conservative **scripted agent intentions** when it is their turn, always subject to COSTA's real target/rule validation. On each human response, the controller can advance multiple agent turns or a whole round, then stops for the next human. One message is **not** assumed to equal a full round.

The Dungeon Master summarises **verified hits, misses, holds, casualties and outcomes**, and separately asks for the next decision; it no longer responds with a content-free 'Combat action accepted'. The browser displays current **player-party HP** (including a visible 'down' label at 0 HP), the DM message and **Combat journal** (player-safe ordered events, initiative/phase status, raw d20/damage faces and source-applied modifiers, own party HP at terminal). **View full combat log** is read-only. A new browser tab has a fresh ephemeral session; server restart wipes encounter-local state. No new HTTP endpoint or second server has been introduced.

The prior message-only example `I swing my sword at the orc.` still returns the old **SIMULATED** stub narrative when no structured combat session has been started. In active combat the same input is not necessarily legal until a specific human is prompted and a target is identified. Do not mistake old simulated text for real rolled combat.

## Actual architecture

```text
HTML /chat → ChatApiClient → existing Meta POST /api/turn
    TurnRequest.combat {START | ACTION | VIEW_LOG, ...}
    ↓ existing typed InternalRequest
    DungeonMasterAgent(Braider) — trusted child request, no DM model dice
    ↓ capability=combat / operation=combat_turn
    CombatSessionService — session isolation, token/version/action ID/replay guard
    ↓ CombatCommand — the only mutation interface
    COSTA CombatEngine — verified source-backed hit tables/rule profiles,
        initiative, raw selected Die, modifiers, HP, phases, terminal,
        ordered private journal, player-view projection
    ↑ trusted result with STRICTLY public combat_view and safe DM message
    ↑ Meta allowlisted Pydantic TurnResponse.combat
    ↑ browser textContent (no raw HTML or direct Combat API)
```

**Modules:**
- `aidm/combat/session.py`: one in-memory CombatEngine per session, trusted canonical 3v3 construction, selected dice source, exclusive session locks, independent client action IDs, exact pending decision tokens, version gating, agent turns and redacted chronological public log.
- `aidm/combat/live_policy.py`: optional live Responses API policy for **intention and narration only**; injected model has no rule authority, no hidden monster data, never chooses HP/dice and cannot call CombatEngine. No provider calls when disabled. This is **not** the main DM agent/persistent intelligence; the DM gateway remains the single player-facing service.
- `aidm/meta/turn.py`: extends the accepted Pydantic request/response additively with optional `combat`; old message-only request remains valid. Rejects forbidden extra fields. Exposes a narrow `PlayerCombatView`; never serialises private combat journal fields or `CommittedEffects`.
- `aidm/dm/agent.py`: typed optional delegation to the injected session service and safe reply re-enveloping while retaining DES-015.2 legacy simulated stub.
- `aidm/web/app.py`: same Meta FastAPI app + injected real CombatSessionService; retains old `combat` stub, now also registers `combat_session`.
- `aidm/web/static/`: two controls, one player-safe journal, existing chat Send / Enter / Shift+Enter; one in-page session ID; fresh correlation ID and action ID each turn; fail-closed reply correlation; no blind retry after uncertain ACTION.
- `aidm/combat/test/test_combat_session.py`: source-backed 2-round fixed-roll oracles, 3v3, raw Evro 12+3 hit and 5+3 damage, victory, source field redaction, replay/stale/invalid, two session isolation, readonly log, unsupported flail/morale and fake LLM.
- `aidm/web/test/combat_client.test.mjs`: no-network Node built-in tests of START/ACTION/VIEW_LOG, terminal guard, timeout reconciliation, safe text-only log.
- Existing `aidm/web/test/chat_client.test.mjs` and old Python tests remain regression tests for message-only chat.

## Request/response examples

Both are **POST /api/turn** using the existing Meta service:

```json
{
  "session_id": "one-browser-session",
  "correlation_id": "init-001",
  "combat": {"kind": "START"}
}
```

Returned `combat` (only approved player fields) includes `encounter_id`, `state_version`, `current_round`, `phase_label`, `terminal`, `outcome`, `next_decision` with opaque token and legal visible targets, `new_log_entries`, `log_next_cursor`, optional party survivor HP and explicit deferred labels. `status=NEEDS_PLAYER_INPUT` when a human decision is due; it does **not** mean a rules error.

Once the UI receives the server's decision it submits an **ACTION** with a message and matching encounter, actor, token, version, generated action ID and existing cursor. The browser never invents a die, player HP, modifiers or target authority: even when a model suggests an attack, Python CombatEngine decides legality, consumes the selected die, and commits the encounter-local HP/event transition. A stale version/duplicate action is **BLOCKED** without an additional roll. A failed or timed-out action can be **indeterminate** because Meta uses `asyncio.to_thread`; the client must inspect `VIEW_LOG` before any deliberate retry. `VIEW_LOG` never advances a round, consumes RNG or invokes the model.

## Optional live LLM demonstration (required for final BON integrated UAT)

Default mode is **offline**, with `ScriptedIntentPolicy` and `SystemRandomSource` (the actual Python engine rolls, not a fixed combat script). Offline automated tests use `FixedRollSource` and a mock LLM policy to reproduce deterministic two-round outcomes without secret, network or expense.

To opt in to a **real** LLM on PEQUOD, set the following environment values *before starting Uvicorn*, using a separately provisioned OpenAI API key and a model identifier supported by your account:

```bash
export AIDM_LIVE_LLM=1
export AIDM_LLM_MODEL="<your supported model ID>"
read -rs -p "OPENAI_API_KEY: " OPENAI_API_KEY; echo
export OPENAI_API_KEY
python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
```

The browser does not receive the key. The opt-in adapter calls the OpenAI **Responses API** and uses the live model to interpret the **human's natural-language** intention into a *proposal* and produce a **labelled non-authoritative** narration from verified public events. COSTA's deterministic Python controller remains the exclusive rules, dice, HP and outcome authority; Evro/orc intentions currently use a conservative non-LLM scripted policy. A model outage returns a safe status without silently submitting an action, and no automatic model/tool retries are performed. Tokens/latency may incur API charges and Meta's request timeout may need an explicitly approved longer value for a live demo.

**This code does not constitute an actual live-provider test.** BON must complete at least one whole real encounter with an actual connected LLM and independently verify the JSON/log/results during Iteration 2.4. A fake-model pytest result is NOT that UAT evidence.

## Tests

```bash
python -m pytest aidm/combat/test/test_combat_session.py aidm/web/test/test_web_chat.py aidm/dm/test/test_dm_agent.py -q
python -m aidm.test_runner
node --test aidm/web/test/chat_client.test.mjs aidm/web/test/combat_client.test.mjs
```

Report source SHA, clean/dirty status, full JUnit counts, exact line coverage, runner exit code, Node outcome separately and any browser observations. The Python >=90% full-application gate is required. Browser acceptance is separate from pytest/Node.

## Specific limitations / technical debt

1. **In-memory only**: per-browser transient sessions do not have authenticated user identity, state persistence across restart, replayable global Bookkeeper receipt or database-backed Adventure/Expedition context. Encounter IDs are opaque capabilities but not a substitute for authentication; local loopback use only.
2. **Confirmed house rule**: only owner-approved flail overlay `HR-WEAPON-FLAIL-001` v1.0 (1d6 base damage) is applied; other flail mechanics are not invented. Provisional plate/shields are honoured only through the explicitly confirmed canonical fixture profile. Flail without overlay and due morale are negative tests.
3. **Bounded first rules slice**: stationary low-level melee with previously supplied synthetic no-surprise input. Missile, magic, movement, polearms, monster special attacks and enabled due morale remain visibly deferred/blocked, not falsely completed 1983 Mentzer rules. The temporary data/reference provider `TD-AIDM-DATA-001` precedes the future rules/character/monster DB and Adventure/Expedition engines.
4. **Transient status**: active encounter commands are serialised under per-session locks. An HTTP timeout never asserts rollback; log reconciliation and version/token checks prevent ordinary retry effects. Neither JSONL audit nor local HP substitutes for future Bookkeeper authority.
5. **Game narrative**: only the actual CombatEngine journal/result determines game facts. The optional model's text is explicitly secondary; the player-facing DM does not own LLM memory or free-form exploration at this stage.
6. **Capacity**: original 1.33h story estimate is provisional/high risk; actual developer time must be Owner-confirmed, BON UAT actual separately added, and ALEK reconciles Sprint 2 capacity/transition.

**Handoff:** DAVOS developer BUILD/TEST (Iteration 2.3) → merge → BON one independent *joint* DES-001.2 + DES-025.2 Functional UAT (Iteration 2.4) → Complete/ALEK only after acceptance and owner-confirmed total actual. 2.END is release-only.

### Owner browser walkthrough corrections — 20 November 2026

Owner's first PEQUOD 3v3 walkthrough verified actual side initiative, Orc attacks, Alho/Sho turns and third-round progression, but revealed three usability defects now addressed in this same draft PR: (1) the initial static notice incorrectly described **all** chat as simulated; (2) the DM simply answered 'Combat action accepted' while rules-resolved attacks occurred in a separate journal; (3) the offline parser accepted full `Alho attacks Orc 1` but rejected `Orc 1` and `1` after a specific pending target prompt. A reported Orc-first round applied 6 + 3 damage to Evro's 8 HP, legitimately incapacitating him before his agent turn. The UI now shows party HP throughout, and the public log/DM reports his fall. All public output derives from COSTA's engine: no synthetic successful roll, undeclared death mechanic or hidden opponent HP.

**Regression:** `test_offline_target_shorthand_only_uses_pending_visible_target`, invalid/ambiguous shorthand, in-process HTTP shorthand→real combat, and an exact fixed-dice Orc-first Evro-0-HP fixture. Browser/Node test verifies safe live party HP and down label. Full PEQUOD source-matched Python/Node regression needs to be repeated after this correction; prior PASS receipts pertain to the preceding SHA.

### Second owner browser walkthrough — visible Orc defeated and model transparency

Owner verified a real random-roll encounter in which Alho hit Orc 1 for 4,
Evro hit Orc 1 for another 4 and the orc disappeared from subsequent
eligible-target prompts without an explicit defeat announcement. The engine
correctly set its HP to zero, but the DM/public event projector only labelled
**party** casualties. In the same pending human decision, `IS orc 1 dead?`
was treated as an invalid attack instead of a question. Both are repaired in
the typed `CombatSessionService` layer without changing COSTA's combat rules:
a **visible** opponent going from positive HP to zero now causes the public
melee event and DM summary to say `Orc 1 falls`; a narrow query such as
`Is Orc 1 dead?` or `Is Orc 2 still alive?` returns the engine's
player-visible `defeated` flag as `down and out of the fight` or
`still in the fight`. These questions **never** consume the pending
human action, dice, version or journal events, and do not call the optional
LLM. An attack against Orc 1 after defeat gives an explicit `already down`
response listing **only currently valid targets**, never an obsolete
suggestion. The engine currently records `defeated`/zero HP, not a distinct
authoritative `dead versus unconscious` state; the UI therefore does not
invent that ruling or reveal opponents' exact HP.

The browser now shows an honest `intent_mode` marker. **OFFLINE_SCRIPTED**
(default) means **zero live model API calls** in the typed combat path:
human text uses a small rule-based parser, Evro/orcs use explicitly scripted
target intentions, and the DM's prose is a deterministic rendering of
source-verified events. **Dice are still genuinely random**, drawn from the
engine's `SystemRandomSource`, unless tests inject fixed faces. A separate
**LIVE_LLM** mode is enabled only by the explicit environment flag
`AIDM_LIVE_LLM=1` with a configured `AIDM_LLM_MODEL` and
`OPENAI_API_KEY`. This currently calls the model only to propose **human
intents** and narrate safe events, not to choose Evro/orc tactics or own
combat rules. The browser label signals a configured integration, not
proof of a successful paid provider call.

**PowerShell example**, from a local development session (do not commit
the key or paste it into a chat):

```powershell
$env:AIDM_LIVE_LLM = "1"
$env:AIDM_LLM_MODEL = "<supported OpenAI model ID>"
$secret = Read-Host -AsSecureString "OpenAI API key"
$env:OPENAI_API_KEY = [System.Net.NetworkCredential]::new("", $secret).Password
python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
# Afterwards:
Remove-Item Env:OPENAI_API_KEY
Remove-Item Env:AIDM_LIVE_LLM
```

The provider requires network access and may incur charges. The complete
live LLM end-to-end encounter is **BON Iteration 2.4 UAT**; until explicitly
observed, no one should claim the actual provider call passed. Regression
tests cover (1) fixed-faces Alho 4 + Evro 4 defeat, (2) read-only question,
(3) no dice/HP/journal change, (4) exact visible target only and (5) no
private foe HP/AC exposed.

### Combat status emojis (display-only; verified 21 November 2026)

The same verified source-backed event that drives the log now supplies a strict,
optional `CombatLogView.cue` enum. The DM turns eligible verified event cues
into concise emoji-prefixed sentences; the browser renders the **same cues** in
the player-safe journal using `textContent`, never an HTML fragment. No model
can set a cue or claim a hit without a corresponding validated engine event.

| Icon | Combat meaning | Cued by |
| --- | --- | --- |
| ⚔️ | Hit | Controller's source-resolved `MELEE_RESOLVED.hit = true` |
| 💨 | Miss | Controller's source-resolved `MELEE_RESOLVED.hit = false` |
| 💀 | Falls / defeated / incapacitated | Visible foe or party member HP crosses positive to zero |
| ✋ | Hold | Valid controller `ACTION_HELD` |
| 🔄 | Round change | Controller `ROUND_STARTED` / `ROUND_COMPLETED` |
| 🎲 | Initiative | Controller `SIDE_INITIATIVE` |
| 🏆 | Party victory | Controller `ENCOUNTER_TERMINAL: PARTY_VICTORY` |
| 💔 | Party defeat | Controller `ENCOUNTER_TERMINAL: PARTY_DEFEAT` |
| 🏁 | Other terminal outcome | Controller `ENCOUNTER_TERMINAL` without a resolved win/loss |

**Crucially, 💀 means out of the fight, NOT necessarily dead**: the current
engine does not support an independent death/unconsciousness determination.
An attack that deals damage but does not cause a fall remains ⚔️. A hit
reducing a combatant to zero is 💀 in preference to ⚔️ (the original damage
sentence is retained). Metadata includes no private monster HP or AC.
Unknown/untrusted cues fail the typed HTTP boundary and are never interpreted
as raw HTML. Emoji-free existing textual narrative and raw die breakdown
remain in the log, so emojis are optional visual shorthand only.

Tests verify strict cue enum, actual fixed-dice hit/miss/fall/hold/victory
events, and text-safe journal rendering with malformed cues. The actual
PEQUOD full runner and Node CLI must be repeated for this latest draft head
before developer sign-off; prior clean runs refer to earlier commits.

### Tied initiative: simultaneous defeat attribution (21 November 2026)

Owner reported a false contradiction in the combat journal:
`💀 R1 · MELEE: Alho misses Orc 1. Orc 1 falls | d20 2 + 0 = 2`.
Root cause was **projection**, not a missed attack calculating damage.
COSTA's `CombatEngine._resolve_simultaneous` correctly aggregates all
eligible attacks in a tied initiative exchange, applies one final HP commit,
then deliberately records the **same** `hp_before`/`hp_after` per target
on **each** related `MELEE_RESOLVED` event, including a miss with damage 0.
The initial DAVOS public event projector mistook that per-target aggregate
HP transition as the attributable outcome of Alho's particular miss. The
bad projection attached both the text `Orc 1 falls` and 💀 to the missed
attack; the underlying attack roll/damage were unchanged.

Corrected behavior:
- Individual tied-instead-of-normal melee events report only their own
  engine-verified hit/miss and damage: a miss is always 💨.
- Validated positive-to-zero aggregate HP casualties are collected from
  real positive-damage hits, then reported **once** on
  `SIMULTANEOUS_EXCHANGE_COMMITTED` as 💀 `Simultaneous exchange
  resolves. Orc 1 falls`; there is no unverified personal kill credit.
- The journal cursor implementation also processes earlier events for
  aggregation before applying the displayed cursor, so the full and
  incremental player-safe journals agree without duplicate kills.
- Ordinary non-simultaneous landed lethal attacks continue to report
  the fall directly on that hit.

`test_tied_initiative_miss_does_not_take_credit_for_simultaneous_defeat`
uses source-backed fixed faces for tied initiative, Alho d20=2 miss,
Evro d20=12/d8=5 hit, and Orc 1's 6-HP defeat, asserting no fall on
Alho's miss, exactly one fall on the source-backed exchange commit,
correct DM text and no leaked private HP/AC. The owner must rerun
source-matched PEQUOD tests and the browser on the latest SHA to certify
this correction.


### Third browser UX refinement — initiative clarity, multiline DM, and tailing scroll (21 November 2026)

Owner identified three usability issues:
1. Generic 'Round X: side initiative rolled' does not identify which side acts first, particularly on tied rounds.
2. The DM combat reply concatenated many events into one long paragraph.
3. Scrollbars did not automatically tail new messages.

The combat session's public SIDE_INITIATIVE projector now reads only actual engine-owned faces_by_side for the two approved combat sides. It announces each side's numeric d6 result and Party wins and acts first, Orcs win and act first, or Initiative tied — both sides act simultaneously. This is only a public display projection: the engine remains authoritative for initiative, side order and simultaneous damage. Both the full journal and DM's response contain the source-backed result.

The DM narration now renders each verified action/event on a separate line, including round-start and initiative lines, with a blank line before a new round. The existing CSS .message p { white-space: pre-wrap; } displays the actual newline characters and preserves the player decision prompt. Nothing is inserted as raw HTML.

The transcript's scrollable element is .chat-panel; the combat journal's is .combat-board. Previously the JS assigned scrollTop to their inner non-scrolling ordered lists. The UI now sets scrollTop = scrollHeight on the correct parent after appending player/DM messages or fresh journal events. This deliberately follows new messages to the tail, per owner request.

Added Python fixed-dice tests for party initiative win, orc initiative win, tied initiative, and round-two initiative text/carriage returns. Expanded offline JS DOM tests verify newlines remain in textContent and both actual scrollbar containers tail after new replies. Latest source-matched PEQUOD Python/Node full regression and manual browser verification remain required.


### Reset combat control (21 November 2026)

The HTML prototype now has a **Reset combat** button next to Start and View Log. It is disabled until a combat session exists and while a request is pending. Reset is a typed control request through the existing same-origin POST /api/turn, never a new endpoint. It includes the current opaque encounter ID (but no player action, dice, hit/HP values or user rules).

The CombatSessionService RESET handler checks the current session and exact active encounter ID under the same lock used for ACTION. A successful RESET creates an entirely fresh canonical 3-v-3 CombatEngine, independently seeded dice source, encounter UUID, zeroed version/action-ID ledger, full starting HP, fresh round 1 initiative and fresh event journal. It replaces only the current session's active encounter. Stale RESET/ACTION/VIEW_LOG requests using an old encounter ID are blocked without touching the new combat. START remains idempotent: only explicit RESET replaces an existing match.

Only after a confirmed new encounter ID does the browser clear the old transcript, old journal, last outcome, typed-but-unsent message and view cursor. It then shows the fresh DM opening and round-1 events and resumes tailing both scrollbars. Failure or indeterminate RESET response must NOT clear the old display. An uncertain network reset blocks subsequent combat ACTIONs until START re-synchronises with the server's current encounter. Reset is a prototype convenience, not Bookkeeper persistence, resurrection or an undo of any external world event.

Python tests exercise reset while active, fresh HP/engine/roll source/log/ID, cross-session isolation, repeated/stale/wrong-ID reset rejection, stale action failure, and a clean reset after party victory. Offline JavaScript tests verify the typed network route, identity and correlation, timeout recovery, and the browser control preserving old display on failure then clearing it on confirmed new encounter. Source-matched PEQUOD pytest/standard runner/standalone Node and manual browser acceptance remain required.


### Reset test correction — 21 November 2026

PEQUOD focused pytest reported 46 passed / 1 failed in test_reset_creates_new_canonical_engine_while_preserving_session_identity. The test incorrectly expected the new decision_token string always to differ from the previous encounter. COSTA's deterministic CombatEngine token is derived from session ID, round, version, event count and actor, which can be identical immediately after RESET. This is not a proof of stale ACTION acceptance: Meta / CombatSessionService requires and verifies the *current encounter_id* before accepting a decision, so an old encounter ID is rejected even if the token text happens to recur. The test now checks that the new decision token exists and relies on the separate stale-action regression to prove encounter isolation. Production rules, dice and state transitions were not modified; the reset code docstring was clarified. Owner must repeat source-matched focused pytest and full runner before signing off. No latest-head PASS claimed.


### Live LLM configuration through root .env (21 November 2026)

Earlier builds read AIDM_LIVE_LLM and AIDM_LLM_MODEL directly from os.environ, so putting them only in the local developer .env silently left the application offline. The corrected code loads both public live settings through COSTA's validated load_config, which uses .env in development mode with process-environment precedence. Only when live mode is enabled does the FastAPI factory explicitly load the OPENAI_API_KEY secret; no credentials are read at module import and there is no network call until a live intent/narration request is performed.

Create a Git-ignored file C:\Development\aidm\.env, containing for example:

    AIDM_LIVE_LLM=1
    AIDM_LLM_MODEL=gpt-4.1-mini
    OPENAI_API_KEY=<your privately supplied OpenAI API key>

Launch Uvicorn with the current working directory at C:\Development\aidm and AIDM_MODE=development (the default when CI is false). Explicit process environment variables take precedence over .env, so an older shell AIDM_LIVE_LLM=0 will deliberately keep scripted mode. Test, CI and production mode ignore local .env. Never commit the real key; .gitignore already excludes .env. Restart Uvicorn after edits and start/reset an encounter; the status should report Live LLM enabled. This indicates selected policy, not proof of a successful provider call. The actual live OpenAI provider encounter and error handling still need independent UAT.

To inspect *nonsecret* loaded settings without displaying the credential, run from repo root:

    python -c "from aidm.config import load_config; c=load_config(required_secrets=('OPENAI_API_KEY',)); print('live=', c.live_llm, 'model=', c.llm_model, 'key_present=', bool(c.get_secret('OPENAI_API_KEY')))"

Regression tests in aidm/web/test/test_web_chat.py use a fake OpenAIResponsesPolicy, a synthetic local .env, and an isolated temporary cwd to verify .env activates the LIVE_LLM adapter, process environment overrides win, .env cannot opt test/CI/production into paid calls, and missing secrets fail without leaking values. Tests do not make a live provider request.
