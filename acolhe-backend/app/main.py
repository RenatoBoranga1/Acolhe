from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import get_settings
from app.core.database import configure_database, get_engine, session_scope
from app.core.logging import configure_logging
from app.core.rate_limit import RateLimitMiddleware
from app.models import Base
from app.schemas.common import HealthResponse
from app.services.seed import ensure_demo_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    configure_logging()
    configure_database(settings.database_url)
    Base.metadata.create_all(bind=get_engine())
    if settings.seed_demo_data:
        with session_scope() as session:
            ensure_demo_data(session)
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description="API do Acolhe para apoio inicial seguro e organizacao de proximos passos.",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RateLimitMiddleware, max_requests_per_minute=settings.rate_limit_per_minute)
    app.include_router(api_router, prefix=settings.api_prefix)

    @app.get("/health", response_model=HealthResponse, tags=["health"])
    def healthcheck() -> HealthResponse:
        return HealthResponse(
            status="ok",
            app=settings.app_name,
            timestamp=datetime.now(timezone.utc),
        )

    return app


app = create_app()
