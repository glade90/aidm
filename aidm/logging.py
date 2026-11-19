"""AIDM's shared, rotating technical logger (first implementation increment).

Purpose: One emoji/caller-aware logger, timed tracing and safe SQL execution hook.
Usage: from aidm.logging import log, configure_logging, execute_logged
Change Log: 2026-11-17 COSTA — AIDM-DES-035.1 technical logging foundation.
            2026-11-18 COSTA — AIDM-DES-030.1 structured identity records.

Only one process may rotate a given file: multiprocess listeners/adapters are deferred.
Never pass secrets, player-only/DM-only text, or raw exception messages to log.*.
"""

from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime, timezone
import functools
import inspect
import json
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import re
from threading import RLock
from time import perf_counter
from typing import Any, Callable, Iterator, Mapping, ParamSpec, TypeVar

TRACE = 5
logging.addLevelName(TRACE, "TRACE")
_LEVELS = {"TRACE": TRACE, "DEBUG": logging.DEBUG, "INFO": logging.INFO,
           "WARNING": logging.WARNING, "ERROR": logging.ERROR,
           "CRITICAL": logging.CRITICAL}
_EMOJI = {TRACE: "🔬", logging.DEBUG: "🐛", logging.INFO: "ℹ️",
          logging.WARNING: "⚠️", logging.ERROR: "❌", logging.CRITICAL: "💥"}
_LOCK = RLock()
_LOGGER = logging.getLogger("aidm.technical")
_LOGGER.propagate = False
_CONFIGURED = False
_SLOW_MS = 1000.0
_CORRELATION: ContextVar[str | None] = ContextVar("aidm_log_correlation", default=None)
_DEPTH: ContextVar[int] = ContextVar("aidm_log_depth", default=0)
_IDENTITY_PROVIDER: Callable[[], Mapping[str, str]] | None = None
_P = ParamSpec("_P")
_T = TypeVar("_T")


class _EmojiFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        timestamp = datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
        emoji = _EMOJI.get(record.levelno, "❓")
        caller = getattr(record, "caller", "UNKNOWN")
        message = record.getMessage().replace("\r", "\\r").replace("\n", "\\n")
        cid = getattr(record, "correlation_id", None)
        suffix = f" [cid={cid}]" if cid else ""
        return f"{timestamp} {emoji} {caller} | {message}{suffix}"


class _JsonFormatter(logging.Formatter):
    """Optional structured JSONL diagnostics with exact immutable build identity."""
    def format(self, record: logging.LogRecord) -> str:
        fields = {
            "timestamp": datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="milliseconds"),
            "severity": record.levelno,
            "emoji": _EMOJI.get(record.levelno, "❓"),
            "caller": getattr(record, "caller", "UNKNOWN"),
            "message": record.getMessage(),
            "correlation_id": getattr(record, "correlation_id", None),
            "exception_type": getattr(record, "exception_type", None),
            "version": getattr(record, "version", "UNKNOWN"),
            "source_sha": getattr(record, "source_sha", "UNKNOWN"),
            "build_id": getattr(record, "build_id", "UNKNOWN"),
            "build_type": getattr(record, "release_kind", "UNKNOWN"),
            "build_timestamp": getattr(record, "build_timestamp", "UNKNOWN"),
            "dirty": getattr(record, "dirty", "UNKNOWN"),
        }
        return json.dumps(fields, ensure_ascii=False, separators=(",", ":"))


def configure_logging(
    *, path: str | Path = "logs/technical.log", level: str = "INFO",
    max_bytes: int = 10 * 1024 * 1024, backup_count: int = 5,
    console: bool = False, slow_ms: float = 1000.0,
    json_path: str | Path | None = None,
) -> None:
    """Configure one shared file logger, replacing rather than duplicating handlers."""
    global _CONFIGURED, _SLOW_MS
    name = level.upper()
    if name not in _LEVELS:
        raise ValueError("Invalid logging level")
    if max_bytes <= 0 or backup_count < 0 or slow_ms < 0:
        raise ValueError("Invalid logging rotation or slow-call settings")
    destination = Path(path)
    with _LOCK:
        destination.parent.mkdir(parents=True, exist_ok=True)
        handler = RotatingFileHandler(destination, maxBytes=max_bytes, backupCount=backup_count,
                                      encoding="utf-8")
        handler.setFormatter(_EmojiFormatter())
        handlers: list[logging.Handler] = [handler]
        if json_path is not None:
            structured = Path(json_path)
            structured.parent.mkdir(parents=True, exist_ok=True)
            json_handler = RotatingFileHandler(
                structured, maxBytes=max_bytes, backupCount=backup_count,
                encoding="utf-8",
            )
            json_handler.setFormatter(_JsonFormatter())
            handlers.append(json_handler)
        if console:
            stream = logging.StreamHandler()
            stream.setFormatter(_EmojiFormatter())
            handlers.append(stream)
        old = list(_LOGGER.handlers)
        for entry in old:
            _LOGGER.removeHandler(entry)
            entry.close()
        for entry in handlers:
            _LOGGER.addHandler(entry)
        _LOGGER.setLevel(_LEVELS[name])
        _LOGGER.propagate = False
        _SLOW_MS = float(slow_ms)
        if _IDENTITY_PROVIDER is None:
            # Resolve the same identity once at startup; DES-030.2 controls releases.
            from .versioning import get_build_identity
            set_identity_provider(get_build_identity().for_logging)
        _CONFIGURED = True


def close_logging() -> None:
    """Flush and close all owned handlers (shutdown and test clean-up)."""
    global _CONFIGURED
    with _LOCK:
        for handler in list(_LOGGER.handlers):
            handler.flush()
            _LOGGER.removeHandler(handler)
            handler.close()
        _CONFIGURED = False


def set_identity_provider(provider: Callable[[], Mapping[str, str]] | None) -> None:
    """Receive build identity from DES-030.1 when available; never invent a SHA."""
    global _IDENTITY_PROVIDER
    _IDENTITY_PROVIDER = provider


def _identity() -> dict[str, str]:
    names = ("version", "source_sha", "build_id", "release_kind", "build_timestamp", "dirty")
    try:
        supplied = dict(_IDENTITY_PROVIDER()) if _IDENTITY_PROVIDER else {}
    except Exception:
        supplied = {}
    return {key: str(supplied.get(key) or "UNKNOWN") for key in names}


def _caller_name() -> str:
    # _caller_name <- _emit <- info/warning/error/debug/trace <- real caller
    frame = inspect.currentframe()
    try:
        for _ in range(3):
            frame = frame.f_back if frame else None
        if frame is None:
            return "UNKNOWN"
        local = frame.f_locals
        if "self" in local:
            return f"{type(local['self']).__name__}.{frame.f_code.co_name}"
        if isinstance(local.get("cls"), type):
            return f"{local['cls'].__name__}.{frame.f_code.co_name}"
        return f"{frame.f_globals.get('__name__', 'UNKNOWN').rsplit('.', 1)[-1]}.{frame.f_code.co_name}"
    finally:
        del frame


class LoggerFacade:
    """One process-wide facade; callers never configure their own handlers."""

    def _emit(self, level: int, message: str, *, caller: str | None = None,
              exception_type: str | None = None) -> None:
        if not _CONFIGURED:
            with _LOCK:
                if not _CONFIGURED:
                    configure_logging()
        if not _LOGGER.isEnabledFor(level):
            return
        extra = {"caller": caller or _caller_name(), "correlation_id": _CORRELATION.get(),
                 "exception_type": exception_type, "span_depth": _DEPTH.get(), **_identity()}
        # Never attach raw exc_info: its str(exception) may contain secrets.
        _LOGGER.log(level, "%s", message, extra=extra)

    def info(self, message: str) -> None:
        self._emit(logging.INFO, message)

    def warning(self, message: str) -> None:
        self._emit(logging.WARNING, message)

    def error(self, message: str) -> None:
        self._emit(logging.ERROR, message)

    def critical(self, message: str) -> None:
        self._emit(logging.CRITICAL, message)

    def debug(self, message: str) -> None:
        self._emit(logging.DEBUG, message)

    def trace(self, message: str) -> None:
        self._emit(TRACE, message)

    @contextmanager
    def correlation(self, correlation_id: str) -> Iterator[None]:
        token = _CORRELATION.set(correlation_id)
        try:
            yield
        finally:
            _CORRELATION.reset(token)

    def trace_calls(
        self, function: Callable[_P, _T] | None = None, *, slow_ms: float | None = None,
    ) -> Callable[_P, _T] | Callable[[Callable[_P, _T]], Callable[_P, _T]]:
        """Opt-in duration/exception logging; argument and result values are not logged."""
        def decorate(fn: Callable[_P, _T]) -> Callable[_P, _T]:
            if getattr(fn, "__aidm_traced__", False):
                return fn
            parts = fn.__qualname__.split(".")
            caller = (f"{parts[-2]}.{parts[-1]}"
                      if len(parts) > 1 and parts[-2] != "<locals>"
                      else f"{fn.__module__.rsplit('.', 1)[-1]}.{fn.__name__}")

            @functools.wraps(fn)
            def wrapped(*args: _P.args, **kwargs: _P.kwargs) -> _T:
                token = _DEPTH.set(_DEPTH.get() + 1)
                start = perf_counter()
                outcome, error_type = "ok", None
                self._emit(TRACE, f"enter depth={_DEPTH.get()}", caller=caller)
                try:
                    return fn(*args, **kwargs)
                except BaseException as exc:
                    outcome, error_type = "error", type(exc).__name__
                    self._emit(logging.ERROR, f"failed exception={error_type}",
                               caller=caller, exception_type=error_type)
                    raise
                finally:
                    elapsed = (perf_counter() - start) * 1000
                    self._emit(TRACE, f"exit outcome={outcome} elapsed_ms={elapsed:.3f} depth={_DEPTH.get()}",
                               caller=caller, exception_type=error_type)
                    threshold = _SLOW_MS if slow_ms is None else slow_ms
                    if elapsed >= threshold:
                        self._emit(logging.WARNING, f"slow_call elapsed_ms={elapsed:.3f} threshold_ms={threshold:g} outcome={outcome}",
                                   caller=caller, exception_type=error_type)
                    _DEPTH.reset(token)
            setattr(wrapped, "__aidm_traced__", True)
            return wrapped
        return decorate(function) if function is not None else decorate

    def trace_class(self, cls: type) -> type:
        """Opt in all user-defined methods of one class, preserving descriptors."""
        for name, method in vars(cls).copy().items():
            if name.startswith("__"):
                continue
            if isinstance(method, staticmethod):
                setattr(cls, name, staticmethod(self.trace_calls(method.__func__)))
            elif isinstance(method, classmethod):
                setattr(cls, name, classmethod(self.trace_calls(method.__func__)))
            elif inspect.isfunction(method):
                setattr(cls, name, self.trace_calls(method))
        return cls


log = LoggerFacade()


def _sql_category(statement: str) -> str:
    token = statement.lstrip().split(maxsplit=1)[0].upper() if statement.strip() else ""
    if token in {"SELECT", "WITH", "EXPLAIN"}:
        return "READ"
    if token in {"CREATE", "ALTER", "DROP", "TRUNCATE"}:
        return "DDL"
    return "DML" if token in {"INSERT", "UPDATE", "DELETE", "MERGE", "REPLACE"} else "OTHER"


def _sql_template(statement: str) -> str:
    # Placeholders are preserved. Quoted inline string literals are masked.
    # This is not a complete SQL parser: applications MUST use bound parameters.
    flattened = " ".join(statement.split())
    return re.sub(r"'(?:''|[^'])*'", "'[REDACTED]'", flattened)


def execute_logged(executor: Any, statement: str, params: Any = None) -> Any:
    """Execute through a DB-API-like fake/adapter; log afterwards, never parameter values."""
    start = perf_counter()
    category, template = _sql_category(statement), _sql_template(statement)
    bind_types = (
        ",".join(type(item).__name__ for item in params.values()) if isinstance(params, Mapping)
        else ",".join(type(item).__name__ for item in params) if params is not None else "none"
    )
    outcome, error_type = "ok", None
    try:
        return executor.execute(statement) if params is None else executor.execute(statement, params)
    except BaseException as exc:
        outcome, error_type = "error", type(exc).__name__
        raise
    finally:
        elapsed = (perf_counter() - start) * 1000
        log._emit(logging.ERROR if outcome == "error" else logging.INFO,
                  f"sql category={category} outcome={outcome} elapsed_ms={elapsed:.3f} "
                  f"template={template} bind_types={bind_types}" +
                  (f" exception={error_type}" if error_type else ""),
                  caller="execute_logged", exception_type=error_type)