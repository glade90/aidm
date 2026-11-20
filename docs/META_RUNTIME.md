# AIDM-DES-013.1 — Minimal Meta Service runtime

**Owner:** COSTA · **Design:** AIDM-ARCH-RUNTIME-001 v0.1 (BON, approved 18 November 2026) · **Updated:** 20 November 2026.

## What it does

The Python `MetaRuntime` manages service registration, startup, readiness, safe diagnostics and cleanup. It does **not** run an LLM, route player turns, track world state, or interpret combat. `ServiceRegistry` stores named, explicitly injected service objects; it does **not** implement routing policy, permissions or CrewAI. At first boot, the default registry contains only a harmless `MockTool` named `mock_tool`; no combat is executed.

`create_app()` is the FastAPI equivalent of a Flask `create_app` factory. It creates a thin ASGI app with `GET /health` and `GET /status`. FastAPI uses a **lifespan** hook to call `await MetaRuntime.start()` when Uvicorn starts and `await MetaRuntime.stop()` on shutdown. The app **does not** start the server itself. Uvicorn owns the socket and event loop. `GET /docs` and `/openapi.json` exist in `development` mode, not `test`, `ci`, or `production`. There is no POST player-turn route in this Story.

Existing services are reused rather than duplicated: `aidm.config.load_config()` validates configuration (development `.env` optional, env overrides); `aidm.logging.configure_logging` / `log` / `close_logging` provide shared structured logging and correlation context; `aidm.versioning.get_build_identity()` provides version, source SHA, build ID and build classification. The runtime never claims a Git checkout is a published release. Invalid required settings or missing required registry entries fail startup before `READY`.

## Install, run, inspect, stop

From the repository root with Python 3.11+:

```bash
python -m pip install -r requirements-dev.txt
python -m uvicorn aidm.meta.http:create_app --factory --host 127.0.0.1 --port 8000
```

Open `http://127.0.0.1:8000/health`, `http://127.0.0.1:8000/status`, or `http://127.0.0.1:8000/docs` (development only). Stop the process using **Ctrl+C**; Uvicorn runs the FastAPI lifespan shutdown and closes resources. Do not use `--reload`, `--workers` or bind `0.0.0.0` for this first local-only prototype. Run tests using `python -m aidm.test_runner` for the full suite, or `python -m pytest aidm/meta/test -q` for local focused tests.

Expected safe health shape once started:

```json
{"state": "READY", "ready": true}
```

`/status` includes only state, readiness, names of **registered** services and `build` identity fields (`version`, `source_sha`, `build_type`, `build_id`, `build_timestamp`, `dirty`). It never includes secret configuration, player prompts, paths, provider API keys or hidden world facts. An unknown source is reported `UNKNOWN`, not invented. Before readiness both endpoints return HTTP 503, and the list of ready capabilities is empty. The real repository SHA and identity fields depend on the running build; no fabricated value is promised by the example.

## Service injection — contract for DAVOS (AIDM-DES-013.2)

```python
from aidm.meta.http import create_app
from aidm.meta.runtime import ServiceRegistry

registry = ServiceRegistry(required=("dm", "dispatcher", "mock_tool"))
registry.register("dm", fake_dm)
registry.register("dispatcher", fake_dispatcher)
registry.register("mock_tool", fake_tool)
app = create_app(registry=registry)

# At POST /api/turn (DAVOS's module, not yet installed by 013.1):
# runtime = app.state.meta_runtime
# handler = runtime.registry.get("dm")
# Use aidm.internal_messages.InternalRequest / InternalResult, not a second envelope.
```

`ServiceRegistry.register(name, service)` refuses duplicate names and `None` services. `get(name)` returns the *same injected object* or raises `MissingServiceError`. All required names are verified before startup; registration freezes when ready. Service objects can optionally define `start()` and `stop()` (sync or async); each is started once in registration order and stopped once in reverse order. `MetaRuntime.start()` and `.stop()` are async and idempotent in their respective completed states. A failed startup rolls back already-started resources, enters `FAILED`, and does **not** claim READY. A failed stop also enters FAILED. The existing `aidm.logging.log.correlation(id)` is exposed as `runtime.correlation(id)` for request-scoped logging; trusted HTTP code must validate untrusted identifiers itself.

`create_app(settings=validated_settings, registry=registry, logger=fake_logger)` allows deterministic tests. Production defaults use the real central logger; test fake loggers follow `start(settings)`, `info(message)`, `error(message)`, `close()` and must not persist secrets. The composition itself does not own the DM's conversation memory or a dispatch table.

**Example request to mock tool (internal Python only):**

```python
from aidm.internal_messages import make_request
request = make_request(caller="DM", capability="mock_tool", operation="mock_ping", payload={})
result = registry.get("mock_tool")(request)
assert result.safe_summary == "Mock tool response only. No game state was changed."
assert result.committed_effects is None
```

The temporary default `MockTool` is for demonstration, not a verified player action. DAVOS owns the player-facing `POST /api/turn`, the Pydantic input/output models, status mapping and safe fake DM/dispatcher/tool chain. BON owns Functional UAT. The future DES-016 dispatcher owns real routing; DES-017 Bookkeeper owns authoritative commits. Do not treat scope/caller declarations from arbitrary JSON as permissions.

## Explicit limitations

- No LLM, API key, token consumption while idle, CrewAI graph, HTTP tool-bus, websocket, combat, world state, database or cloud hosting.
- No real operational load shedding or long-lived active request draining beyond FastAPI/Uvicorn's normal lifespan behavior. DES-013.2 adds bounded request handling; production hardening later.
- Initial local-only ASGI factory, not a production authentication/remote access policy. Use `127.0.0.1` as shown.
- Scope remains within DES-013.1; user-facing action status and player-safe view must be enforced by injected trusted services, not by the registry.

## Build notes / ownership

COSTA implements the shared factory, registry and lifecycle; DAVOS consumes the factory and registers his DM/dispatcher and mock tool; BON coordinates future schema decisions and executes independent Functional UAT for 013.2. Follow Engineering Standards §§4,6,8,9,11–13 and record exact test run/source SHA at acceptance. CI is tracked separately under DES-027.1.