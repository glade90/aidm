"""Local browser-chat composition for AIDM's existing Meta Service.

Purpose: Serve one static chat page on the very same FastAPI/Meta application
         as POST /api/turn, using the real thin DM and Combat stubs.
Usage: python -m uvicorn aidm.web.app:create_chat_app --factory --host 127.0.0.1 --port 8000
Change Log: 2026-11-20 DAVOS — AIDM-DES-014.1 local browser prototype.
            2026-11-20 DAVOS — AIDM-DES-025.2 actual combat session injection.

No second HTTP server, database or duplicate rules engine. A live model is
strictly opt-in; default sessions use deterministic scripted intentions.
"""

from __future__ import annotations

from collections.abc import Callable
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from braider import FakeModelRuntime, ModelChoice, ModelTarget

from aidm.combat import CombatAgent
from aidm.combat.session import CombatSessionService, IntentPolicy
from aidm.combat.live_policy import OpenAIResponsesPolicy
from aidm.config import Settings, load_config
from aidm.dm import DungeonMasterAgent
from aidm.internal_messages import InternalRequest, InternalResult
from aidm.meta.http import create_app
from aidm.meta.runtime import RuntimeLogger, ServiceRegistry

_STATIC = Path(__file__).resolve().parent / "static"
_CSP = (
    "default-src 'none'; script-src 'self'; style-src 'self'; "
    "connect-src 'self'; img-src 'self'; base-uri 'none'; "
    "form-action 'none'; frame-ancestors 'none'"
)


def create_chat_app(
    *, settings: Settings | None = None, logger: RuntimeLogger | None = None,
    combat_handler: Callable[[InternalRequest], InternalResult] | None = None,
    dm_handler: Callable[[InternalRequest], InternalResult] | None = None,
    combat_session_handler: Callable[[InternalRequest], InternalResult] | None = None,
    intent_policy: IntentPolicy | None = None,
) -> FastAPI:
    """Compose *one* Meta app with injectable stub agents and a local chat page.

    A test can wrap/inject the Combat handler to prove the real call chain.
    Both defaults are offline synthetic agents and do not require API keys.
    """
    targets = {ModelChoice.BALANCED: ModelTarget("offline-fake", "synthetic")}

    if combat_handler is None:
        combat = CombatAgent(
            runtime=FakeModelRuntime("Private synthetic intent, never a result"),
            model_targets=targets,
            approved_encounter_context="Approved synthetic combat training encounter",
        )
        combat_handler = combat.handle

    if combat_session_handler is None:
        if intent_policy is None and os.environ.get("AIDM_LIVE_LLM", "").strip() == "1":
            # Live model use is opt-in at launch. The secret loader is explicit
            # and never runs on import. Tests can inject a fake IntentPolicy.
            configured = settings if settings is not None else load_config(
                required_secrets=("OPENAI_API_KEY",),
            )
            secret = configured.get_secret("OPENAI_API_KEY")
            model = os.environ.get("AIDM_LLM_MODEL", "").strip()
            if not secret or not model:
                raise ValueError("Live model requires explicitly configured key and model")
            intent_policy = OpenAIResponsesPolicy(api_key=secret, model=model)
        service = CombatSessionService(intent_policy=intent_policy)
        combat_session_handler = service.handle

    if dm_handler is None:
        dm_handler = DungeonMasterAgent(
            runtime=FakeModelRuntime("DM model must not run"),
            model_targets=targets,
            combat_handler=combat_handler,
            combat_session_handler=combat_session_handler,
            approved_encounter_id="synthetic-combat-demo",
        )

    registry = ServiceRegistry(required=("dm", "combat", "combat_session"))
    registry.register("combat", combat_handler)
    registry.register("combat_session", combat_session_handler)
    registry.register("dm", dm_handler)

    app = create_app(settings=settings, registry=registry, logger=logger)
    app.mount("/static", StaticFiles(directory=_STATIC), name="chat-static")

    @app.get("/", include_in_schema=False)
    def entry() -> RedirectResponse:
        return RedirectResponse("/chat", status_code=307)

    @app.get("/chat", include_in_schema=False)
    def chat() -> FileResponse:
        return FileResponse(
            _STATIC / "index.html",
            media_type="text/html",
            headers={"Cache-Control": "no-store", "Content-Security-Policy": _CSP},
        )

    return app
