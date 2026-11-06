PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
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

CREATE TABLE IF NOT EXISTS chargers (
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

CREATE TABLE IF NOT EXISTS availability (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  charger_id  INTEGER NOT NULL REFERENCES chargers(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  TEXT NOT NULL,             -- 'HH:MM'
  end_time    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bookings (
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

CREATE TABLE IF NOT EXISTS payments (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id   INTEGER NOT NULL REFERENCES bookings(id),
  provider_ref TEXT NOT NULL UNIQUE,     -- Razorpay order id
  payment_id   TEXT,
  status       TEXT NOT NULL,            -- CREATED, PAID, REFUNDED, FAILED
  amount       INTEGER NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS reviews (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL UNIQUE REFERENCES bookings(id),
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  token_hash TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS email_otps (
  email      TEXT NOT NULL,
  code_hash  TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER,
  action     TEXT NOT NULL,
  detail     TEXT,
  ip         TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_chargers_geo     ON chargers(lat, lng);
CREATE INDEX IF NOT EXISTS idx_chargers_host    ON chargers(host_id);
CREATE INDEX IF NOT EXISTS idx_bookings_slot    ON bookings(charger_id, start_ts, end_ts);
CREATE INDEX IF NOT EXISTS idx_bookings_driver  ON bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);

