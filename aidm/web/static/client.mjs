/* AIDM-DES-014.1 — testable, framework-free Meta /api/turn HTTP client.
 * The browser owns no Combat API, rules, world state or persistent game memory.
 * Change Log: 2026-11-20 DAVOS — correct native fetch receiver (browser failure).
 *             2026-11-20 DAVOS — AIDM-DES-025.2 optional combat turns.
 */

const STATUSES = new Set([
  "COMPLETED", "NEEDS_PLAYER_INPUT", "BLOCKED",
  "NEEDS_RULING", "ERROR", "HANDOFF",
]);
const ERROR_MESSAGE = "The Dungeon Master is unavailable. Check the local service and try again.";
const BAD_REPLY_MESSAGE = "The response could not be verified. You can try another turn.";

export function createId(prefix) {
  if (!globalThis.crypto || typeof globalThis.crypto.randomUUID !== "function") {
    throw new Error("Secure browser identifiers are unavailable");
  }
  return `${prefix}-${globalThis.crypto.randomUUID()}`;
}

export class ChatApiClient {
  constructor({
    // Keep the native fetch call bound to its browser/global receiver.
    // Passing globalThis.fetch by reference and then calling this.fetcher()
    // can throw "Illegal invocation" before any POST reaches Uvicorn.
    fetcher = (url, options) => globalThis.fetch(url, options),
    idFactory = createId,
    sessionId,
  } = {}) {
    if (typeof fetcher !== "function" || typeof idFactory !== "function") {
      throw new TypeError("A fetch function and ID factory are required");
    }
    this.fetcher = fetcher;
    this.idFactory = idFactory;
    // The current Meta contract *echoes* the client's session ID; it does
    // not mint or persist one. Never claim this is authoritative game memory.
    this.sessionId = sessionId ?? this.idFactory("session");
    this.combatState = null;
    this.actionUncertain = false; // Must inspect trusted state before retry.
  }

  async startCombat() {
    return this._send("", { kind: "START", log_since_sequence: 0 });
  }

  async viewCombatLog() {
    if (!this.combatState) {
      return {
        status: "NEEDS_PLAYER_INPUT", message: "Start a combat encounter first.",
        combat: null, simulated: false,
      };
    }
    const result = await this._send("", {
      kind: "VIEW_LOG", encounter_id: this.combatState.encounter_id,
      log_since_sequence: 0,
    });
    if (result.combat && result.status !== "ERROR") {
      this.actionUncertain = false;
    }
    return result;
  }

  async send(message) {
    if (!this.combatState) return this._send(message, null);
    if (this.actionUncertain) {
      return {
        status: "BLOCKED",
        message: "A previous combat outcome may still be completing. View the full combat log before another action.",
        combat: null, simulated: false,
      };
    }
    if (this.combatState.terminal) {
      return {
        status: "BLOCKED", message: "Combat has ended. View the log for the outcome.",
        combat: this.combatState, simulated: false,
      };
    }
    const decision = this.combatState.next_decision;
    if (!decision || !this.combatState.awaiting_player) {
      return {
        status: "NEEDS_PLAYER_INPUT", message: "No player decision is currently ready. View the log.",
        combat: this.combatState, simulated: false,
      };
    }
    const result = await this._send(message, {
      kind: "ACTION",
      encounter_id: this.combatState.encounter_id,
      actor_id: decision.actor_id,
      decision_token: decision.decision_token,
      expected_encounter_version: this.combatState.state_version,
      client_action_id: this.idFactory("action"),
      log_since_sequence: this.combatState.log_next_cursor,
    });
    if (result.status === "ERROR") this.actionUncertain = true;
    return result;
  }

  async _send(message, combat) {
    const correlationId = this.idFactory("turn");
    if ((combat === null || combat.kind === "ACTION")
        && (typeof message !== "string" || !message.trim())) {
      return {
        status: "NEEDS_PLAYER_INPUT", message: "Please enter a message.",
        correlationId, sessionId: this.sessionId, simulated: false,
      };
    }

    try {
      // The ONLY network call made by this client.
      const response = await this.fetcher("/api/turn", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...((combat === null || combat.kind === "ACTION") ? { message } : {}),
          session_id: this.sessionId, correlation_id: correlationId,
          ...(combat !== null ? { combat } : {}),
        }),
      });

      let body;
      try {
        body = await response.json();
      } catch {
        return this.badReply(correlationId);
      }
      if (!body || typeof body !== "object") return this.badReply(correlationId);

      // Meta can issue a fresh correlation on invalid 422 input, as that
      // request never reached the typed player-turn handler.
      if (response.status === 422 && body.status === "NEEDS_PLAYER_INPUT") {
        return {
          status: "NEEDS_PLAYER_INPUT",
          message: "Please check your message and try again.",
          correlationId, sessionId: this.sessionId, simulated: false,
        };
      }

      // Never attach a reply to the wrong conversation or turn.
      if (body.session_id !== this.sessionId
          || body.correlation_id !== correlationId
          || !STATUSES.has(body.status)
          || (response.ok && body.status === "ERROR")
          || (!response.ok && body.status === "COMPLETED")) {
        return this.badReply(correlationId);
      }

      const approvedText = (
        typeof body.message === "string" && body.message.trim()
          ? body.message
          : typeof body.error?.message === "string" && body.error.message.trim()
            ? body.error.message
            : BAD_REPLY_MESSAGE
      );

      const combatView = body.combat && typeof body.combat === "object"
        && typeof body.combat.encounter_id === "string"
        && Number.isInteger(body.combat.state_version)
        && Number.isInteger(body.combat.log_next_cursor)
        && Array.isArray(body.combat.new_log_entries)
        ? body.combat : null;
      // A denial may correctly omit a combat view (e.g. wrong encounter).
      // But a purported successful typed combat response must include one.
      if (combat !== null && combatView === null
          && body.status === "COMPLETED") {
        return this.badReply(correlationId);
      }
      if (combatView !== null) this.combatState = combatView;

      return {
        status: body.status, message: approvedText,
        correlationId, sessionId: this.sessionId,
        simulated: body.simulated === true, combat: combatView,
      };
    } catch {
      // Never render raw network errors or backend tracebacks.
      return {
        status: "ERROR", message: ERROR_MESSAGE,
        correlationId, sessionId: this.sessionId, simulated: false,
      };
    }
  }

  badReply(correlationId) {
    return {
      status: "ERROR", message: BAD_REPLY_MESSAGE,
      correlationId, sessionId: this.sessionId, simulated: false,
    };
  }
}
