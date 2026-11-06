import os
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from loguru import logger

from .config import settings
from .db import init_db, get_db
from .logging_setup import setup_logging
from .routers import auth, chargers, bookings, payments, reviews, host, ai, admin

setup_logging()

if settings.sentry_dsn:
    try:
        import sentry_sdk
        sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)
        logger.info("Sentry initialized")
    except Exception as e:
        logger.warning(f"Could not initialize Sentry: {e}")

async def cleanup_expired_bookings():
    """Background task running every 60s to expire PENDING_PAYMENT bookings older than 10 mins"""
    while True:
        try:
            with get_db() as db:
                cur = db.execute("""
                    UPDATE bookings
                    SET status = 'EXPIRED'
                    WHERE status = 'PENDING_PAYMENT'
                      AND created_at < datetime('now', '-10 minutes')
                """)
                if cur.rowcount > 0:
                    logger.info(f"Expired {cur.rowcount} pending bookings")
        except Exception as e:
            logger.error(f"Error in cleanup task: {e}")
        await asyncio.sleep(60)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure DB and migrations are ready
    try:
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {e}")

    # Launch background cleanup task
    cleanup_task = asyncio.create_task(cleanup_expired_bookings())
    yield
    # Shutdown
    cleanup_task.cancel()

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])
app = FastAPI(title="ChargeBridge API", version="1.0.0", lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS configuration
allowed_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
if settings.app_env == "development" or "*" in allowed_origins or not allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins if ("*" not in allowed_origins and allowed_origins) else ["*"],
        allow_origin_regex=r"^https?://.*$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_origin_regex=r"^https?://.*$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["*"],
    )

os.makedirs(settings.upload_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

# Include all routers
for r in (auth, chargers, bookings, payments, reviews, host, ai, admin):
    app.include_router(r.router)

@app.get("/health")
def health():
    return {"status": "ok", "app": "ChargeBridge API", "version": "1.0.0"}

@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    logger.exception(f"Unhandled error on {request.url.path}: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again later."}
    )

