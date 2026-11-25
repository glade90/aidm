"""AIDM-DES-025.2 — trusted in-memory human-driven combat gateway.

Purpose: Drive COSTA's source-backed CombatEngine through existing DM/Meta messages;
         never accept client-supplied hit/HP/rules/dice as authoritative.
Usage: service = CombatSessionService()
       registry.register("combat_session", service)
Change Log: 2026-11-20 DAVOS — initial multi-round session gateway.

The session store is EPHEMERAL. Only the CombatEngine owns encounter HP,
rules arithmetic, raw dice, phase progression and the internal event journal.
No Bookkeeper effects are forged. The live model, when explicitly supplied,
proposes an intention and a non-authoritative narrative, never a rule result.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass, replace
from threading import RLock
from typing import Any, Protocol
from uuid import uuid4
import re

from aidm.combat.dice import DiceRoller, RollSource, SystemRandomSource
from aidm.combat.engine import (
    CombatCommand, CombatEngine, CombatError, CombatStatus,
    SurpriseKind, SurpriseResult, canonical_dice_kit,
)
from aidm.combat.fixtures import canonical_three_vs_three
from aidm.combat.rules_reference import FLAIL_RULE, RuleProfile
from aidm.combat.state import Controller
from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_result, safe_failure,
)

_IDENT = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
_TURN_LIMIT = 128
# Questions are read-only even when the browser is awaiting a combat ACTION.
# Interpret no general natural language here: only narrow status questions.
_ORC_STATUS_QUESTION = re.compile(
    r"(?:is|was)\s+(?:the\s+)?orc[ -]?0*([1-9][0-9]*)\s+"
    r"(?:dead|down|defeated|alive|still\s+alive)\s*\??",
    re.IGNORECASE,
)
_ORC_TARGET_ONLY = re.compile(r"(?:orc[ -]?)?0*([1-9][0-9]*)", re.IGNORECASE)
# Display-only cues are derived from verified engine events. In particular,
# FALL means incapacitated/out of the fight, not confirmed dead.
_COMBAT_CUE_EMOJI = {
    "HIT": "⚔️", "MISS": "💨", "FALL": "💀", "HOLD": "✋",
    "ROUND": "🔄", "INITIATIVE": "🎲",
    "VICTORY": "🏆", "DEFEAT": "💔", "END": "🏁",
}


class IntentPolicy(Protocol):
    """Untrusted intention proposal boundary; never mutates a CombatEngine."""

    def propose(self, *, player_text: str, actor_id: str,
                allowed_targets: tuple[str, ...]) -> tuple[str, str | None]: ...

    def narrate(self, *, verified_events: tuple[str, ...]) -> str | None: ...


def _exact_human_combat_choice(
    player_text: str, allowed_targets: tuple[str, ...],
) -> tuple[str, str | None] | None:
    """Resolve unambiguous UI shortcuts without an LLM (or a dice roll).

    None means natural language requiring the injected interpreter. A known
    but unavailable numeric target must be rejected here, NEVER sent to an
    LLM that could silently redirect the attack to another surviving foe.
    The authoritative controller still verifies legality after this step.
    """
    text = player_text.strip().casefold()
    if text == "hold":
        return "HOLD", None
    if text in allowed_targets:
        return "ATTACK_MELEE", text
    number = re.fullmatch(r"(?:orc[ -]?)?([0-9]+)", text)
    if number is None:
        return None
    # Avoid unbounded decimal-to-int conversion and retain arbitrary exact
    # target IDs without guessing a new numbered opponent.
    digits = number.group(1).lstrip("0")
    if not digits:
        return "NEEDS_CLARIFICATION", None
    candidate = f"orc-{digits.zfill(2)}"
    if candidate in allowed_targets:
        return "ATTACK_MELEE", candidate
    return "NEEDS_CLARIFICATION", None


class ScriptedIntentPolicy:
    """Offline, conservative human-input parser; all choices still engine-validated."""

    mode = "OFFLINE_SCRIPTED"

    def propose(self, *, player_text: str, actor_id: str,
                allowed_targets: tuple[str, ...]) -> tuple[str, str | None]:
        exact = _exact_human_combat_choice(player_text, allowed_targets)
        if exact is not None:
            return exact
        text = player_text.strip().casefold()
        if text in ("wait", "pass", "stand firm", "skip", "defend"):
            return "HOLD", None
        if re.search(r"\b(cast|spell|shoot|bow|arrow|move|run|retreat|switch|equip|draw|morale)\b", text):
            return "UNSUPPORTED_RULE", None
        if not re.search(r"\b(attack|attacks|hit|strike|swing|slash|flail)\b", text):
            return "NEEDS_CLARIFICATION", None
        targeted = []
        for target in allowed_targets:
            n = target.removeprefix("orc-").lstrip("0")
            if (target.casefold() in text
                    or re.search(rf"\borc[ -]?0?{re.escape(n)}\b", text)):
                targeted.append(target)
        if len(targeted) == 1:
            return "ATTACK_MELEE", targeted[0]
        if len(targeted) == 0 and len(allowed_targets) == 1 and "orc" in text:
            return "ATTACK_MELEE", allowed_targets[0]
        return "NEEDS_CLARIFICATION", None

    def narrate(self, *, verified_events: tuple[str, ...]) -> str | None:
        # Recorded source events speak for themselves in offline mode.
        return None


@dataclass(slots=True)
class _ActiveEncounter:
    engine: CombatEngine
    encounter_id: str
    lock: RLock
    seen_actions: set[str]
    last_narrated_seq: int = 0  # once per verified completed round for specialist only


class CombatSessionService:
    """One approved canonical 3v3 fixture per session, no external persistence.

    The random encounter ID is a local bearer-like capability in addition to
    the session key, NOT a production user authentication mechanism.
    Per-session RLock covers validation, engine submission, log projection and
    duplicate IDs. A timed-out HTTP thread may still commit: callers must
    VIEW_LOG to resynchronise, never blindly submit the same action again.
    """

    def __init__(
        self, *,
        roll_source_factory: Callable[[], RollSource] = SystemRandomSource,
        intent_policy: IntentPolicy | None = None,
        rule_profile_factory: Callable[[], RuleProfile] | None = None,
    ) -> None:
        if not callable(roll_source_factory):
            raise ValueError("Dice source factory must be callable")
        self._source_factory = roll_source_factory
        self._policy = intent_policy if intent_policy is not None else ScriptedIntentPolicy()
        declared_mode = getattr(self._policy, "mode", "INJECTED_POLICY")
        self._intent_mode = (
            declared_mode if declared_mode in ("OFFLINE_SCRIPTED", "LIVE_LLM")
            else "INJECTED_POLICY"
        )
        self._rule_profile_factory = (rule_profile_factory if rule_profile_factory is not None
            else lambda: RuleProfile(
                house_rule_overlays=(FLAIL_RULE,), fixture_loadout_confirmed=True,
            ))
        self._sessions: dict[str, _ActiveEncounter] = {}
        self._lock = RLock()

    def __call__(self, request: InternalRequest) -> InternalResult:
        return self.handle(request)

    def handle(self, request: InternalRequest) -> InternalResult:
        if request.capability != "combat" or request.operation != "combat_turn" or request.is_mutation:
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
        body = request.payload.get("combat")
        if not isinstance(body, Mapping):
            return safe_failure(request, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT)
        if not isinstance(request.session_id, str) or _IDENT.fullmatch(request.session_id) is None:
            return safe_failure(request, ErrorCode.INVALID_INPUT, status=ResultStatus.NEEDS_PLAYER_INPUT)
        kind = body.get("kind")
        if kind == "START":
            return self._start(request)
        if kind == "RESET":
            return self._reset(request)
        if kind not in ("ACTION", "VIEW_LOG"):
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
        # Keep lookup and dispatch under the same session-map lock used by
        # RESET. A stale ACTION must never mutate a replaced encounter after
        # checking its previous encounter id.
        with self._lock:
            current = self._sessions.get(request.session_id)
            if current is None or body.get("encounter_id") != current.encounter_id:
                return safe_failure(request, ErrorCode.UNAUTHORISED, status=ResultStatus.BLOCKED)
            with current.lock:
                if kind == "VIEW_LOG":
                    return self._result(request, current, body, message="Combat journal retrieved.", read_only=True)
                return self._action(request, current, body)

    def _fresh_encounter(self, session_id: str) -> _ActiveEncounter:
        """Construct a new real engine and independent roll source; no reuse."""
        fixture = canonical_three_vs_three()
        definition = fixture.encounter
        dice = canonical_dice_kit(definition)
        encounter_id = f"enc-{uuid4().hex}"
        definition = replace(definition, encounter_id=encounter_id)
        profile = self._rule_profile_factory()
        if not isinstance(profile, RuleProfile):
            raise ValueError("The configured combat rules profile is unavailable")
        surprise = SurpriseResult(
            SurpriseKind.NONE, encounter_id, "ENCOUNTER_AGENT",
            "approved-synthetic-surprise-none", profile.profile_id,
        )
        engine = CombatEngine(
            definition, surprise=surprise,
            roller=DiceRoller(self._source_factory()), dice=dice,
            profile=profile, session_id=session_id,
        )
        return _ActiveEncounter(engine, encounter_id, RLock(), set())

    def _start(self, request: InternalRequest) -> InternalResult:
        body = request.payload["combat"]
        if body.get("encounter_id") is not None:
            return safe_failure(request, ErrorCode.INVALID_INPUT, status=ResultStatus.BLOCKED)
        with self._lock:
            current = self._sessions.get(request.session_id)
            if current is None:
                try:
                    current = self._fresh_encounter(request.session_id)
                except Exception:
                    return safe_failure(request, ErrorCode.INTERNAL_ERROR)
                self._sessions[request.session_id] = current
            with current.lock:
                self._advance(current)
                return self._result(
                    request, current, body,
                    message="Combat begins: Alho, Evro and Sho face three visible orcs.",
                )

    def _reset(self, request: InternalRequest) -> InternalResult:
        """Replace only the named active encounter; never reset another session.

        An old encounter id cannot reset an unrelated/newer encounter. The
        old action ledger, HP, journal and RNG do not carry over. A decision
        token's text can recur at the same round/version/actor after reset;
        the required encounter ID scopes it, and stale IDs are rejected.
        START remains idempotent, while RESET explicitly creates a new fight.
        """
        body = request.payload["combat"]
        with self._lock:
            current = self._sessions.get(request.session_id)
            if (current is None or not isinstance(body.get("encounter_id"), str)
                    or body["encounter_id"] != current.encounter_id):
                return safe_failure(request, ErrorCode.UNAUTHORISED, status=ResultStatus.BLOCKED)
            with current.lock:
                try:
                    fresh = self._fresh_encounter(request.session_id)
                except Exception:
                    return safe_failure(request, ErrorCode.INTERNAL_ERROR)
                self._sessions[request.session_id] = fresh
                with fresh.lock:
                    self._advance(fresh)
                    return self._result(
                        request, fresh, body,
                        message="Combat reset. A fresh 3 vs 3 encounter begins: "
                                "Alho, Evro and Sho face three visible orcs.",
                    )

    def _action(self, request: InternalRequest, current: _ActiveEncounter,
                body: Mapping[str, Any]) -> InternalResult:
        engine = current.engine
        pending = engine.next_decision() if engine.status() is CombatStatus.READY else engine._pending
        if engine.outcome is not None:
            return self._result(
                request, current, body, message="This encounter has already ended.",
                error_code=ErrorCode.UNSUPPORTED_RULE, status=ResultStatus.BLOCKED,
                read_only=True,
            )
        if not isinstance(body.get("client_action_id"), str) or _IDENT.fullmatch(body["client_action_id"]) is None:
            return self._result(request, current, body, error_code=ErrorCode.INVALID_INPUT,
                                status=ResultStatus.BLOCKED, read_only=True)
        action_id = body["client_action_id"]
        if action_id in current.seen_actions:
            return self._result(request, current, body, error_code=ErrorCode.STATE_VERSION_CONFLICT,
                                status=ResultStatus.BLOCKED, read_only=True)
        if (pending is None or pending.status is not CombatStatus.NEEDS_PLAYER_INPUT
                or body.get("decision_token") != pending.token
                or body.get("expected_encounter_version") != engine.version
                or body.get("actor_id") != pending.actor_id):
            return self._result(request, current, body, error_code=ErrorCode.STATE_VERSION_CONFLICT,
                                status=ResultStatus.BLOCKED, read_only=True)
        player_text = request.payload.get("message")
        if not isinstance(player_text, str) or not player_text.strip():
            return self._result(request, current, body, error_code=ErrorCode.INVALID_INPUT,
                                status=ResultStatus.NEEDS_PLAYER_INPUT, read_only=True)
        # A status question is NOT an attack and consumes no decision/dice.
        # Query only the engine's *player-visible* defeated flag (never foe HP).
        status_question = _ORC_STATUS_QUESTION.fullmatch(player_text.strip())
        if status_question is not None:
            target_id = f"orc-{int(status_question.group(1)):02d}"
            actors = engine.player_view()["actors"]
            visible_foes = {
                actor["actor_id"]: actor
                for actor in actors if actor["side_id"] != engine.definition.party.side.side_id
            }
            foe = visible_foes.get(target_id)
            if foe is None:
                answer = "I cannot confirm the status of that opponent."
            elif foe["defeated"]:
                answer = f"{foe['name']} is down and out of the fight."
            else:
                answer = f"{foe['name']} is still in the fight."
            return self._result(
                request, current, body, message=answer,
                status=ResultStatus.NEEDS_PLAYER_INPUT, read_only=True,
            )
        # UI promises exact target names/numbers and HOLD. Resolve those
        # deterministically for ALL modes, including LIVE_LLM: model output
        # may not reliably parse a bare "1" and must not redirect an invalid
        # or already-defeated numbered target to some other living creature.
        exact = _exact_human_combat_choice(player_text, pending.allowed_targets)
        if exact is not None:
            action, target = exact
        else:
            try:
                if callable(getattr(self._policy, "propose_scoped", None)):
                    # Only trusted public Engine projection enters the specialist;
                    # request payload cannot amend HP, targets or legal moves.
                    safe_events, _ = self._public_events(engine, 0)
                    action, target = self._policy.propose_scoped(
                        player_text=player_text, actor_id=pending.actor_id,
                        allowed_targets=pending.allowed_targets,
                        trusted_context={
                            "round": pending.round_index,
                            "state_version": pending.version,
                            "actor_id": pending.actor_id,
                            "visible_state": engine.player_view(),
                            "recent_verified_events": [e["text"] for e in safe_events[-12:]],
                            "rules_profile_ref": engine.profile.profile_id,
                            "spatial_graph": "NOT_INJECTED_FIRST_SLICE",
                        },
                        trace_id=request.correlation_id,
                    )
                else:
                    action, target = self._policy.propose(
                        player_text=player_text, actor_id=pending.actor_id,
                        allowed_targets=pending.allowed_targets,
                    )
            except Exception:
                return self._result(request, current, body, error_code=ErrorCode.DEPENDENCY_UNAVAILABLE,
                                    status=ResultStatus.ERROR, read_only=True)
        if action == "UNSUPPORTED_RULE":
            return self._result(request, current, body, error_code=ErrorCode.UNSUPPORTED_RULE,
                                status=ResultStatus.NEEDS_RULING, read_only=True)
        if action not in ("HOLD", "ATTACK_MELEE"):
            return self._result(request, current, body, error_code=ErrorCode.INVALID_INPUT,
                                status=ResultStatus.NEEDS_PLAYER_INPUT, read_only=True)
        # The model/parser is NOT trusted for legality. The deterministic
        # controller re-verifies actor, token, version, target and all rules.
        command = CombatCommand(
            action_id, engine.session_id, pending.actor_id,
            pending.version, pending.token, action, target,
        )
        try:
            engine.submit(command)
        except CombatError:
            return self._result(request, current, body, error_code=ErrorCode.UNSUPPORTED_RULE,
                                status=ResultStatus.NEEDS_RULING, read_only=True)
        except Exception:
            # Do not assert rollback if an uncertain source fails after a roll.
            return self._result(request, current, body, error_code=ErrorCode.INTERNAL_ERROR,
                                status=ResultStatus.ERROR, read_only=True)
        current.seen_actions.add(action_id)
        self._advance(current)
        return self._result(
            request, current, body,
            message=(f"Combat ended: {engine.outcome}." if engine.outcome
                     else "Combat action accepted."),
        )

    def _advance(self, active: _ActiveEncounter) -> None:
        """Resolve scripted retainer/monsters until next human or terminal.

        Never execute source-unverified mechanics. Engine exceptions leave
        its own blocker/pending in place for a truthful NEEDS_RULING view.
        """
        engine = active.engine
        for number in range(_TURN_LIMIT):
            decision = engine.next_decision()
            if decision is None or decision.status is CombatStatus.NEEDS_PLAYER_INPUT:
                return
            if decision.status is not CombatStatus.NEEDS_AGENT_INPUT:
                return
            actor = next(a for a in engine.definition.members if a.encounter_actor_id == decision.actor_id)
            # Deterministic and limited NPC/retainer *intention*, NOT an
            # autonomous rules agent. Prefer Evro for opponents; if unavailable,
            # choose Sho (Alho's armour is deliberately unverified).
            if actor.controller is Controller.HUMAN:
                return
            targets = list(decision.allowed_targets)
            if decision.side_id == engine.definition.party.side.side_id:
                target = targets[0] if targets else None
            else:
                target = next((a for a in ("evro", "sho-rembo") if a in targets), None)
            kind = "ATTACK_MELEE" if target is not None else "HOLD"
            try:
                engine.submit(CombatCommand(
                    f"auto-{active.encounter_id}-{number}-{uuid4().hex[:12]}",
                    engine.session_id, decision.actor_id, decision.version,
                    decision.token, kind, target,
                ))
            except CombatError:
                # Do not silently substitute a HOLD after a failed ATTACK;
                # pending survives, and public status indicates required ruling.
                return
        # No infinite autonomous loop; engine remains at a real decision.
        return

    @staticmethod
    def _public_events(engine: CombatEngine, after: int) -> tuple[list[dict[str, Any]], int]:
        """Project internal journal only through a strict event/field allowlist.

        No monster AC/HP, hidden identity, intent prompts, source secrets,
        private event details or raw unrestricted serialisation.
        """
        events = engine.journal()
        player_ids = {
            a.encounter_actor_id: a.display_name
            for a in engine.definition.party.members
        }
        # The engine's player view is the only source of *visible* creature
        # names. Never announce unseen monster identities or exact foe HP.
        visible_foes = {
            a["actor_id"]: a["name"] for a in engine.player_view()["actors"]
            if a["side_id"] != engine.definition.party.side.side_id
        }
        allowed = []
        # Tied initiative commits one aggregate HP result for *all* attacks.
        # That result is repeated on each MELEE_RESOLVED event, including
        # misses. Gather casualties until the commit event, then announce
        # them once at that boundary: never credit a miss with a defeat.
        simultaneous_falls: set[str] = set()
        for e in events:
            d = e.details
            if e.kind == "MELEE_RESOLVED" and d.get("simultaneous") is True:
                target_id = d.get("target_id")
                if (d.get("hit") is True and type(d.get("damage")) is int
                        and d["damage"] > 0 and d.get("hp_before", 0) > 0
                        and d.get("hp_after") == 0
                        and (target_id in player_ids or target_id in visible_foes)):
                    simultaneous_falls.add(target_id)
            committed_falls: list[str] = []
            if e.kind == "SIMULTANEOUS_EXCHANGE_COMMITTED":
                committed_falls = [
                    player_ids.get(target, visible_foes.get(target, target))
                    for target in sorted(simultaneous_falls)
                ]
                simultaneous_falls.clear()
            if e.seq <= after:
                continue
            text = e.public_message
            roll = None
            cue = None
            if e.kind == "SIDE_INITIATIVE":
                cue = "INITIATIVE"
                sides = engine.definition.sides
                faces = e.details.get("faces_by_side")
                if (isinstance(faces, Mapping) and len(sides) == 2
                        and all(type(faces.get(side.side_id)) is int for side in sides)):
                    left, right = sides
                    left_face, right_face = faces[left.side_id], faces[right.side_id]
                    def public_side_name(side):
                        if side.side_id == engine.definition.party.side.side_id:
                            return "Party"
                        if all(actor.publicly_visible
                               and actor.display_name.startswith("Orc ")
                               for actor in side.members):
                            return "Orcs"
                        return side.label.title()

                    left_name, right_name = public_side_name(left), public_side_name(right)
                    verdict = (
                        "Initiative tied — both sides act simultaneously"
                        if left_face == right_face
                        else (
                            f"{left_name if left_face > right_face else right_name} "
                            f"{'wins' if left_face > right_face else 'win'} initiative and "
                            f"{'acts' if left_face > right_face else 'act'} first"
                        )
                    )
                    text = (f"Round {e.round_index} initiative: "
                            f"{left_name} {left_face}, {right_name} {right_face} — {verdict}")
            elif e.kind in ("ROUND_STARTED", "ROUND_COMPLETED"):
                cue = "ROUND"
            elif e.kind == "ACTION_HELD":
                cue = "HOLD"
            elif e.kind == "ENCOUNTER_TERMINAL":
                cue = (
                    "VICTORY" if e.details.get("outcome") == "PARTY_VICTORY"
                    else "DEFEAT" if e.details.get("outcome") == "PARTY_DEFEAT"
                    else "END"
                )
            elif e.kind == "SIMULTANEOUS_EXCHANGE_COMMITTED" and committed_falls:
                victims = ", ".join(committed_falls)
                verb = "falls" if len(committed_falls) == 1 else "fall"
                text = f"Simultaneous exchange resolves. {victims} {verb}"
                cue = "FALL"
            if e.kind == "PHASE_CHECKPOINT":
                label = e.details.get("status")
                if label in ("SCENARIO_RULE_DISABLED", "STATIONARY_SCENARIO", "NOT_DUE",
                             "BLOCKED_UNIMPLEMENTED", "READY_MELEE"):
                    text = f"{e.phase}: {label}"
            elif e.kind == "INTENT_REQUIRED":
                # Do not reveal hidden NPC plans as the log grows.
                if e.details.get("controller") == Controller.HUMAN.value:
                    text = f"{player_ids.get(e.actor_id, e.actor_id)} awaits a decision"
            elif e.kind == "MELEE_RESOLVED" and text is not None:
                d = e.details
                raw_attack, raw_damage = d.get("hit_roll"), d.get("damage_roll")
                # Own party casualties are player-observable, including when
                # enemy initiative incapacitates the retainer before his turn.
                # Never display a creature's exact HP in this projection.
                target_id = d.get("target_id")
                cue = "HIT" if d.get("hit") is True else "MISS"
                # Ordinary attack: an actual landed hit can defeat its target.
                # Tied initiative: hp_before/after reflect the *aggregate*
                # damage from the whole exchange, even for missed attacks.
                # Those falls are reported on SIMULTANEOUS_EXCHANGE_COMMITTED.
                if (d.get("simultaneous") is not True
                        and d.get("hit") is True and d.get("damage", 0) > 0
                        and d.get("hp_after") == 0
                        and d.get("hp_before", 0) > 0):
                    if target_id in player_ids:
                        text += f". {player_ids[target_id]} falls"
                        cue = "FALL"
                    elif target_id in visible_foes:
                        # Out of the fight is NOT a death vs unconscious ruling.
                        text += f". {visible_foes[target_id]} falls"
                        cue = "FALL"
                roll = {
                    "attack_face": raw_attack["face"] if raw_attack else None,
                    "attack_die_id": raw_attack["die_id"] if raw_attack else None,
                    "attack_modifier": d["hit_modifier"]["amount"] if raw_attack else None,
                    "attack_total": d.get("modified_hit"),
                    "damage_face": raw_damage["face"] if raw_damage else None,
                    "damage_die_id": raw_damage["die_id"] if raw_damage else None,
                    "damage_modifier": d["damage_modifier"]["amount"] if raw_damage else None,
                    "damage_total": d.get("damage"),
                    "hit": d.get("hit"),
                }
            if text:
                item = {
                    "seq": e.seq, "round": e.round_index, "phase": e.phase,
                    "kind": e.kind, "text": text,
                }
                if roll is not None:
                    item["roll"] = roll
                if cue is not None:
                    item["cue"] = cue
                allowed.append(item)
        return allowed, events[-1].seq if events else 0

    def _result(self, request: InternalRequest, active: _ActiveEncounter,
                body: Mapping[str, Any], *, message: str = "",
                error_code: ErrorCode | None = None, status: ResultStatus | None = None,
                read_only: bool = False) -> InternalResult:
        engine = active.engine
        snap = engine.snapshot()
        pending = engine._pending
        phase = "MELEE" if pending else ("TERMINAL" if engine.outcome else snap["status"])
        cursor = body.get("log_since_sequence", 0)
        if type(cursor) is not int or cursor < 0:
            cursor = 0
        if body.get("kind") == "VIEW_LOG":
            cursor = 0 if body.get("log_since_sequence") is None else cursor
        public_log, last_seq = self._public_events(engine, cursor)
        party = [
            {"actor_id": a["actor_id"], "name": a["name"], "hp_current": a["hp_current"],
             "hp_max": a["hp_max"]}
            for a in engine.player_view()["actors"]
            if a["side_id"] == engine.definition.party.side.side_id
        ]
        humans = {a.encounter_actor_id for a in engine.definition.party.members
                  if a.controller is Controller.HUMAN}
        next_prompt = None
        if pending is not None and pending.actor_id in humans and not engine.outcome:
            visible = {a["actor_id"]: a["name"] for a in engine.player_view()["actors"]}
            target_labels = [visible[t] for t in pending.allowed_targets if t in visible]
            next_prompt = {
                "actor_id": pending.actor_id, "prompt": (
                    f"{visible.get(pending.actor_id, pending.actor_id)}: "
                    f"choose a melee attack target ({', '.join(target_labels)}) "
                    "by name or number, or say HOLD."
                ),
                "decision_token": pending.token,
                "allowed_targets": list(pending.allowed_targets),
            }
        if status is None:
            status = (
                ResultStatus.COMPLETED if engine.outcome
                else ResultStatus.NEEDS_RULING if engine.status() is CombatStatus.NEEDS_RULING
                else ResultStatus.NEEDS_PLAYER_INPUT if next_prompt
                else ResultStatus.NEEDS_RULING
            )
        view = {
            "encounter_id": active.encounter_id,
            "intent_mode": self._intent_mode,
            "state_version": snap["version"],
            "current_round": snap["round_index"],
            "phase_label": phase,
            "terminal": bool(engine.outcome),
            "outcome": engine.outcome,
            "awaiting_player": next_prompt is not None,
            "next_decision": next_prompt,
            "new_log_entries": public_log,
            "log_next_cursor": last_seq,
            "party_status": party,  # Owner-visible HP during the encounter.
            "surviving_party_summary": party if engine.outcome else None,
            "deferred_labels": ["Missile and magic not resolved",
                                "Movement limited to stationary scenario",
                                "Morale deliberately disabled in scenario"],
        }
        if error_code is None and status is ResultStatus.NEEDS_RULING:
            error_code = ErrorCode.UNSUPPORTED_RULE
        if status is ResultStatus.ERROR:
            summary = "Combat result is uncertain; inspect the current log before any retry."
        elif error_code is ErrorCode.INVALID_INPUT:
            allowed = pending.allowed_targets if pending else ()
            visible = {
                a["actor_id"]: a for a in engine.player_view()["actors"]
                if a["side_id"] != engine.definition.party.side.side_id
            }
            requested = _ORC_TARGET_ONLY.fullmatch(
                str(request.payload.get("message", "")).strip()
            )
            target_id = (f"orc-{int(requested.group(1)):02d}"
                         if requested is not None else None)
            if target_id in visible and visible[target_id]["defeated"]:
                summary = f"{visible[target_id]['name']} is already down and cannot be targeted."
            else:
                summary = "I couldn't identify a single legal target."
            choices = [visible[t]["name"] for t in allowed if t in visible]
            if choices:
                summary += f" Choose from {', '.join(choices)} by name or number, or HOLD."
            else:
                summary += " Say HOLD or ask for clarification."
        elif error_code is ErrorCode.STATE_VERSION_CONFLICT:
            summary = "That combat decision is no longer current; inspect the combat log."
        elif error_code is ErrorCode.UNSUPPORTED_RULE and status is ResultStatus.NEEDS_RULING:
            summary = "That action needs a rules ruling; I cannot resolve it as written."
        elif status is ResultStatus.BLOCKED:
            summary = message or "That action is blocked."
        elif read_only:
            summary = message or "Combat journal retrieved."
        else:
            # A DM must report VERIFIED in-world events, not 'action accepted'.
            # Raw dice and phases remain in the separate complete audit log.
            lines = []
            terminal_in_log = any(
                event["kind"] == "ENCOUNTER_TERMINAL" for event in public_log
            )
            if message and message != "Combat action accepted." and not (
                terminal_in_log and message.startswith("Combat ended:")
            ):
                lines.append(message)
            notable = [
                event for event in public_log
                if event["kind"] in (
                    "ROUND_STARTED", "SIDE_INITIATIVE", "MELEE_RESOLVED",
                    "ACTION_HELD", "ROUND_COMPLETED", "ENCOUNTER_TERMINAL",
                    "SIMULTANEOUS_EXCHANGE_COMMITTED",
                )
            ]
            if notable:
                # Each verified event gets a real newline; the browser
                # preserves it with white-space: pre-wrap. Blank line before
                # a new round makes transitions easy to scan.
                lines.append("\n".join(
                    ("\n" if event["kind"] == "ROUND_STARTED" else "")
                    + f"{_COMBAT_CUE_EMOJI.get(event.get('cue'), '')} {event['text'].rstrip('.')}.".strip()
                    for event in notable
                ))
            if engine.outcome and not any(engine.outcome in line for line in lines):
                badge = _COMBAT_CUE_EMOJI["VICTORY"] if engine.outcome == "PARTY_VICTORY" else _COMBAT_CUE_EMOJI["DEFEAT"]
                lines.append(f"{badge} Combat ended: {engine.outcome}.")
            if not lines and not next_prompt:
                lines.append("The combat controller requires a ruling.")
            summary = "\n\n".join(lines)
        if next_prompt and (status is ResultStatus.NEEDS_PLAYER_INPUT
                            or (error_code is not None and status is not ResultStatus.ERROR)):
            summary = (summary + "\n\n" if summary else "") + next_prompt["prompt"]
        if not read_only and status in (ResultStatus.NEEDS_PLAYER_INPUT, ResultStatus.COMPLETED):
            if getattr(self._policy, "narrate_on_round_complete", False):
                # SPECIALIST path: one narrative after a mechanically complete
                # round, never one call per human attack or read-only VIEW_LOG.
                all_public, _ = self._public_events(engine, 0)
                boundaries = [e for e in all_public if e["seq"] > active.last_narrated_seq
                              and e["kind"] in ("ROUND_COMPLETED", "ENCOUNTER_TERMINAL")]
                if boundaries:
                    boundary = boundaries[-1]
                    # Deduplicate terminal event if a normal round-close already
                    # generated a narrative for this round.
                    active.last_narrated_seq = boundary["seq"]
                    narratable = tuple(e["text"] for e in all_public
                                       if e["round"] == boundary["round"]
                                       and e["seq"] <= boundary["seq"]
                                       and e["kind"] in (
                                           "ROUND_STARTED", "SIDE_INITIATIVE",
                                           "MELEE_RESOLVED", "ACTION_HELD",
                                           "SIMULTANEOUS_EXCHANGE_COMMITTED",
                                           "ENCOUNTER_TERMINAL",
                                       ))
                else:
                    narratable = ()
            else:
                # Existing DES-025.2 policy retains old per-action behaviour.
                narratable = tuple(e["text"] for e in public_log[-3:])
            if narratable:
                try:
                    flavour = self._policy.narrate(verified_events=narratable)
                except Exception:
                    flavour = None
                if isinstance(flavour, str) and flavour.strip():
                    summary += " Narrative (non-authoritative): " + flavour.strip()[:500]
        return make_result(
            request, status, safe_summary=summary, error_code=error_code,
            data={"combat_view": view},
        )
