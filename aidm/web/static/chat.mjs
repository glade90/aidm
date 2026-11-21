/* AIDM-DES-014.1 — DOM-only chat presentation; no game logic.
 * Every server string is displayed with textContent, never innerHTML.
 * AIDM-DES-025.2 adds source-verified combat log and start/view controls.
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
  const startButton = documentRef.getElementById("combat-start");
  const logButton = documentRef.getElementById("combat-log");
  const combatStatus = documentRef.getElementById("combat-status");
  const combatBoard = documentRef.getElementById("combat-board");
  const combatEvents = documentRef.getElementById("combat-events");
  const partyOutcome = documentRef.getElementById("party-outcome");
  const partyStatus = documentRef.getElementById("party-status");
  const shownEvents = new Set();
  let visibleEncounterId = null;
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

  function showCombat(view) {
    if (!view || !combatBoard || !combatEvents) return;
    if (visibleEncounterId !== view.encounter_id) {
      shownEvents.clear();
      combatEvents.replaceChildren();
      visibleEncounterId = view.encounter_id;
    }
    combatBoard.hidden = false;
    if (partyStatus && Array.isArray(view.party_status)) {
      partyStatus.textContent = view.party_status.map((actor) => {
        const down = actor.hp_current === 0 ? " (down)" : "";
        return `${actor.name}: ${actor.hp_current}/${actor.hp_max} HP${down}`;
      }).join(" · ");
    }
    if (logButton) logButton.disabled = pending;
    if (combatStatus) {
      const label = view.terminal ? "Encounter ended"
        : view.awaiting_player ? "Waiting for your decision" : "Rules check required";
      const modelLabel = view.intent_mode === "LIVE_LLM"
        ? "Live LLM enabled" : view.intent_mode === "OFFLINE_SCRIPTED"
          ? "Offline scripted intentions" : "Injected intention policy";
      combatStatus.textContent =
        `Round ${view.current_round} · ${view.phase_label} · ${label} · ${modelLabel}`;
    }
    for (const entry of view.new_log_entries ?? []) {
      if (!Number.isInteger(entry.seq) || shownEvents.has(entry.seq)) continue;
      shownEvents.add(entry.seq);
      const item = documentRef.createElement("li");
      let text = `R${entry.round} · ${entry.phase}: ${entry.text}`;
      const roll = entry.roll;
      if (roll && Number.isInteger(roll.attack_face)) {
        text += ` | d20 ${roll.attack_face} + ${roll.attack_modifier} = ${roll.attack_total}`;
      }
      if (roll && Number.isInteger(roll.damage_face)) {
        text += ` | damage die ${roll.damage_face} + ${roll.damage_modifier} = ${roll.damage_total}`;
      }
      item.textContent = text; // No private HTML/raw journal insertion.
      combatEvents.appendChild(item);
    }
    combatEvents.scrollTop = combatEvents.scrollHeight;
    if (partyOutcome && view.terminal) {
      const party = (view.surviving_party_summary ?? [])
        .map((actor) => `${actor.name}: ${actor.hp_current}/${actor.hp_max} HP`)
        .join(" · ");
      partyOutcome.textContent = `Outcome: ${view.outcome ?? "unknown"} · ${party}`;
    }
  }

  function combatReplyText(result) {
    let text = result.message;
    const next = result.combat?.next_decision;
    if (next && typeof next.prompt === "string" && !text.includes(next.prompt)) {
      text += `\n\nNext decision: ${next.prompt}`;
    }
    return text;
  }

  function setPending(value) {
    pending = value;
    button.disabled = value;
    input.disabled = value;
    if (startButton) startButton.disabled = value;
    if (logButton) logButton.disabled = value || !(client.combatState);
  }

  async function submit(event) {
    event?.preventDefault();
    if (pending) return; // Synchronous guard against double-click/Enter.
    const message = input.value;
    if (!message.trim()) {
      input.focus();
      return;
    }

    setPending(true);
    setStatus("Waiting for Dungeon Master…", "working");
    addMessage("player", message);
    input.value = "";

    try {
      const result = await client.send(message);
      const failure = result.status === "ERROR";
      const note = result.simulated
        ? "Simulated · No dice, damage or HP changes"
        : result.status !== "COMPLETED" ? result.status.replaceAll("_", " ") : "";
      addMessage("dm", combatReplyText(result), { kind: failure ? "error" : "normal", note });
      showCombat(result.combat);
      setStatus(failure ? "Unavailable — you may try again" : "Ready to send",
        failure ? "error" : "ready");
    } catch {
      // Defensive boundary if an injected or future client itself throws.
      addMessage("dm", "The local chat request could not be completed.",
        { kind: "error", note: "ERROR" });
      setStatus("Unavailable — you may try again", "error");
    } finally {
      setPending(false);
      input.focus();
    }
  }

  async function runCombatControl(action, label) {
    if (pending) return;
    setPending(true);
    setStatus(label, "working");
    try {
      const result = await action();
      if (result.combat) showCombat(result.combat);
      // Do not make a VIEW_LOG response look like a new combat action.
      if (label !== "Retrieving combat journal…") {
        addMessage("dm", combatReplyText(result), {
          kind: result.status === "ERROR" ? "error" : "normal",
          note: result.status,
        });
      }
      setStatus(result.status === "ERROR"
        ? "Outcome uncertain — read combat log before retrying"
        : "Ready to send", result.status === "ERROR" ? "error" : "ready");
    } catch {
      addMessage("dm", "The encounter is unavailable; inspect the log before retrying.",
        { kind: "error", note: "ERROR" });
      setStatus("Outcome uncertain — read combat log before retrying", "error");
    } finally {
      setPending(false);
      input.focus();
    }
  }
  if (startButton) {
    startButton.addEventListener("click", () =>
      runCombatControl(() => client.startCombat(), "Starting combat…"));
  }
  if (logButton) {
    logButton.addEventListener("click", () =>
      runCombatControl(() => client.viewCombatLog(), "Retrieving combat journal…"));
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
