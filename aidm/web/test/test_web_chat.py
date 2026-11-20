"""AIDM-DES-014.1 — Meta-served browser chat and real stub integration tests.

Purpose: Prove one local app, static page, and Browser/Meta/DM/Combat seam.
Usage: python -m pytest aidm/web/test/test_web_chat.py -q
Change Log: 2026-11-20 DAVOS — first HTML chat and stub roundtrip tests.

Browser DOM/fetch contract tests are separate, offline Node built-in tests at
aidm/web/test/chat_client.test.mjs; pytest does not execute JavaScript.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from braider import FakeModelRuntime, ModelChoice, ModelTarget
from aidm.combat import CombatAgent
from aidm.config import load_config
from aidm.internal_messages import ErrorCode, ResultStatus, safe_failure
from aidm.web import create_chat_app


class FakeLogger:
    def start(self, settings): pass
    def info(self, message): pass
    def error(self, message): pass
    def close(self): pass


def app(**overrides):
    settings = load_config(
        environ={"AIDM_MODE": "test"},
        dotenv_path="/definitely/missing/.env",
    )
    return create_chat_app(settings=settings, logger=FakeLogger(), **overrides)


def test_single_meta_app_serves_chat_and_same_origin_modules():
    instance = app()
    with TestClient(instance) as client:
        page = client.get("/chat")
        assert page.status_code == 200
        assert "<!doctype html>" in page.text
        assert 'id="transcript"' in page.text
        assert 'id="chat-form"' in page.text
        assert 'id="player-message"' in page.text
        assert 'id="send-button"' in page.text
        assert 'src="/static/chat.mjs"' in page.text
        assert "/api/turn" not in page.text  # The JS module owns HTTP wiring.
        assert "default-src 'none'" in page.headers["content-security-policy"]
        assert page.headers["cache-control"] == "no-store"

        assert client.get("/").url.path == "/chat"
        for filename in ("client.mjs", "chat.mjs", "chat.css"):
            asset = client.get(f"/static/{filename}")
            assert asset.status_code == 200
        assert "javascript" in client.get("/static/client.mjs").headers["content-type"]
        assert client.get("/health").json() == {"state": "READY", "ready": True}
        assert client.get("/status").json()["capabilities"] == ["combat", "dm"]


def test_frontend_only_references_existing_meta_turn_api_and_safe_text():
    with TestClient(app()) as client:
        js = client.get("/static/client.mjs").text
        ui = client.get("/static/chat.mjs").text
        assert 'this.fetcher("/api/turn"' in js
        assert "POST" in js and "session_id" in js and "correlation_id" in js
        assert "fetch(" not in ui and "/api/combat" not in (js + ui)
        assert "textContent" in ui
        assert "innerHTML" not in ui
        assert 'role="log"' in client.get("/chat").text
        assert "maxlength=\"4000\"" in client.get("/chat").text


def test_real_meta_dm_combat_chain_preserves_original_period_text_and_ids():
    combat_runtime = FakeModelRuntime("SECRET proposal never returned")
    targets = {ModelChoice.BALANCED: ModelTarget("offline-fake", "synthetic")}
    combat_agent = CombatAgent(
        runtime=combat_runtime, model_targets=targets,
        approved_encounter_context="Only synthetic test actors",
    )
    calls = []

    def spy_combat(request):
        calls.append(request)
        return combat_agent.handle(request)

    with TestClient(app(combat_handler=spy_combat)) as client:
        original = "I swing my sword at the orc."
        response = client.post("/api/turn", json={
            "message": original, "session_id": "browser-session",
            "correlation_id": "browser-correlation",
        })
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "COMPLETED"
        assert body["message"] == (
            "Simulation only: the combat intention was received; "
            "no dice were rolled, no damage was calculated, "
            "and no hit points or world state were changed."
        )
        assert body["session_id"] == "browser-session"
        assert body["correlation_id"] == "browser-correlation"
        assert body["request_id"].startswith("call-")
        assert body["simulated"] is True
        assert body["tool_outcome"] == {"mock": True}
        assert "SECRET" not in response.text
        assert "committed_effects" not in body and "event_refs" not in body

        assert len(calls) == 1 and len(combat_runtime.calls) == 1
        assert calls[0].payload["player_text"] == original
        assert calls[0].session_id == body["session_id"]
        assert calls[0].correlation_id == body["correlation_id"]
        assert calls[0].parent_request_id == body["request_id"]
        assert calls[0].request_id != body["request_id"]
        assert calls[0].encounter_id == "synthetic-combat-demo"
        assert combat_runtime.calls[0]["input_text"] == original


def test_two_valid_browser_turns_use_same_session_distinct_correlations():
    with TestClient(app()) as client:
        bodies = [
            client.post("/api/turn", json={
                "message": "I swing my sword at the orc.",
                "session_id": "same-session",
                "correlation_id": f"turn-{i}",
            }).json()
            for i in (1, 2)
        ]
    assert [x["status"] for x in bodies] == ["COMPLETED", "COMPLETED"]
    assert [x["correlation_id"] for x in bodies] == ["turn-1", "turn-2"]
    assert [x["session_id"] for x in bodies] == ["same-session", "same-session"]
    assert bodies[0]["request_id"] != bodies[1]["request_id"]


def test_noncombat_turn_blocks_and_good_turn_afterwards_recovers():
    with TestClient(app()) as client:
        blocked = client.post("/api/turn", json={
            "message": "I open the chest", "session_id": "session-1",
            "correlation_id": "blocked-1",
        })
        assert blocked.status_code == 200
        assert blocked.json()["status"] == "BLOCKED"
        assert blocked.json()["error"]["code"] == "UNKNOWN_CAPABILITY"
        assert blocked.json()["simulated"] is False
        assert "hit points" not in blocked.text

        invalid = client.post("/api/turn", json={"message": ""})
        assert invalid.status_code == 422
        assert invalid.json()["status"] == "NEEDS_PLAYER_INPUT"

        good = client.post("/api/turn", json={
            "message": "I swing my sword at the orc.",
            "session_id": "session-1", "correlation_id": "good-2",
        })
        assert good.status_code == 200
        assert good.json()["status"] == "COMPLETED"
        assert client.get("/health").json()["ready"] is True


def test_unavailable_service_returns_safe_error_then_runtime_can_start():
    instance = app()
    # No lifespan context: same Meta app exists but is not yet ready.
    before = TestClient(instance).post(
        "/api/turn", json={"message": "I swing my sword at the orc."},
    )
    assert before.status_code == 503
    assert before.json()["error"]["code"] == "DEPENDENCY_UNAVAILABLE"
    with TestClient(instance) as client:
        after = client.post(
            "/api/turn", json={"message": "I swing my sword at the orc."},
        )
        assert after.status_code == 200
        assert after.json()["status"] == "COMPLETED"


def test_handler_failure_is_safe_and_does_not_echo_raw_exception():
    calls = []

    def failing_combat(request):
        calls.append(request)
        raise RuntimeError("SECRET backend diagnostic")

    with TestClient(app(combat_handler=failing_combat)) as client:
        response = client.post(
            "/api/turn", json={
                "message": "I swing my sword at the orc.",
                "correlation_id": "error-trace", "session_id": "session-1",
            },
        )
        assert response.status_code == 503
        body = response.json()
        assert body["status"] == "ERROR"
        assert body["error"]["code"] == "INTERNAL_ERROR"
        assert body["correlation_id"] == "error-trace"
        assert "SECRET" not in response.text
        assert len(calls) == 1
        assert client.get("/health").json()["ready"] is True


def test_specialist_clarification_remains_safe_under_injected_handler():
    def needs_input(request):
        return safe_failure(request, ErrorCode.INVALID_INPUT,
                            status=ResultStatus.NEEDS_PLAYER_INPUT)

    with TestClient(app(combat_handler=needs_input)) as client:
        response = client.post(
            "/api/turn", json={"message": "I swing my sword at the orc."},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "NEEDS_PLAYER_INPUT"
        assert response.json()["error"]["code"] == "INVALID_INPUT"
        assert response.json()["simulated"] is False
