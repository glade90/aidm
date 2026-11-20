"""Deterministic FastAPI ASGI factory and safe HTTP tests (AIDM-DES-013.1).

Usage: python -m pytest aidm/meta/test/test_http.py -q
Change Log: 2026-11-20 COSTA — thin health/status and lifespan tests.
"""
from __future__ import annotations

import re

from fastapi.testclient import TestClient
import pytest

from aidm.config import ConfigError, load_config
from aidm.meta.http import create_app
from aidm.meta.runtime import LifecycleState, MissingServiceError, ServiceRegistry


class FakeLogger:
    def __init__(self):
        self.start_calls = 0
        self.close_calls = 0

    def start(self, settings): self.start_calls += 1
    def info(self, message): pass
    def error(self, message): pass
    def close(self): self.close_calls += 1


def settings(mode="development", **overrides):
    source = {"AIDM_MODE": mode, **overrides}
    return load_config(environ=source, dotenv_path="/definitely/nonexistent/.env")


def test_app_creation_never_starts_runtime_or_logger():
    logger = FakeLogger()
    app = create_app(settings("test"), logger=logger)
    assert app.state.meta_runtime.state is LifecycleState.BOOTSTRAPPING
    assert logger.start_calls == 0
    assert "mock_tool" in app.state.registry.names()


def test_health_status_and_graceful_shutdown():
    logger = FakeLogger()
    app = create_app(settings("development"), logger=logger)
    with TestClient(app) as client:
        assert app.state.meta_runtime.ready
        health = client.get("/health")
        assert health.status_code == 200
        assert health.json() == {"state": "READY", "ready": True}
        status = client.get("/status")
        assert status.status_code == 200
        data = status.json()
        assert data["state"] == "READY" and data["capabilities"] == ["mock_tool"]
        assert set(data["build"]) == {
            "version", "source_sha", "build_id", "build_type", "build_timestamp", "dirty",
        }
        assert client.get("/docs").status_code == 200
        assert client.get("/openapi.json").status_code == 200
    assert app.state.meta_runtime.state is LifecycleState.STOPPED
    assert logger.start_calls == logger.close_calls == 1


def test_safe_nonready_health_and_status():
    app = create_app(settings("test"), logger=FakeLogger())
    # Plain TestClient without its context manager does not enter lifespan.
    client = TestClient(app)
    health = client.get("/health")
    status = client.get("/status")
    assert health.status_code == 503 and health.json() == {"state": "BOOTSTRAPPING", "ready": False}
    assert status.status_code == 503
    assert status.json()["capabilities"] == []
    assert status.json()["build"]["version"] == "UNKNOWN"


@pytest.mark.parametrize("mode", ["test", "ci", "production"])
def test_non_development_has_no_docs(mode):
    app = create_app(settings(mode), logger=FakeLogger())
    with TestClient(app) as client:
        assert client.get("/docs").status_code == 404
        assert client.get("/openapi.json").status_code == 404
        assert client.get("/health").status_code == 200


def test_invalid_configuration_fails_at_factory_no_ready(monkeypatch):
    monkeypatch.setenv("AIDM_MODE", "invalid")
    with pytest.raises(ConfigError) as exc:
        create_app(logger=FakeLogger())
    assert str(exc.value) == "Missing or invalid configuration key: AIDM_MODE"


def test_injected_missing_service_fails_lifespan():
    registry = ServiceRegistry(required=("dm", "mock_tool"))
    registry.register("mock_tool", object())
    app = create_app(settings("test"), registry=registry, logger=FakeLogger())
    with pytest.raises(MissingServiceError):
        with TestClient(app):
            pass
    assert app.state.meta_runtime.state is LifecycleState.FAILED


def test_external_pydantic_health_schema_with_docs():
    app = create_app(settings("development"), logger=FakeLogger())
    with TestClient(app) as client:
        schema = client.get("/openapi.json").json()
        assert "/health" in schema["paths"]
        assert "/status" in schema["paths"]
        assert "/api/turn" not in schema["paths"]
        assert "HealthResponse" in schema["components"]["schemas"]
        assert "StatusResponse" in schema["components"]["schemas"]


def test_status_never_exposes_secrets_or_hidden_world():
    app = create_app(settings("development"), logger=FakeLogger())
    with TestClient(app) as client:
        response = client.get("/status")
        body = response.text
        for forbidden in ("SECRET_TOKEN_VALUE", "secret_room", "player_prompt", "_secrets", ".env", "logs/technical.log"):
            assert forbidden not in body
        assert response.json()["capabilities"] == ["mock_tool"]


def test_registry_supports_davos_injected_dm_dispatcher():
    registry = ServiceRegistry(required=("dm", "dispatcher", "mock_tool"))
    dm, dispatcher, tool = object(), object(), object()
    registry.register("dm", dm)
    registry.register("dispatcher", dispatcher)
    registry.register("mock_tool", tool)
    app = create_app(settings("test"), registry=registry, logger=FakeLogger())
    with TestClient(app) as client:
        assert app.state.registry.get("dm") is dm
        assert app.state.meta_runtime.registry.get("dispatcher") is dispatcher
        assert app.state.registry.get("mock_tool") is tool
        assert client.get("/status").json()["capabilities"] == ["dispatcher", "dm", "mock_tool"]


def test_factory_has_no_turn_endpoint_and_no_routing_policy():
    app = create_app(settings("test"), logger=FakeLogger())
    with TestClient(app) as client:
        assert client.post("/api/turn", json={"message": "attack"}).status_code == 404
        assert client.get("/health").json()["ready"] is True


def test_independent_apps_do_not_share_registry_state():
    a = create_app(settings("test"), logger=FakeLogger())
    b = create_app(settings("test"), logger=FakeLogger())
    assert a.state.registry is not b.state.registry
    assert a.state.meta_runtime is not b.state.meta_runtime
    with TestClient(a), TestClient(b):
        assert a.state.registry.get("mock_tool") is not b.state.registry.get("mock_tool")