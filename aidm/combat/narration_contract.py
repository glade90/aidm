"""AIDM-DES-004.2.1 — untrusted CombatAgent narration response contract.

Purpose: Extract player-facing prose only from a complete, validated specialist
         response. A failed extraction returns None so the verified journal is
         displayed instead. This module never handles combat mechanics.
Usage: parse_narration_response('{"narration":"Orc 1 falls."}')
Change Log: 2026-11-26 COSTA — raw-JSON narration UAT defect repair.
"""
from __future__ import annotations

import json
import re

NARRATION_MAX_CHARACTERS = 500
_NARRATION_MAX_RAW_CHARACTERS = 4000
_JSON_FENCE = re.compile(r"\A```json\s*\n(?P<body>.*?)\n```\Z", re.IGNORECASE | re.DOTALL)


def parse_narration_response(raw: str) -> str | None:
    """Validate BEFORE length limiting; never display malformed JSON wrappers.

    Preferred wire format is exactly ``{"narration": "player-safe prose"}``.
    Explicit backwards-compatibility format is unwrapped natural-language prose.
    A complete markdown-json fence is accepted as a legacy structured wrapper.
    Raw JSON strings, arrays, extra object fields, partial/malformed objects,
    arbitrary markdown fences and object-shaped plaintext fail closed.
    """
    if not isinstance(raw, str) or not (value := raw.strip()):
        return None
    if len(value) > _NARRATION_MAX_RAW_CHARACTERS:
        return None

    if value.startswith("```"):
        fence = _JSON_FENCE.fullmatch(value)
        if fence is None:
            return None
        value = fence.group("body").strip()

    if value.startswith("{"):
        try:
            parsed = json.loads(value)
        except (ValueError, TypeError):
            return None
        if (not isinstance(parsed, dict) or set(parsed) != {"narration"}
                or type(parsed["narration"]) is not str):
            return None
        prose = parsed["narration"].strip()
    elif (value.startswith(("[", "`", "}", "\"")) or value in ("null", "true", "false")
          or "{" in value or "}" in value or "```" in value):
        return None
    else:
        # Legacy plain prose is intentionally supported. Do not strip markup
        # from an object-like response or guess how to repair partial JSON.
        prose = value

    if not prose or "{" in prose or "}" in prose or "```" in prose:
        return None
    if any(ord(c) < 32 and c not in ("\n", "\t", "\r") for c in prose):
        return None
    prose = " ".join(prose.split())
    if not prose:
        return None
    if len(prose) <= NARRATION_MAX_CHARACTERS:
        return prose
    # Word-boundary trimming ONLY after validation: no partial JSON exposure.
    limit = NARRATION_MAX_CHARACTERS - 1
    head = prose[:limit]
    if len(prose) > limit and prose[limit] not in (" ", "\t", "\n"):
        head = head.rsplit(" ", 1)[0]
    return (head.rstrip() + "…") if head else None
