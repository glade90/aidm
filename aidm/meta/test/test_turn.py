"""Offline request-to-one-mock-tool tests for AIDM-DES-013.2.

Usage: python -m pytest aidm/meta/test/test_turn.py -q
Change Log: 2026-11-20 DAVOS — Functional BUILD/TEST before independent BON UAT.
            2026-11-20 DAVOS — stabilise timeout fixture on Windows.
"""

from __future__ import annotations

from threading import Event

from fastapi.testclient import TestClient
import pytest

from aidm.config import load_config
from aidm.internal_messages import ResultStatus, make_result
from aidm.meta.http import create_app
from aidm.meta.mock_turn import MockDispatcher, MockDungeonMaster, create_mock_app
from aidm.meta.runtime import MockTool, ServiceRegistry


class FakeLogger:
    def start(self, settings): pass
    def info(self, message): pass
    def error(self, message): pass
    def close(self): pass


def settings(mode="test", timeout="0.5"):
    return load_config(
        environ={"AIDM_MODE": mode, "AIDM_REQUEST_TIMEOUT_SECONDS": timeout},
        dotenv_path="/definitely/missing/.env",
    )


def demo(mode="test", timeout="0.5"):
    return create_mock_app(settings=settings(mode, timeout), logger=FakeLogger())


def injected(dm, *, timeout="0.5"):
    registry = ServiceRegistry(required=("dm", "mock_tool", "dispatcher"))
    registry.register("dm", dm)
    registry.register("mock_tool", MockTool())
    registry.register("dispatcher", object())
    return create_app(settings=settings(timeout=timeout), registry=registry, logger=FakeLogger())


def test_harmless_turn_is_real_tool_output_with_ids_and_no_effects():
    app = demo()
    with TestClient(app) as client:
        response = client.post("/api/turn", json={
            "message": "Hello there", "session_id": "session-1", "correlation_id": "correlation-1",
        })
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "COMPLETED"
        assert body["message"] == "Mock tool response only. No game state was changed."
        assert body["session_id"] == "session-1"
        assert body["correlation_id"] == "correlation-1"
        assert body["request_id"].startswith("call-")
        assert body["simulated"] is True and body["tool_outcome"] == {"mock": True}
        assert "committed_effects" not in body and "event_refs" not in body


def test_attack_is_explicitly_a_mock_with_no_combat_claims():
    with TestClient(demo()) as client:
        response = client.post("/api/turn", json={"message": "What happens if I attack the orc?"})
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "COMPLETED" and body["simulated"]
        assert "mock attack" in body["message"].lower()
        assert "no attack roll, damage, or hp change was calculated" in body["message"].lower()
        assert body["tool_outcome"] == {"mock": True}


@pytest.mark.parametrize("payload", [
    {}, {"message": ""}, {"message": "   "}, {"message": 123},
    {"message": "hello", "session_id": "not allowed !"},
    {"message": "hello", "caller": "Bookkeeper"},
    {"message": "hello", "correlation_id": "bad\nID"},
])
def test_invalid_inputs_are_safe_clarification_not_stack_traces(payload):
    with TestClient(demo()) as client:
        response = client.post("/api/turn", json=payload)
        assert response.status_code == 422
        body = response.json()
        assert body["status"] == "NEEDS_PLAYER_INPUT"
        assert body["error"]["code"] == "INVALID_INPUT"
        assert body["correlation_id"]
        assert "traceback" not in response.text.lower()
        assert "Bookkeeper" not in response.text


def test_malformed_json_is_safe_and_runtime_stays_ready():
    with TestClient(demo()) as client:
        response = client.post(
            "/api/turn", content=b'{"message":', headers={"content-type": "application/json"},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "INVALID_INPUT"
        assert client.get("/health").json() == {"state": "READY", "ready": True}
        assert client.post("/api/turn", json={"message": "hello"}).status_code == 200


def test_unknown_mock_action_is_blocked_without_tool_execution():
    with TestClient(demo()) as client:
        response = client.post("/api/turn", json={"message": "tool:teleport"})
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "BLOCKED"
        assert body["error"]["code"] == "UNKNOWN_CAPABILITY"
        assert body["simulated"] is False and body["tool_outcome"] is None


def test_exactly_one_tool_call_per_request_and_no_context_leak():
    calls = []

    class CountingTool:
        def __call__(self, request):
            calls.append(request)
            return MockTool()(request)

    registry = ServiceRegistry(required=("dm", "dispatcher", "mock_tool"))
    registry.register("mock_tool", CountingTool())
    registry.register("dispatcher", MockDispatcher(registry))
    registry.register("dm", MockDungeonMaster(registry))
    app = create_app(settings=settings(), registry=registry, logger=FakeLogger())
    with TestClient(app) as client:
        one = client.post("/api/turn", json={"message": "hello", "session_id": "s1", "correlation_id": "c1"}).json()
        two = client.post("/api/turn", json={"message": "hello again", "session_id": "s2", "correlation_id": "c2"}).json()
        assert len(calls) == 2
        assert [call.session_id for call in calls] == ["s1", "s2"]
        assert [call.correlation_id for call in calls] == ["c1", "c2"]
        assert all(call.parent_request_id is not None for call in calls)
        assert calls[0].request_id != calls[1].request_id
        assert one["request_id"] != two["request_id"]
        assert one["session_id"] == "s1" and two["session_id"] == "s2"


def test_handler_exception_is_sanitised_and_next_turn_works():
    class FailsOnce:
        count = 0

        def __call__(self, request):
            self.count += 1
            if self.count == 1:
                raise RuntimeError("SECRET_TOKEN_VALUE")
            return make_result(request, ResultStatus.COMPLETED, safe_summary="Recovered", data={"mock": True})

    app = injected(FailsOnce())
    with TestClient(app) as client:
        failed = client.post("/api/turn", json={"message": "hello", "correlation_id": "cid"})
        assert failed.status_code == 503
        assert failed.json()["status"] == "ERROR"
        assert failed.json()["error"]["code"] == "INTERNAL_ERROR"
        assert failed.json()["correlation_id"] == "cid"
        assert "SECRET_TOKEN_VALUE" not in failed.text
        assert client.post("/api/turn", json={"message": "hello"}).json()["message"] == "Recovered"
        assert client.get("/health").json()["ready"] is True


def test_timeout_is_bounded_without_retries_and_followup_works():
    # Deliberately block the first read-only fake until *after* HTTP timeout.
    # A 10ms timer with sleep(80ms) raced with Windows thread scheduling.
    started, release = Event(), Event()

    class SlowOnce:
        count = 0

        def __call__(self, request):
            self.count += 1
            if self.count == 1:
                started.set()
                release.wait(timeout=5)  # Safety backstop if an assertion fails.
            return make_result(request, ResultStatus.COMPLETED, safe_summary="Recovered")

    dm = SlowOnce()
    app = injected(dm, timeout="0.5")
    with TestClient(app) as client:
        try:
            failed = client.post("/api/turn", json={"message": "hello", "correlation_id": "timeout-cid"})
            assert started.is_set(), "First fake invocation must actually begin"
            assert failed.status_code == 504
            assert failed.json()["error"]["code"] == "TIMEOUT"
            assert failed.json()["correlation_id"] == "timeout-cid"
        finally:
            release.set()  # Always let the detached, read-only worker finish.
        assert client.post("/api/turn", json={"message": "hello"}).json()["message"] == "Recovered"
        assert dm.count == 2  # One timed-out call and one recovery; no retries.
        assert client.get("/status").json()["state"] == "READY"


def test_result_projection_does_not_expose_internal_data_or_conflate_handoff():
    class HiddenDM:
        def __call__(self, request):
            return make_result(request, ResultStatus.HANDOFF, data={"hidden_room": "SECRET_TOKEN_VALUE"})

    with TestClient(injected(HiddenDM())) as client:
        response = client.post("/api/turn", json={"message": "look"})
        assert response.status_code == 200
        assert response.json()["status"] == "HANDOFF"
        assert response.json()["simulated"] is False
        assert "SECRET_TOKEN_VALUE" not in response.text
        assert "no action is confirmed complete" in response.json()["message"]


def test_readiness_health_docs_and_shutdown_are_owned_by_meta():
    app = demo("development")
    before = TestClient(app)
    assert before.post("/api/turn", json={"message": "hello"}).status_code == 503
    assert before.get("/health").status_code == 503
    with TestClient(app) as client:
        assert client.get("/health").json()["ready"] is True
        schema = client.get("/openapi.json").json()
        assert "/api/turn" in schema["paths"]
        assert "TurnRequest" in schema["components"]["schemas"]
        assert "TurnResponse" in schema["components"]["schemas"]
        assert client.get("/docs").status_code == 200
        assert client.post("/api/turn", json={"message": "hello"}).status_code == 200
        assert client.get("/status").json()["capabilities"] == ["dispatcher", "dm", "mock_tool"]
    assert app.state.meta_runtime.state.value == "STOPPED"
