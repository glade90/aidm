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
