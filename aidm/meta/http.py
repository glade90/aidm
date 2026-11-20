"""Thin FastAPI ASGI adapter for the AIDM Meta Service lifecycle.

Purpose: Expose safe local health/status and injected player-turn routing.
Usage: python -m uvicorn aidm.meta.http:create_app --factory --host 127.0.0.1 --port 8000
Change Log: 2026-11-20 COSTA — AIDM-DES-013.1 initial FastAPI bootstrap.
            2026-11-20 DAVOS — AIDM-DES-013.2 mounted /api/turn.

Importing this module does not start a server, load .env or call an LLM.
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from aidm.config import Settings, load_config
from aidm.meta.runtime import MetaRuntime, MockTool, RuntimeLogger, ServiceRegistry
from aidm.meta.turn import router as turn_router, turn_validation_error


class HealthResponse(BaseModel):
    state: str
    ready: bool


class StatusResponse(BaseModel):
    state: str
    ready: bool
    capabilities: list[str]
    build: dict[str, str | bool | None]


def create_app(
    settings: Settings | None = None, *,
    registry: ServiceRegistry | None = None,
    logger: RuntimeLogger | None = None,
) -> FastAPI:
    """Build one app without starting Uvicorn or invoking any model.

    POST /api/turn consumes an injected `dm` service; no second server exists.
    The mock composition registers `dm`, `dispatcher` and `mock_tool`.
    """
    effective = settings if settings is not None else load_config()
    if registry is None:
        registry = ServiceRegistry(required=("mock_tool",))
        registry.register("mock_tool", MockTool())
    runtime = MetaRuntime(effective, registry, logger=logger)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        try:
            await runtime.start()
            app.version = str(runtime.status()["build"]["version"])
        except Exception:
            # ASGI startup fails, and Uvicorn must not claim successful startup.
            raise
        try:
            yield
        finally:
            await runtime.stop()

    development = effective.mode == "development"
    app = FastAPI(
        title="AIDM Meta Service", version="UNKNOWN",
        docs_url="/docs" if development else None,
        redoc_url=None, openapi_url="/openapi.json" if development else None,
        lifespan=lifespan,
    )
    app.state.meta_runtime = runtime
    app.state.registry = registry
    app.include_router(turn_router)
    app.add_exception_handler(RequestValidationError, turn_validation_error)

    @app.get("/health", response_model=HealthResponse)
    async def health():
        response = runtime.health()
        return JSONResponse(status_code=200 if runtime.ready else 503, content=response)

    @app.get("/status", response_model=StatusResponse)
    async def status():
        response = runtime.status()
        return JSONResponse(status_code=200 if runtime.ready else 503, content=response)

    return app