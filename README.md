# ⚡ ChargeBridge: EV Charger Sharing Marketplace

A marketplace app that connects **hosts** (people who own an EV charger) with **drivers** (people who need to charge). The platform earns a **commission on every booking**.

- **Frontend:** Flutter (Android, iOS, Web)
- **Backend:** FastAPI (Python)
- **Database:** SQLite (WAL mode) with Litestream backup
- **Cost:** every tool listed here has a free tier (see the "Honest notes" section for the limits)

---

## Table of Contents

1. [Honest notes before you start](#1-honest-notes-before-you-start)
2. [Business model](#2-business-model)
3. [System design and architecture](#3-system-design-and-architecture)
4. [Prerequisites and tools](#4-prerequisites-and-tools)
5. [Repository structure](#5-repository-structure)
6. [Phase 1: Database design (SQLite)](#6-phase-1-database-design-sqlite)
7. [Phase 2: Backend (FastAPI)](#7-phase-2-backend-fastapi)
8. [Phase 3: Authentication and permissions](#8-phase-3-authentication-and-permissions)
9. [Phase 4: Core business logic](#9-phase-4-core-business-logic)
10. [Phase 5: Payments](#10-phase-5-payments)
11. [Phase 6: AI features](#11-phase-6-ai-features)
12. [Phase 7: Security, rate limiting, caching](#12-phase-7-security-rate-limiting-caching)
13. [Phase 8: Logging, error tracking, monitoring](#13-phase-8-logging-error-tracking-monitoring)
14. [Phase 9: Flutter app](#14-phase-9-flutter-app)
15. [Phase 10: Website](#15-phase-10-website)
16. [Phase 11: Testing](#16-phase-11-testing)
17. [Phase 12: Deployment](#17-phase-12-deployment)
18. [Phase 13: CI/CD](#18-phase-13-cicd)
19. [Phase 14: Scaling path](#19-phase-14-scaling-path)
20. [Launch checklist](#20-launch-checklist)
21. [Roadmap](#21-roadmap)

---

## 1. Honest notes before you start

1. **SQLite lives on the server, not the phone.** Two users must see the same data, so the master database sits on the backend. The phone may keep a small local cache (`sqflite`) for offline viewing.
2. **SQLite limits:** it allows one writer at a time. In WAL mode this comfortably handles thousands of users for a marketplace of this kind. When you outgrow it, migrate to PostgreSQL (section 19).
3. **Payments are the one place "free" is not literally free.** Payment gateways charge a per-transaction fee (about 2% in India with Razorpay), with no monthly fee. You build this into your commission.
4. **Holding money and paying hosts later** (an escrow-style split) requires a marketplace product such as **Razorpay Route**. It needs business KYC and approval. For the MVP, you can start with **direct payment to the platform** and pay hosts manually or weekly.
5. **Free hosting has limits.** Oracle Cloud Always Free is the best fit for SQLite because it gives a persistent disk. Free tiers can change, so check current terms.
6. **Legal:** a business that earns money needs registration, GST (India), a privacy policy, terms of service, and clear electrical-safety terms for hosts. Talk to a local professional.
7. **Phone OTP by SMS costs money.** This guide uses email OTP and email and password sign-in instead.

---

## 2. Business model

| Revenue source | Details |
|---|---|
| Commission | 10-15% of each booking |
| Featured listing | Optional flat fee for hosts to rank higher |
| Later | Subscription for hosts with many chargers |

**Money flow:**

```
Driver pays ₹100  →  Platform receives ₹100
                      ├─ Commission (12%)  = ₹12  (your income)
                      └─ Host payout (88%) = ₹88  (paid after session completes)
```

Store `amount`, `commission` and `host_payout` on every booking so your accounting is always auditable.

---

## 3. System design and architecture

```
┌─────────────────────────────┐
│ Flutter App (Android/iOS/Web)│
└──────────────┬──────────────┘
               │ HTTPS, REST + JSON
┌──────────────▼──────────────┐
│ Cloudflare (free CDN, SSL,   │
│ DDoS protection)             │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│ Caddy reverse proxy          │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐      ┌──────────────────────┐
│ FastAPI backend (Uvicorn)    │─────▶│ SQLite (WAL)         │
│  modules: auth, chargers,    │      │ + Litestream backup  │
│  bookings, payments, reviews │      └──────────────────────┘
└───┬─────────┬─────────┬─────┘
    │         │         │
    ▼         ▼         ▼
 Razorpay   Firebase   Gemini API
 (payments) (push)     (AI, free tier)
```

**Why a modular monolith?** One deployable unit is cheap, simple to debug and fast to ship. Modules are separated by folder, so you can split them into services later if needed.

**Booking lifecycle:**

```
PENDING_PAYMENT → CONFIRMED → ACTIVE → COMPLETED
        │              │
        └── EXPIRED    └── CANCELLED (with refund rules)
```

---

## 4. Prerequisites and tools

All free.

| Tool | Purpose | Install |
|---|---|---|
| Python 3.11+ | Backend | python.org |
| Flutter SDK 3.22+ | App | docs.flutter.dev/get-started/install |
| Android Studio or VS Code | IDE and emulator | developer.android.com/studio |
| Git and GitHub account | Version control, CI | github.com |
| Razorpay account (test mode) | Payments | razorpay.com |
| Firebase project | Push notifications | console.firebase.google.com |
| Google AI Studio key | Gemini free tier | aistudio.google.com |
| Sentry account | Error tracking | sentry.io |
| Cloudflare account | CDN, Pages | cloudflare.com |
| Oracle Cloud account | Free VM | oracle.com/cloud/free |

Verify your install:

```bash
python --version
flutter doctor
git --version
```

---

## 5. Repository structure

```
chargebridge/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── db.py
│   │   ├── security.py
│   │   ├── deps.py
│   │   ├── logging_setup.py
│   │   ├── routers/
│   │   │   ├── auth.py
│   │   │   ├── chargers.py
│   │   │   ├── bookings.py
│   │   │   ├── payments.py
│   │   │   ├── reviews.py
│   │   │   ├── host.py
│   │   │   ├── ai.py
│   │   │   └── admin.py
│   │   ├── services/
│   │   │   ├── pricing.py
│   │   │   ├── geo.py
│   │   │   ├── razorpay_client.py
│   │   │   └── email.py
│   │   └── schemas.py
│   ├── migrations/
│   │   └── 001_init.sql
│   ├── tests/
│   ├── requirements.txt
│   └── .env.example
├── app/                  # Flutter project
├── deploy/
│   ├── Caddyfile
│   ├── chargebridge.service
│   └── litestream.yml
├── .github/workflows/ci.yml
└── README.md
```

Create it:

```bash
mkdir chargebridge && cd chargebridge
git init
mkdir -p backend/app/routers backend/app/services backend/migrations backend/tests deploy .github/workflows
```

---

## 6. Phase 1: Database design (SQLite)

### Step 1: Create the schema

`backend/migrations/001_init.sql`

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  role          TEXT NOT NULL CHECK (role IN ('driver','host','admin')),
  password_hash TEXT NOT NULL,
  is_verified   INTEGER NOT NULL DEFAULT 0,
  fcm_token     TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE chargers (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  host_id        INTEGER NOT NULL REFERENCES users(id),
  title          TEXT NOT NULL,
  description    TEXT,
  lat            REAL NOT NULL,
  lng            REAL NOT NULL,
  address        TEXT NOT NULL,
  connector_type TEXT NOT NULL,          -- CCS2, Type2, CHAdeMO, GB/T, 3-pin
  power_kw       REAL NOT NULL,
  price_per_kwh  REAL NOT NULL,
  price_per_hour REAL,
  photos         TEXT NOT NULL DEFAULT '[]',   -- JSON array of file paths
  is_active      INTEGER NOT NULL DEFAULT 1,
  is_featured    INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE availability (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  charger_id  INTEGER NOT NULL REFERENCES chargers(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  TEXT NOT NULL,             -- 'HH:MM'
  end_time    TEXT NOT NULL
);

CREATE TABLE bookings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  charger_id  INTEGER NOT NULL REFERENCES chargers(id),
  driver_id   INTEGER NOT NULL REFERENCES users(id),
  start_ts    INTEGER NOT NULL,          -- unix seconds, UTC
  end_ts      INTEGER NOT NULL,
  status      TEXT NOT NULL CHECK (status IN
              ('PENDING_PAYMENT','CONFIRMED','ACTIVE','COMPLETED','CANCELLED','EXPIRED')),
  amount      INTEGER NOT NULL,          -- paise, never floats for money
  commission  INTEGER NOT NULL,
  host_payout INTEGER NOT NULL,
  payout_status TEXT NOT NULL DEFAULT 'PENDING',  -- PENDING, PAID
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  CHECK (end_ts > start_ts)
);

CREATE TABLE payments (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id   INTEGER NOT NULL REFERENCES bookings(id),
  provider_ref TEXT NOT NULL UNIQUE,     -- Razorpay order id
  payment_id   TEXT,
  status       TEXT NOT NULL,            -- CREATED, PAID, REFUNDED, FAILED
  amount       INTEGER NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE reviews (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL UNIQUE REFERENCES bookings(id),
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE refresh_tokens (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE email_otps (
  email      TEXT NOT NULL,
  code_hash  TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE audit_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER,
  action     TEXT NOT NULL,
  detail     TEXT,
  ip         TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_chargers_geo     ON chargers(lat, lng);
CREATE INDEX idx_chargers_host    ON chargers(host_id);
CREATE INDEX idx_bookings_slot    ON bookings(charger_id, start_ts, end_ts);
CREATE INDEX idx_bookings_driver  ON bookings(driver_id);
CREATE INDEX idx_payments_booking ON payments(booking_id);
```

**Design rules used:**
- Money is stored as **integer paise**, never floating point.
- Timestamps are **UTC unix seconds**. Convert to local time only in the UI.
- Foreign keys are enforced with `PRAGMA foreign_keys = ON` (it must be set on every connection).

### Step 2: Connection helper with WAL mode

`backend/app/db.py`

```python
import sqlite3
from contextlib import contextmanager
from .config import settings

def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.db_path, timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    conn.execute("PRAGMA busy_timeout=10000;")
    return conn

@contextmanager
def get_db():
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()

def init_db():
    with get_db() as db:
        with open("migrations/001_init.sql") as f:
            db.executescript(f.read())
```

### Step 3: Run the migration

```bash
cd backend
python -c "from app.db import init_db; init_db()"
```

---

## 7. Phase 2: Backend (FastAPI)

### Step 1: Environment

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
```

`requirements.txt`

```
fastapi==0.115.*
uvicorn[standard]==0.32.*
pydantic[email]==2.*
pydantic-settings==2.*
argon2-cffi==23.*
pyjwt==2.*
slowapi==0.1.*
cachetools==5.*
loguru==0.7.*
sentry-sdk[fastapi]==2.*
razorpay==1.4.*
httpx==0.27.*
python-multipart==0.0.*
pillow==10.*
pytest==8.*
pytest-asyncio==0.24.*
```

```bash
pip install -r requirements.txt
```

### Step 2: Configuration

`.env.example` (copy to `.env`, **never commit `.env`**)

```
APP_ENV=development
DB_PATH=./chargebridge.db
JWT_SECRET=change-me-to-a-long-random-string
ACCESS_TOKEN_MINUTES=15
REFRESH_TOKEN_DAYS=30
COMMISSION_PERCENT=12
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx
GEMINI_API_KEY=xxx
SENTRY_DSN=
SMTP_HOST=smtp.gmail.com
SMTP_USER=you@gmail.com
SMTP_PASSWORD=app-password
CORS_ORIGINS=https://yourapp.pages.dev
UPLOAD_DIR=./uploads
```

Generate a strong secret:

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

`app/config.py`

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "development"
    db_path: str = "./chargebridge.db"
    jwt_secret: str
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    commission_percent: int = 12
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""
    gemini_api_key: str = ""
    sentry_dsn: str = ""
    smtp_host: str = ""
    smtp_user: str = ""
    smtp_password: str = ""
    cors_origins: str = ""
    upload_dir: str = "./uploads"

    class Config:
        env_file = ".env"

settings = Settings()
```

### Step 3: App entry point

`app/main.py`

```python
import os
import sentry_sdk
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from .config import settings
from .logging_setup import setup_logging
from .routers import auth, chargers, bookings, payments, reviews, host, ai, admin

setup_logging()
if settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])
app = FastAPI(title="ChargeBridge API", version="1.0.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o for o in settings.cors_origins.split(",") if o],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

os.makedirs(settings.upload_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

for r in (auth, chargers, bookings, payments, reviews, host, ai, admin):
    app.include_router(r.router)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    from loguru import logger
    logger.exception(f"Unhandled error on {request.url.path}")
    return JSONResponse({"detail": "Internal server error"}, status_code=500)
```

### Step 4: Run it

```bash
uvicorn app.main:app --reload
```

Open `http://localhost:8000/docs` for the auto-generated API explorer.

### Step 5: API reference

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/register` | none | Create account, send email OTP |
| POST | `/auth/verify-otp` | none | Verify email |
| POST | `/auth/login` | none | Get access and refresh tokens |
| POST | `/auth/refresh` | refresh | Rotate tokens |
| POST | `/auth/logout` | user | Revoke refresh token |
| GET | `/chargers` | user | Nearby search |
| GET | `/chargers/{id}` | user | Detail with reviews |
| POST | `/chargers` | host | Create listing |
| PUT | `/chargers/{id}` | host (owner) | Edit listing |
| POST | `/chargers/{id}/photos` | host (owner) | Upload photo |
| PUT | `/chargers/{id}/availability` | host (owner) | Set weekly hours |
| POST | `/bookings` | driver | Create booking and payment order |
| GET | `/bookings/mine` | user | List my bookings |
| POST | `/bookings/{id}/cancel` | owner | Cancel with refund rules |
| POST | `/bookings/{id}/complete` | host | Mark session complete |
| POST | `/payments/webhook` | signature | Razorpay confirmation |
| POST | `/reviews` | driver | Review a completed booking |
| GET | `/host/earnings` | host | Earnings summary |
| POST | `/ai/listing` | host | AI description and price suggestion |
| GET | `/admin/users`, `/admin/bookings` | admin | Moderation |

---

## 8. Phase 3: Authentication and permissions

### Step 1: Password hashing and tokens

`app/security.py`

```python
import hashlib, secrets, time
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from .config import settings

ph = PasswordHasher()

def hash_password(p: str) -> str:
    return ph.hash(p)

def verify_password(hashed: str, p: str) -> bool:
    try:
        return ph.verify(hashed, p)
    except VerifyMismatchError:
        return False

def make_access_token(user_id: int, role: str) -> str:
    now = int(time.time())
    payload = {"sub": str(user_id), "role": role, "iat": now,
               "exp": now + settings.access_token_minutes * 60, "type": "access"}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])

def new_refresh_token() -> tuple[str, str]:
    raw = secrets.token_urlsafe(48)
    return raw, hashlib.sha256(raw.encode()).hexdigest()   # store only the hash
```

### Step 2: Dependencies for protected routes

`app/deps.py`

```python
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from .security import decode_token

bearer = HTTPBearer()

def current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    try:
        data = decode_token(creds.credentials)
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid or expired token")
    if data.get("type") != "access":
        raise HTTPException(401, "Wrong token type")
    return {"id": int(data["sub"]), "role": data["role"]}

def require_role(*roles: str):
    def checker(user: dict = Depends(current_user)):
        if user["role"] not in roles:
            raise HTTPException(403, "Not allowed")
        return user
    return checker
```

### Step 3: Registration flow with email OTP

1. `POST /auth/register`: validate input, hash the password, save the user with `is_verified = 0`, generate a 6-digit code, store its **hash** with a 10-minute expiry, and email it.
2. `POST /auth/verify-otp`: compare the hash, allow at most 5 attempts, then set `is_verified = 1`.
3. `POST /auth/login`: only verified users get tokens. Rate limit to **5 per minute**.
4. `POST /auth/refresh`: check the stored hash, revoke the old token and issue a new pair (**rotation**).

Sending email for free: use a Gmail App Password over SMTP (about 500 emails per day), or Brevo's free plan (about 300 per day).

### Step 4: Permission matrix

| Action | Driver | Host | Admin |
|---|---|---|---|
| Search chargers | ✅ | ✅ | ✅ |
| Book a charger | ✅ | ❌ own charger | ✅ |
| Create or edit charger | ❌ | ✅ own only | ✅ |
| See host earnings | ❌ | ✅ own only | ✅ |
| Ban users, refund | ❌ | ❌ | ✅ |

**Rule:** every endpoint that takes an `id` must check ownership. The check `WHERE id = ? AND host_id = ?` is the pattern to use.

---

## 9. Phase 4: Core business logic

### Step 1: Nearby search (bounding box first, then Haversine)

`app/services/geo.py`

```python
import math

def bounding_box(lat: float, lng: float, radius_km: float):
    dlat = radius_km / 111.0
    dlng = radius_km / (111.0 * max(math.cos(math.radians(lat)), 0.01))
    return lat - dlat, lat + dlat, lng - dlng, lng + dlng

def haversine_km(lat1, lng1, lat2, lng2) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2 * r * math.asin(math.sqrt(a))
```

The query uses the indexed `lat, lng` columns to filter rows in the box, then Haversine sorts by exact distance in Python:

```sql
SELECT * FROM chargers
WHERE is_active = 1
  AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?
  AND (? IS NULL OR connector_type = ?);
```

### Step 2: Pricing

`app/services/pricing.py`

```python
from ..config import settings

def calculate(price_per_hour: float, start_ts: int, end_ts: int) -> dict:
    hours = (end_ts - start_ts) / 3600
    amount = round(price_per_hour * hours * 100)            # paise
    commission = round(amount * settings.commission_percent / 100)
    return {"amount": amount, "commission": commission,
            "host_payout": amount - commission}
```

**Never accept a price from the client.** Always recompute on the server.

### Step 3: Double-booking prevention

Use an immediate write transaction so two requests cannot both pass the check:

```python
def create_booking(db, charger_id, driver_id, start_ts, end_ts, price):
    db.execute("BEGIN IMMEDIATE")          # takes the write lock now
    try:
        clash = db.execute("""
            SELECT 1 FROM bookings
            WHERE charger_id = ?
              AND status IN ('PENDING_PAYMENT','CONFIRMED','ACTIVE')
              AND start_ts < ? AND end_ts > ?
            LIMIT 1""", (charger_id, end_ts, start_ts)).fetchone()
        if clash:
            db.execute("ROLLBACK")
            raise SlotTaken()
        cur = db.execute("""INSERT INTO bookings
            (charger_id, driver_id, start_ts, end_ts, status, amount, commission, host_payout)
            VALUES (?,?,?,?, 'PENDING_PAYMENT', ?,?,?)""",
            (charger_id, driver_id, start_ts, end_ts,
             price["amount"], price["commission"], price["host_payout"]))
        db.execute("COMMIT")
        return cur.lastrowid
    except Exception:
        db.execute("ROLLBACK")
        raise
```

Also validate that the slot falls inside the host's `availability` window, is in the future, and is at most a sensible length (for example 8 hours).

### Step 4: Expire unpaid bookings

A background task runs every minute and sets `PENDING_PAYMENT` bookings older than 10 minutes to `EXPIRED`, which frees the slot.

```python
@app.on_event("startup")
async def start_cleanup():
    import asyncio
    async def loop():
        while True:
            with get_db() as db:
                db.execute("""UPDATE bookings SET status='EXPIRED'
                  WHERE status='PENDING_PAYMENT'
                  AND created_at < datetime('now','-10 minutes')""")
            await asyncio.sleep(60)
    asyncio.create_task(loop())
```

### Step 5: Cancellation and refund policy

| Cancelled | Refund |
|---|---|
| More than 2 hours before start | 100% |
| Between 30 minutes and 2 hours before | 50% |
| Less than 30 minutes before | 0% |
| Cancelled by host | 100% to driver, host gets a strike |

### Step 6: Payout rule

When the host marks the session `COMPLETED` (or it auto-completes at `end_ts`), set `payout_status = 'PENDING'`. An admin screen lists the pending payouts, and you pay hosts by UPI or bank transfer weekly, then mark them `PAID`. Automate through Razorpay Route when approved.

---

## 10. Phase 5: Payments

### Step 1: Test-mode setup

1. Sign up at razorpay.com and stay in **Test Mode**.
2. Settings, then API Keys, then generate a key and put it into `.env`.
3. Settings, then Webhooks, then add `https://api.yourdomain.com/payments/webhook`, select `payment.captured` and `payment.failed`, and set a secret.

### Step 2: Create an order when booking

```python
import razorpay
client = razorpay.Client(auth=(settings.razorpay_key_id, settings.razorpay_key_secret))

order = client.order.create({
    "amount": price["amount"],            # paise, computed on the server
    "currency": "INR",
    "receipt": f"booking_{booking_id}",
})
# save order["id"] in payments.provider_ref, status 'CREATED'
```

Return `order_id` and `key_id` to the app. The app opens Razorpay Checkout.

### Step 3: Verify the webhook (this is the source of truth)

```python
import hmac, hashlib
from fastapi import Request, HTTPException

@router.post("/payments/webhook")
async def webhook(request: Request):
    body = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")
    expected = hmac.new(settings.razorpay_webhook_secret.encode(),
                        body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, sig):
        raise HTTPException(400, "Bad signature")
    event = json.loads(body)
    if event["event"] == "payment.captured":
        order_id = event["payload"]["payment"]["entity"]["order_id"]
        # in ONE transaction: payments.status='PAID', bookings.status='CONFIRMED'
        # make this idempotent: ignore if already PAID
    return {"ok": True}
```

**Never confirm a booking from the app's "payment success" callback alone.** Only the verified webhook confirms.

### Step 4: Refunds

```python
client.payment.refund(payment_id, {"amount": refund_paise})
```

Save the result and set the payment status to `REFUNDED` (or partial).

### Step 5: Going live

Complete Razorpay KYC, switch to live keys, and repeat the webhook setup with live credentials. Test with a real ₹1 payment first.

---

## 11. Phase 6: AI features

Two useful, low-risk features using the **Gemini free tier**.

### Feature 1: Listing writer and price suggestion (for hosts)

**System prompt:**

```
You are an assistant for an EV charger rental marketplace in India.
Given the host's details (location, connector type, kW, amenities),
write a friendly 60-word listing description and suggest a price
range per kWh based on typical local rates.
Return JSON only, no markdown:
{"description": "...", "suggested_price_min": n, "suggested_price_max": n}
Never invent amenities that were not provided.
```

### Backend call

```python
import httpx, json

async def generate_listing(details: dict) -> dict:
    url = ("https://generativelanguage.googleapis.com/v1beta/models/"
           "gemini-1.5-flash:generateContent?key=" + settings.gemini_api_key)
    payload = {"contents": [{"parts": [{"text": SYSTEM_PROMPT + json.dumps(details)}]}],
               "generationConfig": {"responseMimeType": "application/json"}}
    async with httpx.AsyncClient(timeout=20) as c:
        r = await c.post(url, json=payload)
        r.raise_for_status()
    text = r.json()["candidates"][0]["content"]["parts"][0]["text"]
    return json.loads(text)
```

Model names change over time, so check the current free model in Google AI Studio.

**Safeguards:**
- The API key stays on the server.
- Rate limit `/ai/listing` to 5 per minute per user.
- Validate the JSON before returning. If parsing fails, return a friendly error.
- Treat suggestions as hints. The host decides the final text and price.

### Feature 2 (optional): Review summaries

Summarize the last 20 reviews of a charger into 2 sentences, and cache the result for 24 hours.

---

## 12. Phase 7: Security, rate limiting, caching

### Security checklist

- [ ] HTTPS everywhere (Caddy and Cloudflare handle certificates)
- [ ] Argon2 password hashing, minimum password length 8
- [ ] Short-lived JWT (15 min) plus rotating refresh tokens
- [ ] All SQL uses `?` parameters, never string formatting
- [ ] Pydantic validates every request body
- [ ] Ownership check on every `id` endpoint
- [ ] Server recomputes all prices
- [ ] Webhook signature verified, handler idempotent
- [ ] CORS allow-list only (no `*`)
- [ ] Secrets only in environment variables
- [ ] Image uploads: allow only jpeg/png/webp, max 5 MB, re-encode with Pillow, random file names
- [ ] Audit log for logins, bookings, refunds, admin actions
- [ ] Security headers (set in Caddy): `X-Content-Type-Options`, `Strict-Transport-Security`
- [ ] Daily backups (section 17)
- [ ] Flutter: tokens in `flutter_secure_storage`, never `SharedPreferences`

### Rate limiting

```python
from slowapi import Limiter
limiter = Limiter(key_func=get_remote_address)

@router.post("/auth/login")
@limiter.limit("5/minute")
async def login(request: Request, body: LoginIn): ...

@router.post("/ai/listing")
@limiter.limit("5/minute")
async def ai_listing(request: Request, ...): ...
```

| Endpoint | Limit |
|---|---|
| Default | 100/min per IP |
| Login, OTP | 5/min |
| Register | 3/min |
| Booking | 10/min |
| AI | 5/min |

Behind a proxy, make sure the real client IP is used (`X-Forwarded-For` via Caddy or Cloudflare `CF-Connecting-IP`), or all users will share one limit.

### Caching

```python
from cachetools import TTLCache
search_cache = TTLCache(maxsize=1000, ttl=45)

key = (round(lat, 3), round(lng, 3), radius, connector)
if key in search_cache:
    return search_cache[key]
# ...query, then search_cache[key] = result
```

Rounding coordinates to 3 decimals (about 100 m) makes cache hits much more likely. Clear the cache when a charger is created or edited.

Add HTTP headers: `Cache-Control: public, max-age=30` for search and `max-age=31536000, immutable` for photos.

### CDN

Put your domain on **Cloudflare (free)**. Turn on proxying, "Always HTTPS", caching for `/uploads/*`, and Brotli compression. Convert uploaded photos to WebP (about 200 KB max).

---

## 13. Phase 8: Logging, error tracking, monitoring

### Structured logs

`app/logging_setup.py`

```python
import sys
from loguru import logger

def setup_logging():
    logger.remove()
    logger.add(sys.stdout, serialize=True, level="INFO")
    logger.add("logs/app.log", rotation="10 MB", retention="14 days",
               compression="zip", serialize=True, level="INFO")
```

Log booking created, payment confirmed, refund issued, login failures and webhook failures. **Never log passwords, tokens or full card data.**

### Error tracking (Sentry free tier)

- Backend: already initialised in `main.py` through `sentry_sdk.init`.
- Flutter:

```dart
await SentryFlutter.init(
  (o) => o.dsn = 'YOUR_DSN',
  appRunner: () => runApp(const ProviderScope(child: MyApp())),
);
```

### Monitoring and alerts

1. **UptimeRobot (free):** monitor `https://api.yourdomain.com/health` every 5 minutes, with email or Telegram alerts.
2. **Telegram alert bot (free):** send a message when a webhook fails or an unhandled exception occurs.
3. **Basic metrics:** an admin endpoint showing bookings today, revenue today, failed payments and DB file size.
4. Optional: Grafana Cloud free tier with Prometheus metrics.

Set alerts for: server down, error rate spike in Sentry, failed payment webhooks, disk usage above 80%.

---

## 14. Phase 9: Flutter app

### Step 1: Create the project

```bash
cd chargebridge
flutter create app --org com.chargebridge --platforms android,ios,web
cd app
```

### Step 2: Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.0.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  flutter_map: ^7.0.0
  latlong2: ^0.9.1
  geolocator: ^12.0.0
  sqflite: ^2.3.0
  path: ^1.9.0
  razorpay_flutter: ^1.3.7
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  sentry_flutter: ^8.0.0
  image_picker: ^1.1.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.0
```

```bash
flutter pub get
```

Use **OpenStreetMap tiles** via `flutter_map` instead of Google Maps. Follow the OSM tile usage policy: set a proper user-agent, and use a free tile provider such as MapTiler's free tier for heavy traffic.

### Step 3: Folder structure

```
app/lib/
├── main.dart
├── core/
│   ├── api_client.dart        # Dio, interceptors, token refresh
│   ├── secure_store.dart
│   ├── router.dart
│   └── theme.dart
├── data/
│   ├── models/                # User, Charger, Booking, Review
│   ├── repositories/
│   └── local_db.dart          # sqflite cache
└── features/
    ├── auth/                  # login, register, verify OTP
    ├── map/                   # nearby chargers
    ├── charger_detail/
    ├── booking/               # slot picker, payment
    ├── my_bookings/
    ├── host/                  # dashboard, add charger, earnings
    ├── reviews/
    └── profile/
```

### Step 4: API client with automatic token refresh

```dart
class ApiClient {
  final Dio dio = Dio(BaseOptions(baseUrl: const String.fromEnvironment(
      'API_URL', defaultValue: 'http://10.0.2.2:8000')));

  ApiClient(SecureStore store) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final t = await store.accessToken();
        if (t != null) opts.headers['Authorization'] = 'Bearer $t';
        handler.next(opts);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 && await _refresh(store)) {
          final r = await dio.fetch(e.requestOptions);   // retry once
          return handler.resolve(r);
        }
        handler.next(e);
      },
    ));
  }
}
```

`10.0.2.2` is how the Android emulator reaches your computer's localhost.

### Step 5: Build the screens in this order

1. **Auth:** register, OTP verification, login. Save tokens in secure storage.
2. **Map screen:** get the location (`geolocator`), call `GET /chargers`, draw markers, show a bottom sheet card on tap. Add connector-type filter chips.
3. **Charger detail:** photos, price, connector, rating, reviews, "Book" button.
4. **Booking:** date and time picker, a price preview from the server, then pay.
5. **Payment:** open Razorpay Checkout with `order_id`. On success, show "Confirming..." and **poll** `GET /bookings/{id}` until the status is `CONFIRMED` (the webhook confirms it).
6. **My bookings:** upcoming, past and cancelled tabs, with a cancel button that shows the refund amount first.
7. **Host dashboard:** my chargers, add and edit form with an "Generate with AI" button, availability editor, bookings received, earnings chart.
8. **Reviews:** star rating after a completed booking.
9. **Profile:** edit details, switch to "become a host", logout.

### Step 6: Offline cache

Store the last search results and the user's bookings in `sqflite`. Show cached data instantly, then refresh from the network. Show a small "offline" banner when there is no connection.

### Step 7: Push notifications (free FCM)

1. Create a Firebase project, then run `flutterfire configure`.
2. On login, send the FCM token to `PUT /users/me/fcm-token`.
3. The backend sends notifications through the FCM HTTP v1 API (service account JSON) for: booking confirmed, host got a new booking, a session starts in 30 minutes, and a payout was made.

### Step 8: Run

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

### Step 9: Build release

```bash
# Android
flutter build appbundle --release --dart-define=API_URL=https://api.yourdomain.com
# iOS (needs a Mac and an Apple developer account)
flutter build ipa --release --dart-define=API_URL=https://api.yourdomain.com
```

**Store fees:** Google Play charges a one-time registration fee, and the Apple Developer Program is paid yearly. Both are unavoidable for store publishing. The web version and direct APK sharing are free.

---

## 15. Phase 10: Website

Flutter compiles to the web, so the same code gives you a site.

```bash
cd app
flutter build web --release --dart-define=API_URL=https://api.yourdomain.com
```

Deploy free on **Cloudflare Pages**:

1. Push the repo to GitHub.
2. Cloudflare dashboard, then Workers and Pages, then Create, then Pages, then connect the repo.
3. Build output directory: `app/build/web`. Because Pages doesn't have Flutter preinstalled, the easiest way is to build in GitHub Actions and upload the folder (see section 18).
4. Add your custom domain and enable HTTPS.

**Landing page and SEO:** a Flutter web app is weak for search engines. Create a simple static `landing/index.html` (plain HTML and CSS) at your main domain, with "How it works", host signup and download links, and serve the app at `app.yourdomain.com`. Also add a privacy policy page and terms page, which Google Play and Razorpay both require.

Add CORS for your web origin in the backend `.env`.

---

## 16. Phase 11: Testing

### Backend tests (`pytest`)

Test these first, because they protect your money:

| Test | What it proves |
|---|---|
| Overlap detection | Two bookings can't share a slot |
| Concurrent booking | Two simultaneous requests: exactly one succeeds |
| Pricing | Commission plus payout equals amount, with rounding correct |
| Cancellation refund tiers | The right refund at each time boundary |
| Webhook bad signature | Rejected with 400 |
| Webhook replay | Confirming twice does not double-process |
| Auth | Expired token gives 401, a driver editing a charger gives 403 |
| Ownership | Host A cannot edit host B's charger |
| Rate limit | The 6th login in a minute gives 429 |

Example:

```python
def test_overlap_rejected(db, charger, driver):
    create_booking(db, charger, driver, 1000, 4600, PRICE)
    with pytest.raises(SlotTaken):
        create_booking(db, charger, driver, 3000, 6000, PRICE)

def test_commission_split():
    p = calculate(100.0, 0, 3600)
    assert p["amount"] == p["commission"] + p["host_payout"]
```

Use a temporary database file per test run. Run with:

```bash
cd backend && pytest -q
```

### Flutter tests

```bash
flutter test                              # unit and widget
flutter test integration_test             # end-to-end on emulator
```

Cover: login form validation, price formatting, the token refresh interceptor, the booking flow with a mocked API.

### Load test (`locust`)

```bash
pip install locust
locust -f tests/locustfile.py --host http://localhost:8000
```

Simulate 200 users searching and 20 booking simultaneously. Watch for `database is locked` errors, and if they appear, increase `busy_timeout` and keep write transactions short.

### Manual QA checklist

Register, verify, login, search, book, pay with a Razorpay test card, see the confirmed status, cancel and check the refund, host marks complete, review, and check that earnings update.

---

## 17. Phase 12: Deployment

### Step 1: Create the free server

1. Create an Oracle Cloud account and launch an **Always Free** Ubuntu VM (ARM Ampere instances are generous).
2. Open ports 80 and 443 in the VCN security list, and also in the VM firewall:

```bash
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
```

### Step 2: Install dependencies

```bash
sudo apt update && sudo apt install -y python3-venv python3-pip git caddy
```

### Step 3: Deploy the code

```bash
git clone https://github.com/YOU/chargebridge.git
cd chargebridge/backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env && nano .env           # fill in real values
python -c "from app.db import init_db; init_db()"
```

### Step 4: Run as a service (`deploy/chargebridge.service`)

```ini
[Unit]
Description=ChargeBridge API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/chargebridge/backend
EnvironmentFile=/home/ubuntu/chargebridge/backend/.env
ExecStart=/home/ubuntu/chargebridge/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo cp deploy/chargebridge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chargebridge
```

**Use one worker.** SQLite with an in-memory cache and a background task works best in a single process. Uvicorn's async handling is enough for this scale.

### Step 5: HTTPS reverse proxy (`deploy/Caddyfile`)

```
api.yourdomain.com {
    encode gzip zstd
    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options "nosniff"
    }
    reverse_proxy 127.0.0.1:8000
}
```

```bash
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy
```

Caddy gets and renews free certificates automatically.

### Step 6: Domain and Cloudflare

Buy a domain (the one unavoidable small cost, or use a free subdomain service for testing), add it to Cloudflare, create an `A` record `api` pointing to the VM IP with the proxy turned on, and set SSL mode to **Full (strict)**.

### Step 7: Backups with Litestream (free, continuous)

Litestream streams SQLite changes to storage. Free destinations: Cloudflare R2 free tier, Backblaze B2 free tier, or another disk.

`deploy/litestream.yml`

```yaml
dbs:
  - path: /home/ubuntu/chargebridge/backend/chargebridge.db
    replicas:
      - type: s3
        bucket: chargebridge-backup
        path: db
        endpoint: https://<account>.r2.cloudflarestorage.com
        access-key-id: ${LITESTREAM_ACCESS_KEY_ID}
        secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}
```

Also back up `uploads/` nightly with `rclone` through cron.

**Test your restore.** A backup you have never restored is not a backup:

```bash
litestream restore -o restored.db s3://chargebridge-backup/db
```

### Step 7b: Updating the server

```bash
cd ~/chargebridge && git pull
cd backend && source .venv/bin/activate && pip install -r requirements.txt
sudo systemctl restart chargebridge
```

---

## 18. Phase 13: CI/CD

`.github/workflows/ci.yml`

```yaml
name: CI
on: [push, pull_request]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: pip install -r backend/requirements.txt
      - run: cd backend && JWT_SECRET=test pytest -q

  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: cd app && flutter pub get && flutter analyze && flutter test

  deploy-web:
    needs: [backend, flutter]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: cd app && flutter build web --release --dart-define=API_URL=https://api.yourdomain.com
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy app/build/web --project-name=chargebridge
```

Store secrets in GitHub, then Settings, then Secrets. For backend auto-deploy, add an SSH step that runs the update commands from step 7b.

---

## 19. Phase 14: Scaling path

| Stage | Users | What to do |
|---|---|---|
| 1 | up to a few thousand | One VM, SQLite WAL, in-memory cache. Current setup. |
| 2 | 5k to 50k | Add Redis for cache and rate limits, move photos to object storage (R2), add a read-optimised search index. Upgrade the VM. |
| 3 | 50k+ | Migrate SQLite to **PostgreSQL** with PostGIS for geo queries. Run several API instances behind a load balancer. Use a job queue (Celery or RQ) for emails, push and payouts. |

**Signals that it is time to move on:**
- `database is locked` errors despite short transactions
- Write latency consistently above 200 ms
- You need more than one server instance

The schema was written with portable SQL, so migration to PostgreSQL is mostly changing types (`AUTOINCREMENT` to `SERIAL`, and `datetime` to `timestamptz`).

---

## 20. Launch checklist

**Product**
- [ ] Privacy policy, terms of service, refund policy published
- [ ] Host safety terms (electrical safety, insurance, liability)
- [ ] Host identity check (at least phone or email plus an ID photo reviewed by admin)
- [ ] Support email address and a way to report problems

**Technical**
- [ ] All tests pass in CI
- [ ] Load test done
- [ ] Live Razorpay keys and webhook verified with a real ₹1 payment
- [ ] Backups running and a restore tested
- [ ] Sentry, UptimeRobot and Telegram alerts working
- [ ] Debug mode off, secrets rotated, CORS locked down
- [ ] App icons, screenshots and store listing ready

**Business**
- [ ] Business registration and bank account
- [ ] GST and invoicing sorted for commission income
- [ ] Launch in one city first, and sign up 20 to 30 hosts before opening to drivers, because a marketplace without supply fails

---

## 21. Roadmap

1. **Week 1-2:** database, auth, charger CRUD, search
2. **Week 3:** bookings, pricing, overlap protection, tests
3. **Week 4:** payments, webhook, refunds
4. **Week 5-6:** Flutter app (auth, map, detail, booking, payment)
5. **Week 7:** host dashboard, reviews, push notifications, AI listing writer
6. **Week 8:** security pass, load test, deployment, monitoring
7. **Week 9:** closed beta in one city
8. **After launch:** payouts automation, featured listings, in-app chat, charging-session tracking, ratings for drivers

---

## License

Choose a license for your repository (MIT is common) or keep it private.
