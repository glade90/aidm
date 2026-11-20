/* AIDM-DES-014.1 — testable, framework-free Meta /api/turn HTTP client.
 * The browser owns no Combat API, rules, world state or persistent game memory.
 * Change Log: 2026-11-20 DAVOS — correct native fetch receiver (browser failure).
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
  }

  async send(message) {
    const correlationId = this.idFactory("turn");
    if (typeof message !== "string" || !message.trim()) {
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
          message, session_id: this.sessionId, correlation_id: correlationId,
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

      return {
        status: body.status, message: approvedText,
        correlationId, sessionId: this.sessionId,
        simulated: body.simulated === true,
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
