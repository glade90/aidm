"""AIDM-DES-004.2 bounded model-backed specialist CombatAgent policy.

The existing CombatSessionService is the Python orchestrator and CombatEngine
remains the sole authority. This adapter owns typed proposals and safe-event
narration, not initiative, dice, damage, HP, spells or Bookkeeper writes.

A single-party-round planner is NOT implemented by this first slice; that is a
separate BON-designated Build. Existing per-decision interface is preserved.
"""
from __future__ import annotations

import json
from collections.abc import Mapping
from typing import Any

from braider import Braider, ContextItem, ModelChoice, ModelRuntime, ModelTarget
from .live_policy import OpenAIResponsesPolicy


_INSTRUCTIONS = (
    "You are AIDM's specialised CombatAgent, not the Dungeon Master. "
    "Interpret only the player's permitted COMBAT intent. "
    "For task=INTENT return exactly one JSON object with keys kind and target_id. "
    "kind is ATTACK_MELEE, HOLD, NEEDS_CLARIFICATION, or UNSUPPORTED_RULE; "
    "target_id is a permitted exact ID only for ATTACK_MELEE, otherwise null. "
    "Use NEEDS_CLARIFICATION for genuine ambiguity, UNSUPPORTED_RULE for "
    "unsupported movement, spell, equipment and monster mechanics. "
    "Never assume an unspoken HOLD, invent a target, rule, dice outcome or HP. "
    "For task=NARRATE return short player-safe prose based ONLY on the supplied "
    "verified_public_events. Do not invent actions, results, identities, locations, "
    "dialogue or mechanical consequences. You cannot execute anything."
)


class ResponsesBraiderRuntime:
    """Reuse DES-025.2's single opted-in Responses transport; no second client."""

    def __init__(self, policy: OpenAIResponsesPolicy) -> None:
        if not isinstance(policy, OpenAIResponsesPolicy):
            raise ValueError("Approved existing live-model adapter required")
        self._policy = policy

    def invoke(self, *, model_target: ModelTarget, instructions: str,
               input_text: str, approved_context: Mapping[ContextItem, str]) -> str:
        if model_target.provider != "openai" or model_target.model != self._policy.model:
            raise ValueError("Unexpected model target")
        if set(approved_context) != {ContextItem.TASK_CONTEXT}:
            raise ValueError("Specialist context must be explicitly authorised")
        # This is the EXISTING authenticated/no-store transport; its response
        # contains untrusted model text. Braider owns allowed-context checks.
        return self._policy._invoke(
            instructions=instructions,
            input_text=json.dumps({"task": json.loads(input_text),
                                   "trusted_context": approved_context[ContextItem.TASK_CONTEXT]},
                                  separators=(",", ":")),
        )


class CombatRoundAgent(Braider):
    """Scoped Braider specialist implementing DES-025.2 IntentPolicy seam.

    A future whole-party preflight adapter can replace propose_scoped without
    touching Engine or exposing another DM parser. No automatic retries.
    """

    mode = "LIVE_LLM"
    narrate_on_round_complete = True

    def __init__(self, *, runtime: ModelRuntime, model_target: ModelTarget,
                 approved_fixture_context: str = "Synthetic approved 3v3 stationary melee fixture",
                 narration_style_ref: str = "DES-015-PRINCIPLES") -> None:
        if not isinstance(approved_fixture_context, str) or not approved_fixture_context.strip():
            raise ValueError("Trusted fixture context required")
        if not isinstance(narration_style_ref, str) or not narration_style_ref.strip():
            raise ValueError("Approved DM style reference required")
        super().__init__(
            runtime=runtime,
            model_targets={ModelChoice.BALANCED: model_target},
            model_choice=ModelChoice.BALANCED,
            allowed_context=frozenset({ContextItem.TASK_CONTEXT}),
            instructions=_INSTRUCTIONS,
        )
        self._fixture_context = approved_fixture_context
        self._style_ref = narration_style_ref

    @classmethod
    def from_live_policy(cls, policy: OpenAIResponsesPolicy) -> "CombatRoundAgent":
        """Explicit live opt-in only; the existing policy owns credentials."""
        return cls(runtime=ResponsesBraiderRuntime(policy),
                   model_target=ModelTarget("openai", policy.model))

    def _call(self, task: dict[str, Any], *, trusted_context: dict[str, Any] | None = None,
              trace_id: str | None = None) -> str:
        approved = {"fixture": self._fixture_context,
                    "narration_style_ref": self._style_ref}
        if trusted_context is not None:
            approved["player_visible_state"] = trusted_context
        result = self.invoke(
            json.dumps(task, separators=(",", ":"), ensure_ascii=True),
            approved_context={ContextItem.TASK_CONTEXT: json.dumps(approved, separators=(",", ":"))},
            trace_id=trace_id,
        )
        if result.error_code is not None or not isinstance(result.text, str):
            # Provider reasons, API keys and raw output never reach the player.
            raise RuntimeError("Specialist model unavailable")
        return result.text.strip()

    def propose(self, *, player_text: str, actor_id: str,
                allowed_targets: tuple[str, ...]) -> tuple[str, str | None]:
        return self.propose_scoped(player_text=player_text, actor_id=actor_id,
                                   allowed_targets=allowed_targets,
                                   trusted_context=None, trace_id=None)

    def propose_scoped(self, *, player_text: str, actor_id: str,
                       allowed_targets: tuple[str, ...],
                       trusted_context: dict[str, Any] | None = None,
                       trace_id: str | None = None) -> tuple[str, str | None]:
        if (not isinstance(player_text, str) or not player_text.strip()
                or not isinstance(actor_id, str) or not actor_id
                or not isinstance(allowed_targets, tuple)
                or any(not isinstance(t, str) for t in allowed_targets)):
            return "NEEDS_CLARIFICATION", None
        raw = self._call({"task": "INTENT", "original_player_text": player_text,
                          "actor_id": actor_id, "allowed_target_ids": allowed_targets},
                         trusted_context=trusted_context, trace_id=trace_id)
        try:
            proposed = json.loads(raw)
        except (TypeError, ValueError):
            return "NEEDS_CLARIFICATION", None
        if not isinstance(proposed, dict) or set(proposed) != {"kind", "target_id"}:
            return "NEEDS_CLARIFICATION", None
        kind, target = proposed["kind"], proposed["target_id"]
        if kind == "ATTACK_MELEE" and type(target) is str and target in allowed_targets:
            return "ATTACK_MELEE", target
        if kind in ("HOLD", "NEEDS_CLARIFICATION", "UNSUPPORTED_RULE") and target is None:
            return kind, None
        return "NEEDS_CLARIFICATION", None

    def narrate(self, *, verified_events: tuple[str, ...]) -> str | None:
        if not isinstance(verified_events, tuple) or not verified_events:
            return None
        if any(not isinstance(e, str) for e in verified_events):
            return None
        # Only the trusted Engine's player-safe projection may be passed here.
        # The model cannot write effects or replace the authoritative log.
        return self._call({"task": "NARRATE", "verified_public_events": verified_events})[:500]