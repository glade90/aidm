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

function view(version = 0, { terminal = false, cursor = 4, events = [], encounterId = "enc-approved-one" } = {}) {
  return {
    encounter_id: encounterId,
    intent_mode: "OFFLINE_SCRIPTED",
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
    party_status: [
      { actor_id: "alho", name: "Alho", hp_current: 8, hp_max: 8 },
      { actor_id: "evro", name: "Evro", hp_current: 0, hp_max: 8 },
      { actor_id: "sho-rembo", name: "Sho-Rembo", hp_current: 7, hp_max: 9 },
    ],
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
  const blocked = await client.send("attack Orc 1");
  assert.equal(blocked.status, "BLOCKED");
  assert.match(blocked.message, /View the full combat log/i);
  assert.equal(calls.length, 2, "Do not blindly retry an uncertain action");
  await client.viewCombatLog();
  assert.equal(calls.length, 3);
  assert.equal(calls[2].combat.kind, "VIEW_LOG");
  assert.equal(calls.filter((x) => x.combat.kind === "ACTION").length, 1);
});

class FakeElement {
  constructor() {
    this.listeners = {}; this.children = []; this.dataset = {};
    this.value = ""; this.disabled = false; this.hidden = false;
    this.scrollHeight = 123; this.scrollTop = 0;
    this.textContent = ""; this.parentElement = null;
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
    "chat-form", "player-message", "send-button", "transcript", "chat-panel",
    "service-status", "combat-start", "combat-reset", "combat-log", "combat-status",
    "combat-board", "combat-events", "party-outcome", "party-status",
  ];
  for (const key of ids) controls[key] = new FakeElement();
  controls["service-status"].parentElement = new FakeElement();
  controls["transcript"].parentElement = controls["chat-panel"];
  controls["combat-events"].parentElement = controls["combat-board"];
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
      cue: "HIT", text: malicious, roll: { attack_face: 12, attack_modifier: 3, attack_total: 15,
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
  assert.match(journal.children[0].textContent, /^⚔️ R1/);
  assert.match(dom.controls["party-outcome"].textContent, /Alho: 8\/8 HP/);
  assert.match(dom.controls["party-outcome"].textContent, /^🏆 Outcome:/);
  assert.match(dom.controls["party-status"].textContent, /💀 Evro:/);
  assert.match(dom.controls["party-status"].textContent, /Evro: 0\/8 HP \(down\)/);
  assert.match(dom.controls["combat-status"].textContent, /Offline scripted intentions/);
  assert.match(dom.controls["party-status"].textContent, /Sho-Rembo: 7\/9 HP/);
});

test("miss, fall, hold, round, and victory cues render as safe text only", async () => {
  const dom = makeDom();
  const entries = [
    { seq: 1, round: 1, phase: "PRE_INITIATIVE", kind: "ROUND_STARTED", cue: "ROUND",
      text: "Round 1 begins" },
    { seq: 2, round: 1, phase: "INITIATIVE", kind: "SIDE_INITIATIVE", cue: "INITIATIVE",
      text: "Initiative rolled" },
    { seq: 3, round: 1, phase: "MELEE", kind: "MELEE_RESOLVED", cue: "MISS",
      text: "Orc 1 misses Evro" },
    { seq: 4, round: 1, phase: "MELEE", kind: "MELEE_RESOLVED", cue: "FALL",
      text: "Evro hits Orc 1 for 8 damage. Orc 1 falls" },
    { seq: 5, round: 1, phase: "MELEE", kind: "ACTION_HELD", cue: "HOLD",
      text: "Sho-Rembo holds position" },
    { seq: 6, round: 1, phase: "DM_SPECIAL_END", kind: "ENCOUNTER_TERMINAL",
      cue: "VICTORY", text: "Combat ends: PARTY_VICTORY" },
    { seq: 7, round: 1, phase: "MELEE", kind: "UNTRUSTED", cue: "ANY_HTML",
      text: "<script>not executed</script>" },
  ];
  const fake = {
    combatState: null,
    async startCombat() {
      this.combatState = view(5, { terminal: true, cursor: 7, events: entries });
      return { status: "COMPLETED", message: "Combat ended",
        combat: this.combatState, simulated: false };
    },
  };
  mountChat({ documentRef: dom, client: fake });
  await dom.controls["combat-start"].listeners.click();
  const journal = dom.controls["combat-events"].children;
  assert.equal(journal.length, entries.length);
  assert.match(journal[0].textContent, /^🔄 R1/);
  assert.match(journal[1].textContent, /^🎲 R1/);
  assert.match(journal[2].textContent, /^💨 R1/);
  assert.match(journal[3].textContent, /^💀 R1/);
  assert.match(journal[4].textContent, /^✋ R1/);
  assert.match(journal[5].textContent, /^🏆 R1/);
  assert.match(journal[6].textContent, /^R1/);
  assert.ok(journal[6].textContent.includes("<script>not executed</script>"));
});


test("DM multiline events keep carriage returns and auto-tail the real scroll containers", async () => {
  const dom = makeDom();
  const message = "🔄 Round 1 begins.\n🎲 Round 1 initiative: Party 6, Orcs 2 — Party wins initiative and acts first.\n⚔️ Alho hits Orc 1 for 4 damage.\n\nSho-Rembo: choose your action.";
  const event = { seq: 1, round: 1, phase: "INITIATIVE",
    kind: "SIDE_INITIATIVE", cue: "INITIATIVE",
    text: "Round 1 initiative: Party 6, Orcs 2 — Party wins initiative and acts first" };
  const fake = {
    combatState: null,
    async startCombat() {
      this.combatState = view(0, { cursor: 1, events: [event] });
      return { status: "NEEDS_PLAYER_INPUT", message,
        combat: this.combatState, simulated: false };
    },
    async send(playerText) {
      assert.equal(playerText, "Orc 1");
      this.combatState = view(1, { cursor: 2,
        events: [{ seq: 2, round: 1, phase: "MELEE",
          kind: "MELEE_RESOLVED", cue: "HIT",
          text: "Alho hits Orc 1 for 4 damage" }] });
      return { status: "NEEDS_PLAYER_INPUT",
        message: "⚔️ Alho hits Orc 1 for 4 damage.\n💨 Evro misses Orc 1.",
        combat: this.combatState, simulated: false };
    },
  };
  mountChat({ documentRef: dom, client: fake });
  const transcript = dom.controls["transcript"];
  const panel = dom.controls["chat-panel"];
  const board = dom.controls["combat-board"];
  assert.equal(panel.scrollTop, 0);
  assert.equal(board.scrollTop, 0);
  await dom.controls["combat-start"].listeners.click();
  assert.equal(panel.scrollTop, panel.scrollHeight, "Chat panel follows new DM reply");
  assert.equal(board.scrollTop, board.scrollHeight, "Combat board follows new journal item");
  assert.equal(transcript.scrollTop, 0, "Non-scrolling <ol> is not used");
  assert.ok(transcript.children.at(-1).children[1].textContent.startsWith(message));
  assert.match(transcript.children.at(-1).children[1].textContent, /Next decision:/);

  panel.scrollTop = 0;
  board.scrollTop = 0;
  dom.controls["player-message"].value = "Orc 1";
  await dom.controls["chat-form"].requestSubmit();
  assert.equal(panel.scrollTop, panel.scrollHeight,
    "Chat panel follows both player submission and subsequent DM reply");
  assert.equal(board.scrollTop, board.scrollHeight,
    "Combat board auto-tails new events");
  assert.match(transcript.children.at(-1).children[1].textContent,
    /Alho hits Orc 1 for 4 damage\.\n💨 Evro misses Orc 1\./);
});


test("RESET uses Meta turn and server-supplied new encounter, never local fake combat", async () => {
  const network = [];
  const oldId = "enc-original";
  const newerId = "enc-replacement";
  const client = new ChatApiClient({
    idFactory: ids(),
    fetcher: async (url, options) => {
      const data = JSON.parse(options.body);
      network.push({ url, data });
      const encountered = data.combat.kind === "RESET" ? newerId : oldId;
      return fakeReply(data, view(0, { encounterId: encountered, cursor: 9 }), "NEEDS_PLAYER_INPUT");
    },
  });
  const started = await client.startCombat();
  assert.equal(started.combat.encounter_id, oldId);
  const reset = await client.resetCombat();
  assert.equal(reset.status, "NEEDS_PLAYER_INPUT");
  assert.equal(reset.combat.encounter_id, newerId);
  assert.equal(client.combatState.encounter_id, newerId);
  assert.equal(client.actionUncertain, false);
  assert.deepEqual(network.map(x => x.url), ["/api/turn", "/api/turn"]);
  assert.equal(network[1].data.combat.kind, "RESET");
  assert.equal(network[1].data.combat.encounter_id, oldId);
  assert.equal(network[1].data.combat.log_since_sequence, 0);
  assert.equal(Object.hasOwn(network[1].data, "message"), false);
  assert.equal(network[0].data.session_id, network[1].data.session_id);
  assert.notEqual(network[0].data.correlation_id, network[1].data.correlation_id);
  const restartedLog = await client.viewCombatLog();
  assert.equal(restartedLog.status, "NEEDS_PLAYER_INPUT");
  assert.equal(network[2].data.combat.encounter_id, newerId);
});

test("RESET timeout preserves the previous state until a verified START re-sync", async () => {
  const calls = [];
  let newEncounter = false;
  const client = new ChatApiClient({
    idFactory: ids(),
    fetcher: async (url, options) => {
      const data = JSON.parse(options.body);
      calls.push(data);
      if (data.combat.kind === "RESET") {
        newEncounter = true;
        throw Error("Private network exception");
      }
      const encounterId = newEncounter ? "enc-recovered" : "enc-original";
      return fakeReply(data, view(0, { encounterId }), "NEEDS_PLAYER_INPUT");
    },
  });
  await client.startCombat();
  const reset = await client.resetCombat();
  assert.equal(reset.status, "ERROR");
  assert.equal(client.combatState.encounter_id, "enc-original");
  assert.equal(client.actionUncertain, true);
  assert.equal((await client.send("Orc 1")).status, "BLOCKED");
  assert.equal(calls.length, 2, "No combat ACTION submitted after uncertain reset");
  const recovered = await client.startCombat();
  assert.equal(recovered.combat.encounter_id, "enc-recovered");
  assert.equal(client.actionUncertain, false);
  assert.equal((await client.send("Orc 1")).status, "NEEDS_PLAYER_INPUT");
  assert.equal(calls.at(-1).combat.encounter_id, "enc-recovered");
});

test("Reset combat button clears the prior transcript and journal only on confirmed new encounter", async () => {
  const dom = makeDom();
  const oldEvent = { seq: 1, round: 1, phase: "MELEE", kind: "MELEE_RESOLVED",
    cue: "HIT", text: "Alho hits Orc 1 for 4 damage" };
  const newEvent = { seq: 1, round: 1, phase: "INITIATIVE",
    kind: "SIDE_INITIATIVE", cue: "INITIATIVE",
    text: "Round 1 initiative: Party 6, Orcs 2 — Party wins initiative and acts first" };
  let shouldFail = true;
  const client = {
    combatState: null,
    async startCombat() {
      this.combatState = view(1, { cursor: 7, events: [oldEvent], encounterId: "enc-old" });
      return { status: "NEEDS_PLAYER_INPUT", message: "Old DM narration",
        combat: this.combatState, simulated: false };
    },
    async resetCombat() {
      if (shouldFail) return { status: "ERROR", message: "Reset uncertain",
        combat: null, simulated: false };
      this.combatState = view(0, { cursor: 1, events: [newEvent], encounterId: "enc-fresh" });
      return { status: "NEEDS_PLAYER_INPUT", message: "Combat reset. Fresh fight.",
        combat: this.combatState, simulated: false };
    },
  };
  mountChat({ documentRef: dom, client });
  const resetButton = dom.controls["combat-reset"];
  assert.equal(resetButton.disabled, false, "Fake DOM defaults can differ from real HTML");
  await dom.controls["combat-start"].listeners.click();
  assert.equal(resetButton.disabled, false);
  assert.equal(dom.controls["transcript"].children.length, 1);
  assert.equal(dom.controls["combat-events"].children.length, 1);
  assert.match(dom.controls["combat-events"].children[0].textContent, /Alho hits/);
  await resetButton.listeners.click();
  assert.equal(dom.controls["transcript"].children.length, 2,
    "Uncertain reset must not erase old transcript");
  assert.equal(dom.controls["combat-events"].children.length, 1);
  assert.match(dom.controls["combat-events"].children[0].textContent, /Alho hits/);

  shouldFail = false;
  dom.controls["player-message"].value = "old action draft";
  await resetButton.listeners.click();
  assert.equal(dom.controls["player-message"].value, "");
  assert.equal(dom.controls["transcript"].children.length, 1);
  assert.match(dom.controls["transcript"].children[0].children[1].textContent, /Combat reset/);
  assert.equal(dom.controls["combat-events"].children.length, 1);
  assert.match(dom.controls["combat-events"].children[0].textContent, /initiative/i);
  assert.equal(dom.controls["combat-status"].textContent.includes("Round 1"), true);
  assert.equal(dom.controls["party-outcome"].textContent, "");
  assert.equal(dom.controls["combat-reset"].disabled, false);
  assert.equal(dom.controls["chat-panel"].scrollTop, dom.controls["chat-panel"].scrollHeight);
  assert.equal(dom.controls["combat-board"].scrollTop, dom.controls["combat-board"].scrollHeight);
});
