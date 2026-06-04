from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from app.config import settings
from app.routers import auth, health, records
from app.core.exceptions import generic_exception_handler

app = FastAPI(
    title="SkinLog API",
    version="0.1.0",
    description="Backend do SkinLog — diário visual inteligente da pele.",
)

origins = (
    ["*"]
    if settings.backend_cors_origins == "*"
    else [o.strip() for o in settings.backend_cors_origins.split(",")]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(Exception, generic_exception_handler)

PREFIX = "/api/v1"
app.include_router(health.router)
app.include_router(auth.router, prefix=PREFIX)
app.include_router(records.router, prefix=PREFIX)

static_dir = Path(__file__).parent.parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
