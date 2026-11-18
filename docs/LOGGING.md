# AIDM technical logging — AIDM-DES-035.1

**Purpose:** first technical logging slice, not full observability/replay.  
**Authority:** Golden Braid Engineering Standards §13; secrets §12; build identity §8.5.  
**Change Log:** 2026-11-17 COSTA — initial rotating logger, trace timing and fake SQL hook.

## Setup and usage

From the repository root, at process startup (planned DES-013 integration):

```python
from aidm.config import load_config
from aidm.logging import configure_logging, log, execute_logged, close_logging

settings = load_config()
configure_logging(level=settings.log_level)  # default INFO, path logs/technical.log

class Expedition:
    def explore(self):
        log.info("The party enters a corridor")

Expedition().explore()
close_logging()  # orderly shutdown
```

The same `log` instance is imported everywhere; it lazily configures its default rotating file if first used without explicit startup configuration. **Do not configure handlers per component.** The local file is `logs/technical.log`, rotated at 10 MiB with five backups by default. Console output is opt-in (`console=True`). The default INFO level suppresses DEBUG and TRACE; select DEBUG or TRACE explicitly. Paths, max_bytes, backup_count and slow_ms are configurable. Logs are excluded by `.gitignore`. An unreadable log destination fails visibly instead of silently discarding diagnostics. Every line uses UTC ISO8601 time, emoji severity and the origin `Class.method` or `module.function`.

```python
@log.trace_calls(slow_ms=500)
def validate_move():
    # No automatic logging of args, kwargs or return values.
    return True

@log.trace_class  # optional class-wide instrumentation, excluding dunder methods
class Cartographer:
    def reconcile(self):
        return True

with log.correlation("turn-42"):
    log.info("Step validated")
```

TRACE records `enter`, `exit`, elapsed milliseconds, nested depth and exceptions by **type only**; slow execution emits a warning even at INFO. The decorator handles synchronous Python functions only. Never pass secrets or untrusted text to log methods. `log.error(f"{exc}")` may leak: log exception **type only**. Multi-line messages are escaped onto one technical log line. `log.critical` is also available; no English severity names appear in the rendered severity field.

## Executed SQL hook — fake or future real adapter

```python
result = execute_logged(fake_cursor, "SELECT * FROM doors WHERE room_id=?", (51,))
```

`execute_logged()` calls the supplied DB-API-like `execute()` **before** logging a success/failure with DDL/DML/READ category, SQL template, elapsed milliseconds and bind **types**, never bind values. Failure records include the exception **type**, not raw error text. Single-quoted inline literals are masked as a precaution. **Always use parameter placeholders**, because this is not a SQL parser or general-purpose secret scrubber. Actual database integration (including transaction/rowcount capture) belongs to the later DB adapter Story; do not assume all database paths are instrumented yet.

## Structured metadata and future integrations

Each Python `LogRecord` carries `caller`, `correlation_id`, `exception_type`, `span_depth`, `version`, `source_sha`, `build_id`, `release_kind`. When build identity isn't available, fields report `UNKNOWN`. To integrate DES-030.1's sole authoritative identity source, register its already-established provider with `set_identity_provider(callable)`; do **not** invent a second version file or SHA. A provider failure also yields `UNKNOWN`.

## Test and scope boundaries

`python -m aidm.test_runner` runs colocated `aidm/test/test_logging.py` together with the existing suite, writing distinct Git-ignored reports under `reports/test-runs/` (DES-028.1). Tests cover two unrelated classes and a free function, INFO/DEBUG/TRACE filters, emoji and Unicode formatting, rotation, trace decorator/class, slow warning, exceptions and secret omission, fake DDL/DML/SELECT/error, correlation and build metadata.

**Deferred:** actual DB-driver integration and transaction logging, per-component overrides and routing, multi-process safe rotation (a separate per-process file or central listener is required), framework-wide instrumentation, full replay JSONL, LLM metrics, canonical events/turn journals, player-safe UI projections, automated CI gating and formal build identity. Recording `UNKNOWN` is intentional until DES-030.1 is implemented. These deferred areas remain governed by §13 and follow-up Story scope; this module is neither a game-event authority nor a secret-redaction guarantee for arbitrary input strings.