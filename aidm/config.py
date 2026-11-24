"""Small, offline, secret-safe AIDM configuration boundary.

Purpose: Resolve optional developer .env values beneath process environment;
         validate typed non-secret settings and explicitly required secrets.
Usage: settings = load_config(required_secrets=("SELECTED_PROVIDER_KEY",))
Change log: 2026-11-17 COSTA — AIDM-DES-034.1 initial implementation.

No configuration is read on import, and no network calls are made. The loader
accepts only simple dotenv KEY=VALUE lines: plain values, or single/double
quoted values without interpolation or escape processing. In plain values,
whitespace followed by # starts an inline comment. This restricted syntax is
intentional; unsupported syntax fails closed instead of guessing.
"""

from __future__ import annotations

import math
import os
from pathlib import Path
import re
from typing import Iterable, Mapping, Literal

Mode = Literal["development", "test", "ci", "production"]
LogLevel = Literal["INFO", "DEBUG", "TRACE"]

_VALID_KEY = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")
_MODES = frozenset(("development", "test", "ci", "production"))
_LEVELS = frozenset(("INFO", "DEBUG", "TRACE"))
_BOOLEAN_TRUE = frozenset(("true", "1", "yes", "on"))
_BOOLEAN_FALSE = frozenset(("false", "0", "no", "off"))


class ConfigError(ValueError):
    """Configuration validation error that reports a key, never its value."""

    __slots__ = ("key",)

    def __init__(self, key: str):
        self.key = key
        super().__init__(f"Missing or invalid configuration key: {key}")


class Settings:
    """Validated settings with explicit access to requested secrets only.

    Public repr/str, safe_dict, and JSON error output never expose secret
    bytes. Pickle is disabled to prevent accidental persistence of secrets.
    A caller needing a selected integration's secret must explicitly request
    its key via required_secrets/optional_secrets at load time, then use
    get_secret(name) only in its protected provider adapter.
    """

    __slots__ = ("mode", "debug", "log_level", "request_timeout_seconds",
                 "live_llm", "llm_model", "_secrets")

    def __init__(
        self,
        *,
        mode: Mode,
        debug: bool,
        log_level: LogLevel,
        request_timeout_seconds: float,
        secrets: Mapping[str, str],
        live_llm: bool = False,
        llm_model: str | None = None,
    ) -> None:
        self.mode = mode
        self.debug = debug
        self.log_level = log_level
        self.request_timeout_seconds = request_timeout_seconds
        self.live_llm = live_llm
        self.llm_model = llm_model
        self._secrets = dict(secrets)

    def get_secret(self, key: str) -> str | None:
        """Return only a secret that the caller explicitly registered."""
        if not _VALID_KEY.fullmatch(key):
            raise ConfigError("SECRET_KEY_NAME") from None
        return self._secrets.get(key)

    def to_safe_dict(self) -> dict[str, str | bool | float]:
        """Return non-secret fields suitable for logging/JSON diagnostics."""
        return {
            "mode": self.mode,
            "debug": self.debug,
            "log_level": self.log_level,
            "request_timeout_seconds": self.request_timeout_seconds,
        }

    def __repr__(self) -> str:
        return (
            "Settings("
            f"mode={self.mode!r}, debug={self.debug!r}, "
            f"log_level={self.log_level!r}, "
            f"request_timeout_seconds={self.request_timeout_seconds!r}, "
            "secrets=<redacted>)"
        )

    __str__ = __repr__

    def __reduce_ex__(self, protocol: int) -> object:
        raise TypeError("Settings objects must not be serialized; use to_safe_dict()")


def _bool(value: str, key: str) -> bool:
    normal = value.strip().lower()
    if normal in _BOOLEAN_TRUE:
        return True
    if normal in _BOOLEAN_FALSE:
        return False
    raise ConfigError(key) from None


def _dotenv_values(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    try:
        raw = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError):
        raise ConfigError("AIDM_DOTENV_FILE") from None

    result: dict[str, str] = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ConfigError("AIDM_DOTENV_FILE") from None
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if not _VALID_KEY.fullmatch(key) or key in result:
            raise ConfigError("AIDM_DOTENV_FILE") from None
        if value.startswith(("'", '"')):
            quote = value[0]
            end = value.find(quote, 1)
            if end < 0 or (value[end + 1 :].strip() and not value[end + 1 :].strip().startswith("#")):
                raise ConfigError(key) from None
            value = value[1:end]
        else:
            value = re.split(r"\s+#", value, maxsplit=1)[0].rstrip()
        result[key] = value
    return result


def _valid_names(names: Iterable[str]) -> set[str]:
    result = set()
    for name in names:
        if not isinstance(name, str) or not _VALID_KEY.fullmatch(name):
            raise ConfigError("SECRET_KEY_NAME") from None
        result.add(name)
    return result


def load_config(
    *,
    environ: Mapping[str, str] | None = None,
    dotenv_path: str | os.PathLike[str] = ".env",
    required_secrets: Iterable[str] = (),
    optional_secrets: Iterable[str] = (),
) -> Settings:
    """Load and validate settings without network I/O.

    Process environment overrides .env. Development loads optional .env;
    test, CI and production modes never read it. AIDM_MODE must be selected
    through the process environment (or inferred from CI=true). Defaults are
    for non-sensitive settings only. Future provider key names are passed in
    by the integration that actually needs them, not hard-coded here.

    Tests should pass an explicit fake ``environ`` mapping and temp path to
    avoid depending on the developer workstation or calling external APIs.
    """
    source = dict(os.environ if environ is None else environ)
    ci = _bool(source.get("CI", "false"), "CI")
    mode_raw = source.get("AIDM_MODE", "ci" if ci else "development")
    mode = mode_raw.strip().lower()
    if mode not in _MODES:
        raise ConfigError("AIDM_MODE") from None
    # CI=true must never permit a developer .env, even if mode is overridden.
    if ci and mode == "development":
        raise ConfigError("AIDM_MODE") from None

    local = _dotenv_values(Path(dotenv_path)) if mode == "development" else {}
    # AIDM_MODE is deliberately process-owned: a local file cannot change
    # whether it was allowed to be read or opt a CI job into development.
    local.pop("AIDM_MODE", None)
    effective = {**local, **source}

    debug = _bool(effective.get("AIDM_DEBUG", "false"), "AIDM_DEBUG")
    level = effective.get("AIDM_LOG_LEVEL", "INFO").strip().upper()
    if level not in _LEVELS:
        raise ConfigError("AIDM_LOG_LEVEL") from None
    try:
        timeout = float(effective.get("AIDM_REQUEST_TIMEOUT_SECONDS", "30"))
    except (TypeError, ValueError):
        raise ConfigError("AIDM_REQUEST_TIMEOUT_SECONDS") from None
    if not math.isfinite(timeout) or timeout <= 0:
        raise ConfigError("AIDM_REQUEST_TIMEOUT_SECONDS") from None

    # Live LLM configuration is non-secret but must use the same merged
    # development .env / process-environment semantics as all other settings.
    # Defaults stay OFFLINE, and .env is ignored entirely outside development.
    live_llm = _bool(effective.get("AIDM_LIVE_LLM", "false"), "AIDM_LIVE_LLM")
    llm_model = effective.get("AIDM_LLM_MODEL", "").strip() or None

    requested = _valid_names(optional_secrets)
    required = _valid_names(required_secrets)
    secrets = {}
    for name in sorted(requested | required):
        value = effective.get(name)
        if name in required and (value is None or not value.strip()):
            raise ConfigError(name) from None
        if value is not None and value.strip():
            secrets[name] = value

    return Settings(
        mode=mode,  # type: ignore[arg-type]  # checked against _MODES
        debug=debug,
        log_level=level,  # type: ignore[arg-type]  # checked against _LEVELS
        request_timeout_seconds=timeout,
        secrets=secrets,
        live_llm=live_llm,
        llm_model=llm_model,
    )