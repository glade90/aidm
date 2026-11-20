/* AIDM-DES-014.1 — DOM-only chat presentation; no game logic.
 * Every server string is displayed with textContent, never innerHTML.
 */
import { ChatApiClient } from "./client.mjs";

export function mountChat({
  documentRef = globalThis.document,
  client = new ChatApiClient(),
} = {}) {
  const form = documentRef.getElementById("chat-form");
  const input = documentRef.getElementById("player-message");
  const button = documentRef.getElementById("send-button");
  const transcript = documentRef.getElementById("transcript");
  const status = documentRef.getElementById("service-status");

  if (!form || !input || !button || !transcript || !status) {
    throw new Error("Chat interface is incomplete");
  }
  const connection = status.parentElement;
  let pending = false;

  function setStatus(text, state = "ready") {
    status.textContent = text;
    if (connection) connection.dataset.state = state;
  }

  function addMessage(role, content, { kind = "normal", note = "" } = {}) {
    const item = documentRef.createElement("li");
    item.className = `message message--${role}`;
    if (kind === "error") item.className += " message--error";

    const speaker = documentRef.createElement("span");
    speaker.className = "speaker";
    speaker.textContent = role === "player" ? "You" : "Dungeon Master";
    const paragraph = documentRef.createElement("p");
    paragraph.textContent = content;
    item.appendChild(speaker);
    item.appendChild(paragraph);

    if (note) {
      const detail = documentRef.createElement("span");
      detail.className = "note";
      detail.textContent = note;
      item.appendChild(detail);
    }
    transcript.appendChild(item);
    transcript.scrollTop = transcript.scrollHeight;
  }

  async function submit(event) {
    event?.preventDefault();
    if (pending) return; // Synchronous guard against double-click/Enter.
    const message = input.value;
    if (!message.trim()) {
      input.focus();
      return;
    }

    pending = true;
    button.disabled = true;
    input.disabled = true;
    setStatus("Waiting for Dungeon Master…", "working");
    addMessage("player", message);
    input.value = "";

    try {
      const result = await client.send(message);
      const failure = result.status === "ERROR";
      const note = result.simulated
        ? "Simulated · No dice, damage or HP changes"
        : result.status !== "COMPLETED" ? result.status.replaceAll("_", " ") : "";
      addMessage("dm", result.message, { kind: failure ? "error" : "normal", note });
      setStatus(failure ? "Unavailable — you may try again" : "Ready to send",
        failure ? "error" : "ready");
    } catch {
      // Defensive boundary if an injected or future client itself throws.
      addMessage("dm", "The local chat request could not be completed.",
        { kind: "error", note: "ERROR" });
      setStatus("Unavailable — you may try again", "error");
    } finally {
      pending = false;
      input.disabled = false;
      button.disabled = false;
      input.focus();
    }
  }

  form.addEventListener("submit", submit);
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      form.requestSubmit();
    }
  });
  setStatus("Ready to send");
  return { submit, addMessage, isPending: () => pending };
}

if (typeof document !== "undefined") {
  mountChat();
}
