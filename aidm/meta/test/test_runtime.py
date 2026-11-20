"""Offline lifecycle/registration tests for AIDM-DES-013.1.

Usage: python -m pytest aidm/meta/test/test_runtime.py -q
Change Log: 2026-11-20 COSTA — first deterministic MetaRuntime tests.
"""
from __future__ import annotations

import asyncio
from dataclasses import dataclass

import pytest

from aidm.config import Settings, load_config
from aidm.internal_messages import ErrorCode, ResultStatus, make_request
from aidm.meta.runtime import (
    DuplicateServiceError, LifecycleState, MetaRuntime, MissingServiceError,
    MockTool, RegistryClosedError, RegistryError, RuntimeShutdownError,
    RuntimeStartupError, ServiceRegistry,
)
from aidm.versioning import BuildIdentity


@pytest.fixture
def settings(tmp_path):
    return load_config(environ={"AIDM_MODE": "test"}, dotenv_path=tmp_path / ".env")


class FakeLogger:
    def __init__(self):
        self.entries = []
        self.started = 0
        self.closed = 0
        self.fail = False

    def start(self, settings):
        self.started += 1
        if self.fail:
            raise ValueError("SECRET_TOKEN_VALUE")

    def close(self):
        self.closed += 1

    def info(self, msg):
        self.entries.append(("info", msg))

    def error(self, msg):
        self.entries.append(("error", msg))


class FakeResource:
    def __init__(self, name, events, fail_start=False, fail_stop=False):
        self.name = name
        self.events = events
        self.fail_start = fail_start
        self.fail_stop = fail_stop

    async def start(self):
        self.events.append("start:" + self.name)
        if self.fail_start:
            raise RuntimeError("SECRET_TOKEN_VALUE")

    async def stop(self):
        self.events.append("stop:" + self.name)
        if self.fail_stop:
            raise RuntimeError("SECRET_TOKEN_VALUE")


def identity():
    return BuildIdentity("0.1.0", "c"*40, "development", "dev-cccc", "UNKNOWN", False)


def assembled(settings, *, registry=None, logger=None):
    r = registry or ServiceRegistry(required=("mock_tool",))
    if registry is None:
        r.register("mock_tool", MockTool())
    return MetaRuntime(settings, r, logger=logger or FakeLogger(), identity_provider=identity)


def execute(task):
    return asyncio.run(task)


def test_bootstrap_has_no_started_logger_or_capabilities(settings):
    logger = FakeLogger()
    m = assembled(settings, logger=logger)
    assert m.health() == {"state": "BOOTSTRAPPING", "ready": False}
    assert m.status()["capabilities"] == []
    assert m.status()["build"]["source_sha"] == "UNKNOWN"
    assert logger.started == 0


def test_start_success_and_idempotent_stop(settings):
    logger = FakeLogger()
    m = assembled(settings, logger=logger)
    execute(m.start())
    execute(m.start())
    assert m.ready and m.state is LifecycleState.READY
    assert m.status()["build"]["source_sha"] == "c"*40
    assert m.status()["capabilities"] == ["mock_tool"]
    assert logger.started == 1
    assert logger.entries == [("info", "Meta Service READY")]
    execute(m.stop())
    execute(m.stop())
    assert m.state is LifecycleState.STOPPED and not m.ready
    assert logger.closed == 1
    assert m.status()["capabilities"] == []


def test_runtime_can_be_stopped_before_start(settings):
    m = assembled(settings)
    execute(m.stop())
    execute(m.stop())
    assert m.state is LifecycleState.STOPPED
    with pytest.raises(RuntimeStartupError):
        execute(m.start())


def test_required_missing_is_failed_no_ready_and_rejects_start(settings):
    registry = ServiceRegistry(required=("dm", "mock_tool"))
    registry.register("mock_tool", MockTool())
    logger = FakeLogger()
    m = assembled(settings, registry=registry, logger=logger)
    with pytest.raises(MissingServiceError, match="dm"):
        execute(m.start())
    assert m.state is LifecycleState.FAILED and not m.ready
    assert logger.started == 0
    assert m.status()["capabilities"] == []
    execute(m.stop())
    assert m.state is LifecycleState.FAILED


def test_duplicate_service_fails_predictably(settings):
    r = ServiceRegistry()
    service = object()
    r.register("dm", service)
    assert r.get("dm") is service
    with pytest.raises(DuplicateServiceError):
        r.register("dm", object())
    with pytest.raises(MissingServiceError):
        r.get("unregistered")


@pytest.mark.parametrize("name", ["", "../secret", "Space Name", "-x", "1invalid", "x"*65])
def test_registry_rejects_bad_names(name):
    r = ServiceRegistry()
    with pytest.raises(RegistryError):
        r.register(name, object())
    with pytest.raises(RegistryError):
        r.get(name)
    with pytest.raises(RegistryError):
        ServiceRegistry(required=(name,))


def test_registry_rejects_none_service():
    r = ServiceRegistry()
    with pytest.raises(RegistryError):
        r.register("dm", None)


def test_registry_frozen_after_ready(settings):
    m = assembled(settings)
    execute(m.start())
    with pytest.raises(RegistryClosedError):
        m.registry.register("new_tool", object())
    execute(m.stop())


def test_resources_started_in_order_and_stopped_in_reverse(settings):
    events = []
    r = ServiceRegistry(required=("dm", "dispatcher"))
    r.register("dm", FakeResource("dm", events))
    r.register("dispatcher", FakeResource("dispatcher", events))
    m = assembled(settings, registry=r)
    execute(m.start())
    execute(m.stop())
    assert events == ["start:dm", "start:dispatcher", "stop:dispatcher", "stop:dm"]


def test_failed_service_start_rolls_back_first_service(settings):
    events = []
    r = ServiceRegistry(required=("one", "two"))
    r.register("one", FakeResource("one", events))
    r.register("two", FakeResource("two", events, fail_start=True))
    logger = FakeLogger()
    m = assembled(settings, registry=r, logger=logger)
    with pytest.raises(RuntimeStartupError) as exc:
        execute(m.start())
    assert "SECRET_TOKEN_VALUE" not in str(exc.value)
    assert m.state is LifecycleState.FAILED
    assert events == ["start:one", "start:two", "stop:two", "stop:one"]
    assert logger.closed == 1


def test_failed_logger_start_is_safely_reported(settings):
    logger = FakeLogger()
    logger.fail = True
    m = assembled(settings, logger=logger)
    with pytest.raises(RuntimeStartupError) as exc:
        execute(m.start())
    assert "SECRET_TOKEN_VALUE" not in str(exc.value)
    assert not m.ready
    assert m.state is LifecycleState.FAILED
    assert logger.closed == 1


def test_failed_stop_still_closes_everything(settings):
    events = []
    r = ServiceRegistry(required=("one", "two"))
    r.register("one", FakeResource("one", events, fail_stop=True))
    r.register("two", FakeResource("two", events))
    logger = FakeLogger()
    m = assembled(settings, registry=r, logger=logger)
    execute(m.start())
    with pytest.raises(RuntimeShutdownError) as exc:
        execute(m.stop())
    assert "SECRET_TOKEN_VALUE" not in str(exc.value)
    assert m.state is LifecycleState.FAILED
    assert logger.closed == 1
    assert events[-2:] == ["stop:two", "stop:one"]
    execute(m.stop())


def test_sync_optional_resource_start_stop(settings):
    events = []
    class Sync:
        def start(self): events.append("start")
        def stop(self): events.append("stop")
    r = ServiceRegistry(required=("mock_tool",))
    r.register("mock_tool", Sync())
    m = assembled(settings, registry=r)
    execute(m.start())
    execute(m.stop())
    assert events == ["start", "stop"]


def test_default_mock_tool_reports_non_auth_game_effects(settings):
    m = assembled(settings)
    demo = m.registry.get("mock_tool")
    request = make_request(caller="DM", capability="mock_tool", operation="mock_ping", payload={})
    result = demo(request)
    assert result.status is ResultStatus.COMPLETED
    assert result.committed_effects is None
    assert result.data == {"mock": True}
    assert "No game state was changed" in result.safe_summary
    for operation, mutation in (("attack", False), ("mock_ping", True)):
        bad = make_request(caller="DM", capability="mock_tool", operation=operation,
                           payload={}, is_mutation=mutation,
                           **({"command_id":"command-1","expected_world_version":0} if mutation else {}))
        blocked = demo(bad)
        assert blocked.status is ResultStatus.BLOCKED
        assert blocked.error.code is ErrorCode.UNKNOWN_CAPABILITY
        assert blocked.committed_effects is None


def test_correlation_hook_reuses_shared_logging_context(settings):
    m = assembled(settings)
    with m.correlation("turn-7"):
        with m.correlation("nested-turn"):
            assert m.correlation is not None
    assert m.state is LifecycleState.BOOTSTRAPPING


def test_invalid_settings_type_rejected_safely():
    with pytest.raises(RuntimeStartupError):
        MetaRuntime(object(), ServiceRegistry())
    with pytest.raises(RuntimeStartupError):
        MetaRuntime(None, ServiceRegistry())
    with pytest.raises(RuntimeStartupError):
        MetaRuntime(load_config(environ={"AIDM_MODE":"test"}), object())


def test_bad_identity_provider_fails_no_ready(settings):
    m = MetaRuntime(settings, assembled(settings).registry, logger=FakeLogger(),
                    identity_provider=lambda: "secretbadtype")
    with pytest.raises(RuntimeStartupError):
        execute(m.start())
    assert m.state is LifecycleState.FAILED


def test_no_llm_dependency_or_calls_while_running(settings):
    r = ServiceRegistry(required=("fake_llm",))
    class NotInvoked:
        def __init__(self): self.calls = 0
        def __call__(self, *_): self.calls += 1
    fake = NotInvoked()
    r.register("fake_llm", fake)
    m = assembled(settings, registry=r)
    execute(m.start())
    assert fake.calls == 0
    execute(m.stop())
    assert fake.calls == 0


def test_lifecycle_initializing_and_stopping_are_observable(settings):
    events = []
    registry = ServiceRegistry(required=("probe",))
    class Observed:
        async def start(self):
            events.append(m.state)
        async def stop(self):
            events.append(m.state)
    registry.register("probe", Observed())
    m = assembled(settings, registry=registry)
    execute(m.start())
    execute(m.stop())
    assert events == [LifecycleState.INITIALIZING, LifecycleState.STOPPING]


def test_cancelled_start_releases_partial_resource_and_reports_failed(settings):
    events = []
    registry = ServiceRegistry(required=("cancelled",))
    class Cancelled:
        async def start(self):
            events.append("start")
            raise asyncio.CancelledError()
        async def stop(self):
            events.append("stop")
    registry.register("cancelled", Cancelled())
    logger = FakeLogger()
    m = assembled(settings, registry=registry, logger=logger)
    with pytest.raises(asyncio.CancelledError):
        execute(m.start())
    assert events == ["start", "stop"]
    assert m.state is LifecycleState.FAILED
    assert logger.closed == 1