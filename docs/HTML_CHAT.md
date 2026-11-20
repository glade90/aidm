# AIDM-DES-014.1 — Local Browser Chat (Stub DM / Combat)

**Classification:** Functional · **Developer:** DAVOS · **Sprint/Iteration:** 2 / 2.2 BUILD+TEST, BON UAT in 2.3.

## What you can actually do now

Run **one** existing Meta/FastAPI application, open a small chat page, and send the approved synthetic combat phrase. The browser calls only the existing Meta `POST /api/turn`, not Combat or a new UI backend.

### Start on PEQUOD (Windows / Git Bash)

```bash
python -m pip install -r requirements-dev.txt
python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
```

Open **http://127.0.0.1:8000/chat**. Use this exact sample first:

> I swing my sword at the orc.

A successful response begins **“Simulation only: the combat intention was received”** and explicitly states that no dice were rolled, no damage was calculated and no hit points or world state changed. `BLOCKED` for unknown messages is expected in this deliberately limited prototype. Press **Ctrl+C** to stop the local server. No paid API token or `.env` is needed for the fake agents.

## Architecture and ownership

```text
Browser /chat (HTML + chat.mjs + client.mjs)
    |
    | POST /api/turn (existing endpoint; same origin)
    v
Meta Service (COSTA DES-013.1; DAVOS DES-013.2 HTTP seam)
    |
    | InternalRequest {capability=dm, operation=player_turn,
    |                  message, session_id, correlation_id}
    v
DungeonMasterAgent(Braider) (DAVOS DES-015.2)
    |
    | make_child_request: new request ID, same correlation/session,
    | original player text, trusted encounter fixture
    v
CombatAgent(Braider) (COSTA DES-004.1; injected handle method)
    |
    | InternalResult {status, safe_summary, simulated=True,
    |                 combat_resolved=False}
    v
DM stub re-envelopes against parent request ID, retaining safe text/status
    |
    v
Meta safe TurnResponse -> browser text node
```

**The browser never talks directly to Combat**, chooses an agent, interprets dice, stores HP or acts as Bookkeeper. The Meta service is the only HTTP boundary. The Combat stub makes a fake model invocation and returns an approved static summary, not an executed hit. The inherited DM Braider model is deliberately never invoked.

The factory `aidm.web.app:create_chat_app` uses the existing `aidm.meta.http.create_app` and `ServiceRegistry` and adds a local `/chat` page and `/static/*` asset mount **on the same FastAPI app**. It is an assembly/composition root, not a second server or endpoint for game actions.

### Files and why

- `aidm/web/app.py` — compose existing Meta app and injectable real stub DM/Combat, serve `/chat` and static assets; fake models/encounter are trusted synthetic startup fixtures, not player JSON fields.
- `aidm/web/static/index.html` — semantic chat transcript, textarea, Send and working indicator.
- `aidm/web/static/chat.css` — simple responsive mobile/desktop styling and focus indications.
- `aidm/web/static/client.mjs` — one isolated, mockable `POST /api/turn` fetch client; one browser-tab session ID and a new correlation ID for each turn; safe error handling and reply-ID checks.
- `aidm/web/static/chat.mjs` — DOM wiring and pending-state guard to prevent duplicate sends; ordered history; keyboard Enter/Shift+Enter; **textContent only** for player and server text. No HTML injection.
- `aidm/web/test/test_web_chat.py` — offline FastAPI TestClient exercise of actual Meta→DM→Combat chain with spy, status/ID verification, blocked/clarification/unavailable/handler error, no leaked proposals and static assets.
- `aidm/web/test/chat_client.test.mjs` — **separate** offline browser-client/DOM checks using Node's built-in `node:test`; fake `fetch`, no npm libraries, HTTP server, Combat or network.

To honour the accepted UAT text, the narrow DM fixture now recognises `I swing my sword at the orc.` as well as the prior exclamation mark or no final punctuation. It **forwards the exact message unchanged** and is *not* a general grammar parser.

### Why session IDs originate in this browser prototype

BON's original design anticipated a server-issued opaque session ID, but the accepted `TurnRequest/TurnResponse` from DES-013.2 currently **only echoes** the client's session ID. To avoid changing that approved interface during a browser-only Build, `ChatApiClient` creates a random opaque session ID once per live browser page and verifies the returned echo. Each submission gets a fresh correlation ID. These IDs do not establish authentication, persistence, a server-side session or canonical game state. Refreshing the page begins a new in-memory session. Server-issued session negotiation is deferred to a future contract change.

### Tests and verification

```bash
python -m pytest aidm/web/test/test_web_chat.py aidm/dm/test/test_dm_agent.py -q
python -m aidm.test_runner
node --test aidm/web/test/chat_client.test.mjs
```

Run the JavaScript command if Node.js is installed; it is independent of the Python test runner and **does not count toward Python coverage**. Browser manual inspection and BON independent UAT are also separate.

BON's Functional UAT A–G: open `/chat`, submit the period-ending scripted phrase; verify one browser POST to `/api/turn`, actual DM/Combat call spy and safe synthetic output; make two sequential turns with same session/different correlation; attempt unsupported/blank text, stop/restart backend after page load, verify recovery; paste markup-looking input and confirm it is *text*, not HTML; check keyboard and mobile width. Automated Python tests verify the actual contract behind the page; Node tests verify mock-fetch/DOM pending/safety. Actual human browser UAT is still required.

## Known limitations

No real DM LLM or autonomous intent selection, no combat rolls/HP or authoritative state, no conversation memory or persisted session, no login/multiplayer, no streaming or rich dice/map UI. Current stub supports only the approved synthetic combat statement; unrelated requests are safely blocked. The browser has no offline fallback after a server outage, but it remains usable and reports the error safely; restarting the local server permits another attempt. Later real Combat can replace the injected `CombatAgent.handle` behind the same DM/Meta contract without frontend changes.

**Workflow:** DAVOS developer BUILD+TEST → BON independent Functional UAT Testing in Iteration 2.3 → Complete/ALEK after BON accepts and Owner confirms combined actual hours. Never count the earlier DM-stub Technical tests as this Functional UAT.
