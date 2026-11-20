/* AIDM-DES-025.2 — offline Node tests for the additional typed combat UI.
 * Usage: node --test aidm/web/test/combat_client.test.mjs
 * No provider, browser, server, npm dependency or real network.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { ChatApiClient } from "../static/client.mjs";
import { mountChat } from "../static/chat.mjs";

const ids = () => {
  let n = 0;
  return (prefix) => `${prefix}-${++n}`;
};

function view(version = 0, { terminal = false, cursor = 4, events = [] } = {}) {
  return {
    encounter_id: "enc-approved-one",
    state_version: version,
    current_round: terminal ? 2 : 1,
    phase_label: terminal ? "TERMINAL" : "MELEE",
    terminal, outcome: terminal ? "PARTY_VICTORY" : null,
    awaiting_player: !terminal,
    next_decision: terminal ? null : {
      actor_id: "alho", prompt: "Alho: attack Orc 1 or HOLD",
      decision_token: `session-1:r1:v${version}:s3:alho`,
      allowed_targets: ["orc-01"],
    },
    new_log_entries: events,
    log_next_cursor: cursor,
    surviving_party_summary: terminal
      ? [{ actor_id: "alho", name: "Alho", hp_current: 8, hp_max: 8 }] : null,
    deferred_labels: ["Magic deferred"],
  };
}

function fakeReply(request, combat, status) {
  return {
    status: status === "ERROR" ? 504 : 200,
    ok: status !== "ERROR",
    json: async () => ({
      status, message: status === "ERROR"
        ? "The outcome is uncertain; inspect log before retry."
        : "Combat state from deterministic engine.",
      session_id: request.session_id, correlation_id: request.correlation_id,
      simulated: false, combat,
      error: status === "ERROR" ? {
        code: "TIMEOUT", message: "Outcome unknown.",
      } : null,
    }),
  };
}

test("typed combat START/ACTION/VIEW_LOG all use only Meta POST; no state invented", async () => {
  const network = [];
  const fetcher = async (url, options) => {
    const data = JSON.parse(options.body);
    network.push({ url, method: options.method, data });
    const kind = data.combat.kind;
    return fakeReply(data, kind === "START" ? view() : view(1), "NEEDS_PLAYER_INPUT");
  };
  const client = new ChatApiClient({ fetcher, idFactory: ids() });
  const first = await client.startCombat();
  assert.equal(first.status, "NEEDS_PLAYER_INPUT");
  assert.equal(first.combat.next_decision.actor_id, "alho");
  assert.equal(network[0].data.combat.kind, "START");
  assert.equal(Object.hasOwn(network[0].data, "message"), false);
  assert.equal(network[0].url, "/api/turn");

  const action = await client.send("I swing my sword at Orc 1");
  assert.equal(action.status, "NEEDS_PLAYER_INPUT");
  assert.equal(network[1].data.combat.kind, "ACTION");
  assert.equal(network[1].data.message, "I swing my sword at Orc 1");
  assert.equal(network[1].data.combat.actor_id, "alho");
  assert.equal(network[1].data.combat.decision_token, view().next_decision.decision_token);
  assert.equal(network[1].data.combat.expected_encounter_version, 0);
  assert.equal(network[1].data.combat.client_action_id, "action-3");
  assert.equal(network[1].data.combat.log_since_sequence, 4);

  const whole = await client.viewCombatLog();
  assert.equal(whole.status, "NEEDS_PLAYER_INPUT");
  assert.equal(network[2].data.combat.kind, "VIEW_LOG");
  assert.equal(network[2].data.combat.log_since_sequence, 0);
  assert.equal(Object.hasOwn(network[2].data, "message"), false);
  assert.deepEqual(network.map((entry) => entry.url),
    ["/api/turn", "/api/turn", "/api/turn"]);
  assert.deepEqual(network.map((entry) => entry.data.session_id),
    ["session-1", "session-1", "session-1"]);
  assert.equal(new Set(network.map((entry) => entry.data.correlation_id)).size, 3);
});

test("terminal combat blocks extra actions locally but permits log reading", async () => {
  let count = 0;
  const client = new ChatApiClient({
    idFactory: ids(),
    fetcher: async (url, options) => {
      count++;
      const data = JSON.parse(options.body);
      return fakeReply(data, view(9, { terminal: true, cursor: 45 }), "COMPLETED");
    },
  });
  await client.startCombat();
  const result = await client.send("attack again");
  assert.equal(result.status, "BLOCKED");
  assert.equal(count, 1, "No duplicate combat after terminal");
  assert.equal((await client.viewCombatLog()).combat.terminal, true);
  assert.equal(count, 2);
});

test("unknown timeout never retries a mutable ACTION; VIEW_LOG is allowed", async () => {
  const calls = [];
  const client = new ChatApiClient({
    idFactory: ids(),
    fetcher: async (url, options) => {
      const data = JSON.parse(options.body);
      calls.push(data);
      const status = data.combat.kind === "ACTION" ? "ERROR" : "NEEDS_PLAYER_INPUT";
      return fakeReply(data, view(0), status);
    },
  });
  await client.startCombat();
  const uncertain = await client.send("attack Orc 1");
  assert.equal(uncertain.status, "ERROR");
  assert.equal(calls.length, 2);
  assert.equal(client.combatState.state_version, 0);
  await client.viewCombatLog();
  assert.equal(calls.length, 3);
  assert.equal(calls[2].combat.kind, "VIEW_LOG");
  assert.equal(calls.filter((x) => x.combat.kind === "ACTION").length, 1);
});

class FakeElement {
  constructor() {
    this.listeners = {}; this.children = []; this.dataset = {};
    this.value = ""; this.disabled = false; this.hidden = false;
    this.scrollHeight = 123; this.textContent = ""; this.parentElement = null;
    this.className = "";
  }
  addEventListener(kind, callback) { this.listeners[kind] = callback; }
  appendChild(child) { this.children.push(child); }
  replaceChildren() { this.children = []; }
  focus() {}
  requestSubmit() { return this.listeners.submit?.({ preventDefault() {} }); }
  set innerHTML(_) { throw new Error("UNSAFE_HTML"); }
}

function makeDom() {
  const controls = {};
  const ids = [
    "chat-form", "player-message", "send-button", "transcript",
    "service-status", "combat-start", "combat-log", "combat-status",
    "combat-board", "combat-events", "party-outcome",
  ];
  for (const key of ids) controls[key] = new FakeElement();
  controls["service-status"].parentElement = new FakeElement();
  return {
    controls,
    getElementById: (key) => controls[key],
    createElement: () => new FakeElement(),
  };
}

test("journal renders only escaped text, ordered incremental entries and terminal own HP", async () => {
  const dom = makeDom();
  let calls = 0;
  const malicious = "<img src=x onerror=alert(1)>";
  const logs = [
    { seq: 1, round: 1, phase: "MELEE", kind: "MELEE_RESOLVED",
      text: malicious, roll: { attack_face: 12, attack_modifier: 3, attack_total: 15,
        damage_face: 5, damage_modifier: 3, damage_total: 8 } },
  ];
  const client = {
    combatState: null,
    async startCombat() {
      calls++;
      this.combatState = view(1, { terminal: true, cursor: 1, events: logs });
      return { status: "COMPLETED", message: "Combat over",
               combat: this.combatState, simulated: false };
    },
  };
  mountChat({ documentRef: dom, client });
  await dom.controls["combat-start"].listeners.click();
  assert.equal(calls, 1);
  assert.equal(dom.controls["combat-board"].hidden, false);
  const journal = dom.controls["combat-events"];
  assert.equal(journal.children.length, 1);
  assert.match(journal.children[0].textContent, /d20 12 \+ 3 = 15/);
  assert.match(journal.children[0].textContent, /damage die 5 \+ 3 = 8/);
  assert.ok(journal.children[0].textContent.includes(malicious));
  assert.match(dom.controls["party-outcome"].textContent, /Alho: 8\/8 HP/);
});
