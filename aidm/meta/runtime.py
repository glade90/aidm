"""Framework-neutral Meta Service lifecycle and explicit service registry.

Purpose: Construct, initialise and stop injected in-process AIDM services safely.
Usage: runtime = MetaRuntime(settings, registry); await runtime.start(); await runtime.stop()
Change Log: 2026-11-20 COSTA — AIDM-DES-013.1 first runtime increment.

No HTTP imports, CrewAI, background model loop or world-state authority live here.
Only a trusted adapter may authorise calls and filter player-visible information.
"""

from __future__ import annotations

from contextlib import contextmanager
from enum import Enum
import inspect
import re
from typing import Callable, Iterable, Iterator, Protocol

from aidm.config import Settings
from aidm.internal_messages import (
    ErrorCode, InternalRequest, InternalResult, ResultStatus, make_result, safe_failure,
)
from aidm.logging import close_logging, configure_logging, log
from aidm.versioning import BuildIdentity, UNKNOWN, get_build_identity

_SERVICE_NAME = re.compile(r"[a-z][a-z0-9_]{0,63}\Z")


class RegistryError(ValueError):
    """Base class for safe service registry failures."""


class DuplicateServiceError(RegistryError):
    """A service was already registered under the same name."""


class MissingServiceError(RegistryError):
    """A mandatory or requested service has not been registered."""


class RegistryClosedError(RegistryError):
    """The runtime already started and registrations are frozen."""


class RuntimeStartupError(RuntimeError):
    """A runtime resource failed during startup; details are intentionally withheld."""


class RuntimeShutdownError(RuntimeError):
    """One or more owned runtime resources failed to close safely."""


class LifecycleState(str, Enum):
    BOOTSTRAPPING = "BOOTSTRAPPING"
    INITIALIZING = "INITIALIZING"
    READY = "READY"
    STOPPING = "STOPPING"
    STOPPED = "STOPPED"
    FAILED = "FAILED"


def _name(value: str) -> str:
    if not isinstance(value, str) or not _SERVICE_NAME.fullmatch(value):
        raise RegistryError("Invalid service name") from None
    return value


class ServiceRegistry:
    """Explicit injected services, not a dispatcher or a capability-permission system.

    `required` names are checked at lifecycle startup, not silently created.
    Service objects may optionally implement start()/stop(); async is supported.
    """

    def __init__(self, *, required: Iterable[str] = ()) -> None:
        self._services: dict[str, object] = {}
        self._required = frozenset(_name(name) for name in required)
        self._frozen = False

    def register(self, name: str, service: object) -> None:
        name = _name(name)
        if self._frozen:
            raise RegistryClosedError("Service registry is already started")
        if name in self._services:
            raise DuplicateServiceError(f"Duplicate service registration: {name}")
        if service is None:
            raise RegistryError("Service must not be None")
        self._services[name] = service

    def get(self, name: str) -> object:
        name = _name(name)
        try:
            return self._services[name]
        except KeyError:
            raise MissingServiceError(f"Service unavailable: {name}") from None

    def validate(self) -> None:
        absent = sorted(self._required - self._services.keys())
        if absent:
            raise MissingServiceError("Required service unavailable: " + ", ".join(absent))

    def names(self) -> tuple[str, ...]:
        """Only explicitly registered, local capabilities; no implementation details."""
        return tuple(sorted(self._services))

    def items(self) -> tuple[tuple[str, object], ...]:
        """Lifecycle ownership uses registration order, shutdown uses reverse order."""
        return tuple(self._services.items())

    def freeze(self) -> None:
        self._frozen = True


class RuntimeLogger(Protocol):
    """Injected logger lifecycle; existing AIDM logger is the production adapter."""

    def start(self, settings: Settings) -> None: ...
    def info(self, message: str) -> None: ...
    def error(self, message: str) -> None: ...
    def close(self) -> None: ...


class SharedTechnicalLogger:
    """Thin ownership adapter; reuses the existing log facade and rotating handlers."""

    def start(self, settings: Settings) -> None:
        configure_logging(level=settings.log_level)

    def info(self, message: str) -> None:
        log.info(message)

    def error(self, message: str) -> None:
        log.error(message)

    def close(self) -> None:
        close_logging()


class MockTool:
    """Harmless bootstrap fixture: proves injection, never claims game effects."""

    def __call__(self, request: InternalRequest) -> InternalResult:
        if request.operation != "mock_ping" or request.is_mutation:
            return safe_failure(request, ErrorCode.UNKNOWN_CAPABILITY, status=ResultStatus.BLOCKED)
        return make_result(
            request, ResultStatus.COMPLETED,
            safe_summary="Mock tool response only. No game state was changed.",
            data={"mock": True},
        )


async def _invoke_if_present(service: object, method: str) -> None:
    fn = getattr(service, method, None)
    if fn is not None:
        result = fn()
        if inspect.isawaitable(result):
            await result


class MetaRuntime:
    """Application lifetime manager; no FastAPI dependency or provider credentials."""

    def __init__(
        self, settings: Settings, registry: ServiceRegistry, *,
        logger: RuntimeLogger | None = None,
        identity_provider: Callable[[], BuildIdentity] = get_build_identity,
    ) -> None:
        if not isinstance(settings, Settings):
            raise RuntimeStartupError("Validated Settings are required")
        if not isinstance(registry, ServiceRegistry):
            raise RuntimeStartupError("ServiceRegistry is required")
        self.settings = settings
        self.registry = registry
        self.logger: RuntimeLogger = logger if logger is not None else SharedTechnicalLogger()
        self._identity_provider = identity_provider
        self.state = LifecycleState.BOOTSTRAPPING
        self._started: list[object] = []
        self._logger_started = False
        self._build: BuildIdentity | None = None

    @property
    def ready(self) -> bool:
        return self.state is LifecycleState.READY

    @contextmanager
    def correlation(self, correlation_id: str) -> Iterator[None]:
        """Use DES-035.1's existing context-local log correlation facility."""
        with log.correlation(correlation_id):
            yield

    def health(self) -> dict[str, str | bool]:
        return {"state": self.state.value, "ready": self.ready}

    def status(self) -> dict[str, object]:
        return {
            "state": self.state.value,
            "ready": self.ready,
            "capabilities": list(self.registry.names()) if self.ready else [],
            "build": self._build.as_dict() if self._build is not None else {
                "version": UNKNOWN, "source_sha": UNKNOWN, "build_type": UNKNOWN,
                "build_id": UNKNOWN, "build_timestamp": UNKNOWN, "dirty": None,
            },
        }

    async def start(self) -> None:
        if self.state is LifecycleState.READY:
            return
        if self.state is not LifecycleState.BOOTSTRAPPING:
            raise RuntimeStartupError("Meta Service cannot be restarted in current state")
        self.state = LifecycleState.INITIALIZING
        try:
            self.registry.validate()
            self._build = self._identity_provider()
            if not isinstance(self._build, BuildIdentity):
                raise TypeError("Invalid build identity")
            self.logger.start(self.settings)
            self._logger_started = True
            for _, service in self.registry.items():
                self._started.append(service)  # May own resources even if start() fails partway.
                await _invoke_if_present(service, "start")
            self.registry.freeze()
            self.state = LifecycleState.READY
            self.logger.info("Meta Service READY")
        except BaseException as exc:
            self.state = LifecycleState.FAILED
            if self._logger_started:
                try:
                    self.logger.error(f"Meta startup failed exception={type(exc).__name__}")
                except Exception:
                    pass  # A broken logger must not prevent cleanup.
            await self._release()  # Preserve original failure, including cancellations.
            if not isinstance(exc, Exception):
                raise
            if isinstance(exc, RegistryError):
                raise
            raise RuntimeStartupError("Meta Service startup failed") from None

    async def _release(self) -> bool:
        error = False
        for service in reversed(self._started):
            try:
                await _invoke_if_present(service, "stop")
            except Exception:
                error = True
        self._started.clear()
        if self._logger_started:
            try:
                self.logger.close()
            except Exception:
                error = True
            finally:
                self._logger_started = False
        return error

    async def stop(self) -> None:
        if self.state in (LifecycleState.STOPPED, LifecycleState.STOPPING):
            return
        if self.state is LifecycleState.BOOTSTRAPPING:
            self.state = LifecycleState.STOPPED
            return
        was_failed = self.state is LifecycleState.FAILED
        if not was_failed:
            self.state = LifecycleState.STOPPING
        cleanup_failed = await self._release()
        self.state = LifecycleState.FAILED if was_failed or cleanup_failed else LifecycleState.STOPPED
        if cleanup_failed:
            raise RuntimeShutdownError("Meta Service shutdown failed")