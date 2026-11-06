import os
import sqlite3
from contextlib import contextmanager
from .config import settings

def connect(db_path: str | None = None) -> sqlite3.Connection:
    target_path = db_path or settings.db_path
    db_dir = os.path.dirname(target_path)
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(target_path, timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    conn.execute("PRAGMA busy_timeout=10000;")
    return conn

@contextmanager
def get_db(db_path: str | None = None):
    conn = connect(db_path)
    try:
        yield conn
    finally:
        conn.close()

def init_db(db_path: str | None = None):
    base_dir = os.path.dirname(os.path.dirname(__file__))
    migration_path = os.path.join(base_dir, "migrations", "001_init.sql")
    with get_db(db_path) as db:
        with open(migration_path, "r", encoding="utf-8") as f:
            db.executescript(f.read())

