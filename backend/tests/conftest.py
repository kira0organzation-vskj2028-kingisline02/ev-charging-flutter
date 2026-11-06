import os
import tempfile
import pytest
from fastapi.testclient import TestClient

# Use temp database for tests
temp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DB_PATH"] = temp_db.name
os.environ["JWT_SECRET"] = "test-secret-key-32-chars-long-12345"
os.environ["RAZORPAY_WEBHOOK_SECRET"] = "test_webhook_secret_123"

from app.main import app
from app.db import init_db, get_db
from app.security import hash_password, make_access_token

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    init_db(temp_db.name)
    yield
    try:
        os.remove(temp_db.name)
    except Exception:
        pass

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def test_driver(client):
    with get_db() as db:
        # Check if driver exists
        row = db.execute("SELECT * FROM users WHERE email = 'driver@test.com'").fetchone()
        if not row:
            cur = db.execute("""
                INSERT INTO users (name, email, role, password_hash, is_verified)
                VALUES ('Test Driver', 'driver@test.com', 'driver', ?, 1)
            """, (hash_password("Password123!"),))
            user_id = cur.lastrowid
        else:
            user_id = row["id"]

    token = make_access_token(user_id, "driver")
    return {"id": user_id, "token": token, "email": "driver@test.com", "headers": {"Authorization": f"Bearer {token}"}}

@pytest.fixture
def test_host(client):
    with get_db() as db:
        row = db.execute("SELECT * FROM users WHERE email = 'host@test.com'").fetchone()
        if not row:
            cur = db.execute("""
                INSERT INTO users (name, email, role, password_hash, is_verified)
                VALUES ('Test Host', 'host@test.com', 'host', ?, 1)
            """, (hash_password("Password123!"),))
            user_id = cur.lastrowid
        else:
            user_id = row["id"]

    token = make_access_token(user_id, "host")
    return {"id": user_id, "token": token, "email": "host@test.com", "headers": {"Authorization": f"Bearer {token}"}}

@pytest.fixture
def test_charger(test_host):
    with get_db() as db:
        row = db.execute("SELECT id FROM chargers WHERE host_id = ?", (test_host["id"],)).fetchone()
        if not row:
            cur = db.execute("""
                INSERT INTO chargers (host_id, title, description, lat, lng, address, connector_type, power_kw, price_per_kwh, price_per_hour, photos, is_active)
                VALUES (?, 'Connaught Place Fast Charger', 'Near Metro station', 28.6315, 77.2167, 'CP, New Delhi', 'CCS2', 22.0, 16.0, 200.0, '[]', 1)
            """, (test_host["id"],))
            charger_id = cur.lastrowid
        else:
            charger_id = row["id"]
    return charger_id

