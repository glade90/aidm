"""Offline tests for shared technical logging, rotation, timing and fake SQL.

Purpose: Verify AIDM-DES-035.1 first increment without real I/O services.
Usage: python -m aidm.test_runner
Change Log: 2026-11-17 COSTA — first logger/SQL technical tests.
"""

from __future__ import annotations

import logging
from pathlib import Path
import re
import time

import pytest

from aidm.logging import (
    TRACE, close_logging, configure_logging, execute_logged, log, set_identity_provider,
)


@pytest.fixture
def technical_file(tmp_path: Path):
    path = tmp_path / "technical.log"
    configure_logging(path=path, max_bytes=4096, backup_count=3, level="INFO")
    set_identity_provider(None)
    yield path
    set_identity_provider(None)
    close_logging()


class Cleric:
    def cast(self):
        log.info("blessing applied")
        log.warning("blessing expiring")


class Fighter:
    def attack(self):
        log.error("attack unsuccessful")
        log.debug("debug detail")
        log.trace("trace detail")


def scout():
    log.info("passage inspected")


def test_shared_facade_and_origin_and_emoji(technical_file):
    Cleric().cast()
    Fighter().attack()
    scout()
    lines = technical_file.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 4
    assert all(re.match(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\s", line) for line in lines)
    assert "ℹ️ Cleric.cast | blessing applied" in lines[0]
    assert "⚠️ Cleric.cast | blessing expiring" in lines[1]
    assert "❌ Fighter.attack | attack unsuccessful" in lines[2]
    assert "ℹ️ test_logging.scout | passage inspected" in lines[3]
    assert not any("DEBUG" in x or "INFO" in x or "ERROR" in x for x in lines)


def test_trace_levels_unicode_and_single_handler(technical_file):
    configure_logging(path=technical_file, level="DEBUG")
    Fighter().attack()
    assert "🐛 Fighter.attack | debug detail" in technical_file.read_text(encoding="utf-8")
    assert "trace detail" not in technical_file.read_text(encoding="utf-8")
    configure_logging(path=technical_file, level="TRACE")
    Fighter().attack()
    assert "🔬 Fighter.attack | trace detail" in technical_file.read_text(encoding="utf-8")
    log.info("π 🐉")
    assert "π 🐉" in technical_file.read_text(encoding="utf-8")
    assert len(logging.getLogger("aidm.technical").handlers) == 1


def test_rotation_and_path(technical_file):
    configure_logging(path=technical_file, max_bytes=280, backup_count=2)
    for i in range(30):
        log.info(f"event_{i:03d} " + "x" * 65)
    assert technical_file.exists()
    assert (technical_file.parent / "technical.log.1").exists()
    assert not (technical_file.parent / "technical.log.3").exists()
    assert technical_file.stat().st_size <= 280


def test_decorated_methods_trace_and_slow_info(technical_file):
    @log.trace_calls(slow_ms=0)
    def calculated():
        return 42

    assert calculated() == 42
    text = technical_file.read_text(encoding="utf-8")
    assert "⚠️" in text and "slow_call" in text
    assert "enter" not in text
    configure_logging(path=technical_file, level="TRACE", slow_ms=1000)
    @log.trace_calls
    def foo():
        return 3
    assert foo() == 3
    text = technical_file.read_text(encoding="utf-8")
    assert "🔬" in text and "enter depth=" in text and "exit outcome=ok elapsed_ms=" in text


def test_exception_path_does_not_emit_secret_args_or_message(technical_file):
    secret = "SENSITIVE-DO-NOT-LOG-123"
    @log.trace_calls
    def fails(value):
        raise ValueError("credential=" + value)
    with pytest.raises(ValueError):
        fails(secret)
    data = technical_file.read_text(encoding="utf-8")
    assert "exception=ValueError" in data
    assert secret not in data
    assert "credential=" not in data


def test_class_opt_in_and_correlation_metadata(technical_file):
    records = []
    class Capture(logging.Handler):
        def emit(self, record):
            records.append(record)
    handler = Capture()
    logging.getLogger("aidm.technical").addHandler(handler)
    try:
        set_identity_provider(lambda: {"version": "v-test", "source_sha": "a" * 40,
                                       "build_id": "id-test", "release_kind": "development"})
        @log.trace_class
        class Trap:
            def trigger(self):
                log.info("trap entered")
        with log.correlation("turn-42"):
            Trap().trigger()
        record = records[-1]
        assert record.caller == "Trap.trigger"
        assert record.correlation_id == "turn-42"
        assert record.version == "v-test" and record.source_sha == "a" * 40
        assert record.build_id == "id-test" and record.release_kind == "development"
        log.info("after")
        assert records[-1].correlation_id is None
    finally:
        logging.getLogger("aidm.technical").removeHandler(handler)


def test_missing_build_info_reports_unknown(technical_file):
    records = []
    class Capture(logging.Handler):
        def emit(self, record):
            records.append(record)
    handler = Capture()
    logger = logging.getLogger("aidm.technical")
    logger.addHandler(handler)
    try:
        log.info("identity unavailable")
        assert records[-1].source_sha == "UNKNOWN"
        assert records[-1].version == "UNKNOWN"
        assert records[-1].build_id == "UNKNOWN"
    finally:
        logger.removeHandler(handler)


class FakeDriver:
    def __init__(self, should_fail=False):
        self.calls = []
        self.should_fail = should_fail

    def execute(self, sql, params=None):
        self.calls.append((sql, params))
        if self.should_fail:
            raise RuntimeError("private error detail SECRET-FROM-DB")
        return "OK"


@pytest.mark.parametrize("sql,category", [
    ("CREATE TABLE items (id INTEGER)", "DDL"),
    ("INSERT INTO items VALUES (?)", "DML"),
    ("SELECT * FROM items WHERE token=?", "READ"),
])
def test_fake_sql_executed_then_logged(technical_file, sql, category):
    fake = FakeDriver()
    secret = "SECRET-SQL-BIND-X99"
    assert execute_logged(fake, sql, (secret,)) == "OK"
    assert fake.calls == [(sql, (secret,))]
    data = technical_file.read_text(encoding="utf-8")
    assert f"sql category={category} outcome=ok" in data
    assert f"template={sql}" in data
    assert "bind_types=str" in data
    assert secret not in data


def test_fake_sql_failure_and_inline_string_mask(technical_file):
    fake = FakeDriver(True)
    sql = "SELECT * FROM items WHERE secret='PRIVATE-LITERAL' AND uid=?"
    with pytest.raises(RuntimeError):
        execute_logged(fake, sql, {"uid": "SECRET-MAP-BIND"})
    data = technical_file.read_text(encoding="utf-8")
    assert "sql category=READ outcome=error" in data
    assert "exception=RuntimeError" in data
    assert "PRIVATE-LITERAL" not in data
    assert "SECRET-MAP-BIND" not in data
    assert "SECRET-FROM-DB" not in data
    assert "[REDACTED]" in data