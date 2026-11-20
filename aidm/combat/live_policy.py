"""Optional live LLM intention/narration adapter for AIDM-DES-025.2.

Purpose: Supply only non-authoritative action PROPOSALS and safe-event narrative.
Usage: policy = OpenAIResponsesPolicy(api_key=secret, model="selected-model")
       CombatSessionService(intent_policy=policy)
Change Log: 2026-11-20 DAVOS — Responses API adapter (opt-in only).

No LLM may roll dice, change HP, invent rules, choose hidden targets or
authorise mutation. This adapter has no default real-network execution.
"""

from __future__ import annotations

import json
from urllib.request import Request, urlopen
from typing import Any, Callable

_RESPONSE_URL = "https://api.openai.com/v1/responses"


def _post_json(body: bytes, api_key: str, timeout: float) -> dict[str, Any]:
    req = Request(
        _RESPONSE_URL,
        data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
        method="POST",
    )
    with urlopen(req, timeout=timeout) as result:
        response = result.read(262_145)
    if len(response) > 262_144:
        raise ValueError("Model response too large")
    decoded = json.loads(response)
    if not isinstance(decoded, dict):
        raise ValueError("Invalid model response")
    return decoded


class OpenAIResponsesPolicy:
    """Opt-in Responses API bridge; all outputs are untrusted text proposals.

    The provider configuration is injected, never read at module import time.
    A failed request does not trigger automatic retry or a combat command.
    """

    def __init__(self, *, api_key: str, model: str, timeout_seconds: float = 10,
                 transport: Callable[[bytes, str, float], dict[str, Any]] = _post_json) -> None:
        if not isinstance(api_key, str) or not api_key.strip():
            raise ValueError("Missing live model credential")
        if not isinstance(model, str) or not model.strip():
            raise ValueError("Missing selected live model")
        if not callable(transport) or not 0 < timeout_seconds <= 30:
            raise ValueError("Invalid model adapter parameters")
        self._api_key = api_key
        self.model = model
        self.timeout_seconds = timeout_seconds
        self._transport = transport

    def __repr__(self) -> str:
        return f"OpenAIResponsesPolicy(model={self.model!r}, api_key=<redacted>)"

    def _invoke(self, *, instructions: str, input_text: str) -> str:
        payload = json.dumps({
            "model": self.model,
            "instructions": instructions,
            "input": input_text,
            "max_output_tokens": 250,
            "store": False,
        }, separators=(",", ":")).encode("utf-8")
        response = self._transport(payload, self._api_key, self.timeout_seconds)
        chunks = []
        for item in response.get("output", ()):
            if isinstance(item, dict) and item.get("type") == "message":
                for text in item.get("content", ()):
                    if isinstance(text, dict) and text.get("type") == "output_text":
                        chunks.append(text.get("text", ""))
        value = "\n".join(x for x in chunks if isinstance(x, str)).strip()
        if not value:
            raise ValueError("Model produced no supported text")
        return value[:2000]

    def propose(self, *, player_text: str, actor_id: str,
                allowed_targets: tuple[str, ...]) -> tuple[str, str | None]:
        """Interpret free text into a PROPOSAL, never an approved combat effect."""
        instructions = (
            "You interpret an RPG player's intent for a rules engine. "
            "Return ONLY one compact JSON object: "
            '{"kind":"ATTACK_MELEE","target_id":"<allowed id>"} or '
            '{"kind":"HOLD","target_id":null} or '
            '{"kind":"NEEDS_CLARIFICATION","target_id":null}. '
            "Do not invent a target, actor, action, rule, hit, damage or HP. "
            "If ambiguous, use NEEDS_CLARIFICATION. "
            "You cannot execute any action; the Python rules controller decides legality."
        )
        user = json.dumps({
            "actor_id": actor_id,
            "allowed_target_ids": allowed_targets,
            "player_statement": player_text,
        }, separators=(",", ":"))
        answer = json.loads(self._invoke(instructions=instructions, input_text=user))
        if not isinstance(answer, dict) or set(answer) != {"kind", "target_id"}:
            return "NEEDS_CLARIFICATION", None
        kind = answer["kind"]
        target = answer["target_id"]
        if kind == "HOLD" and target is None:
            return "HOLD", None
        if kind == "ATTACK_MELEE" and isinstance(target, str) and target in allowed_targets:
            return "ATTACK_MELEE", target
        return "NEEDS_CLARIFICATION", None

    def narrate(self, *, verified_events: tuple[str, ...]) -> str | None:
        """Decorative narration only from already-redacted controller events."""
        if not verified_events:
            return None
        instructions = (
            "You are a fantasy Dungeon Master presenting verified combat events. "
            "Only describe the supplied player-visible events in short engaging prose. "
            "Do not introduce new actions, hit results, dice faces, hit points, "
            "characters, equipment, hidden facts, spells, outcomes or mechanics. "
            "You are NOT the source of the combat result."
        )
        return self._invoke(
            instructions=instructions,
            input_text=json.dumps({"verified_public_events": verified_events}),
        )[:500]
