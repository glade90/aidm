/* Offline JavaScript browser-client tests for AIDM-DES-014.1.
 * Run from repo root: node --test aidm/web/test/chat_client.test.mjs
 * Requires only Node's built-in test runner; no npm dependencies/network.
 */
import test from "node:test";
import assert from "node:assert/strict";

import { ChatApiClient } from "../static/client.mjs";
import { mountChat } from "../static/chat.mjs";

function ids() {
  let count = 0;
  return (prefix) => `${prefix}-${++count}`;
}

function reply({ status = "COMPLETED", message = "Simulation only: no dice or HP.",
                 session = "session-1", correlation = "turn-2",
                 simulated = true, httpStatus = 200 } = {}) {
  return {
    status: httpStatus, ok: httpStatus >= 200 && httpStatus < 300,
    async json() {
      return { status, message, session_id: session,
               correlation_id: correlation, simulated };
    },
  };
}

test("only /api/turn is called; original text, stable session, distinct correlations", async () => {
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push({ url, options });
    return reply({ correlation: `turn-${calls.length + 1}` });
  };
  const client = new ChatApiClient({ fetcher, idFactory: ids() });
  const original = "I swing my sword at the orc.";
  const first = await client.send(original);
  const second = await client.send(original);
  assert.equal(first.status, "COMPLETED");
  assert.equal(second.status, "COMPLETED");
  assert.equal(first.simulated, true);
  assert.deepEqual(calls.map((c) => c.url), ["/api/turn", "/api/turn"]);
  assert.deepEqual(calls.map((c) => c.options.method), ["POST", "POST"]);
  assert.deepEqual(calls.map((c) => JSON.parse(c.options.body)), [
    { message: original, session_id: "session-1", correlation_id: "turn-2" },
    { message: original, session_id: "session-1", correlation_id: "turn-3" },
  ]);
});

test("blank input gives clarification and does not call network", async () => {
  const client = new ChatApiClient({
    fetcher: () => { throw new Error("SHOULD_NOT_FETCH"); },
    idFactory: ids(),
  });
  const response = await client.send("   ");
  assert.equal(response.status, "NEEDS_PLAYER_INPUT");
  assert.match(response.message, /enter a message/i);
});

test("unsupported request returns readable blocked result without mechanics", async () => {
  const client = new ChatApiClient({
    fetcher: async () => reply({
      status: "BLOCKED", message: "This operation is not supported.", simulated: false,
    }),
    idFactory: ids(),
  });
  const result = await client.send("Look around");
  assert.equal(result.status, "BLOCKED");
  assert.equal(result.message, "This operation is not supported.");
  assert.equal(result.simulated, false);
});

test("422 validation reports clarification even when Meta generated a new ID", async () => {
  const client = new ChatApiClient({
    fetcher: async () => reply({
      status: "NEEDS_PLAYER_INPUT", httpStatus: 422,
      correlation: "server-validation-correlation", simulated: false,
    }),
    idFactory: ids(),
  });
  const result = await client.send("valid but rejected");
  assert.equal(result.status, "NEEDS_PLAYER_INPUT");
  assert.match(result.message, /check your message/i);
});

test("network outage and subsequent recovery never disclose raw exception", async () => {
  let count = 0;
  const client = new ChatApiClient({
    fetcher: async () => {
      if (++count === 1) throw new Error("SECRET backend traceback");
      return reply({ correlation: "turn-3" });
    },
    idFactory: ids(),
  });
  const failure = await client.send("I swing my sword at the orc.");
  assert.equal(failure.status, "ERROR");
  assert.doesNotMatch(failure.message, /SECRET|traceback/);
  const recovered = await client.send("I swing my sword at the orc.");
  assert.equal(recovered.status, "COMPLETED");
  assert.equal(count, 2);
});

test("mismatched session/correlation and malformed reply fail closed", async () => {
  const bad = [
    reply({ session: "other-session" }),
    reply({ correlation: "other-correlation" }),
    { status: 200, ok: true, json: async () => "<html>" },
    { status: 200, ok: true, json: async () => { throw new Error("SECRET"); } },
  ];
  for (const response of bad) {
    const client = new ChatApiClient({
      fetcher: async () => response, idFactory: ids(),
    });
    const out = await client.send("hello");
    assert.equal(out.status, "ERROR");
    assert.doesNotMatch(out.message, /SECRET|<html>/);
  }
});

test("failed HTTP request cannot be mistaken for completed combat", async () => {
  const client = new ChatApiClient({
    fetcher: async () => reply({ status: "COMPLETED", httpStatus: 503 }),
    idFactory: ids(),
  });
  assert.equal((await client.send("hello")).status, "ERROR");
});

class FakeElement {
  constructor() {
    this.listeners = {};
    this.children = [];
    this.dataset = {};
    this.value = "";
    this.disabled = false;
    this.scrollHeight = 150;
    this.scrollTop = 0;
    this.className = "";
    this.textContent = "";
    this.parentElement = null;
    this.focusCount = 0;
  }
  addEventListener(name, cb) { this.listeners[name] = cb; }
  appendChild(item) { this.children.push(item); }
  focus() { this.focusCount++; }
  requestSubmit() {
    return this.listeners.submit?.({ preventDefault() {} });
  }
  set innerHTML(_) { throw new Error("Unsafe innerHTML insertion attempted"); }
}

function fakeDocument() {
  const elements = {};
  for (const id of ["chat-form", "player-message", "send-button",
                    "transcript", "service-status"]) {
    elements[id] = new FakeElement();
  }
  elements["service-status"].parentElement = new FakeElement();
  return {
    elements,
    getElementById: (id) => elements[id],
    createElement: () => new FakeElement(),
  };
}

test("DOM blocks duplicate pending submits and displays untrusted markup as text", async () => {
  const doc = fakeDocument();
  doc.elements["player-message"].value = "I swing my sword at the orc.";
  let invocations = 0;
  let finish;
  const client = {
    send: async () => {
      invocations++;
      return new Promise((resolve) => { finish = resolve; });
    },
  };
  const view = mountChat({ documentRef: doc, client });
  const first = view.submit({ preventDefault() {} });
  const second = view.submit({ preventDefault() {} });
  await second;
  assert.equal(invocations, 1);
  assert.equal(view.isPending(), true);
  assert.equal(doc.elements["send-button"].disabled, true);
  assert.equal(doc.elements["transcript"].children.length, 1);
  finish({ status: "COMPLETED", message: "<img src=x onerror=alert(1)>",
           simulated: true });
  await first;
  assert.equal(view.isPending(), false);
  assert.equal(doc.elements["send-button"].disabled, false);
  assert.equal(doc.elements["transcript"].children.length, 2);
  const dm = doc.elements["transcript"].children[1];
  assert.equal(dm.children[1].textContent, "<img src=x onerror=alert(1)>");
  assert.match(dm.children[2].textContent, /Simulated/);
});

test("keyboard Enter sends, Shift+Enter does not; UI can recover from failure", async () => {
  const doc = fakeDocument();
  const form = doc.elements["chat-form"];
  const input = doc.elements["player-message"];
  const log = doc.elements["transcript"];
  const client = {
    count: 0,
    async send() {
      this.count++;
      return this.count === 1
        ? { status: "ERROR", message: "Service temporarily unavailable", simulated: false }
        : { status: "BLOCKED", message: "Unsupported action", simulated: false };
    },
  };
  mountChat({ documentRef: doc, client });
  input.value = "first request";
  input.listeners.keydown({ key: "Enter", shiftKey: true,
                            preventDefault() { throw new Error("should not prevent"); } });
  assert.equal(client.count, 0);
  input.listeners.keydown({ key: "Enter", shiftKey: false, isComposing: false,
                            preventDefault() {} });
  await new Promise(setImmediate);
  assert.equal(client.count, 1);
  assert.match(log.children[1].className, /message--error/);
  input.value = "second request";
  await form.requestSubmit();
  assert.equal(client.count, 2);
  assert.equal(log.children[3].children[1].textContent, "Unsupported action");
});
