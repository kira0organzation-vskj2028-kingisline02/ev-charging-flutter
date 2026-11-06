import json
import hmac
import hashlib
import time
from app.config import settings
from app.db import get_db

def test_webhook_processing(client, test_driver, test_charger):
    now = int(time.time())
    # Create booking first
    b_res = client.post(
        "/bookings",
        json={
            "charger_id": test_charger,
            "start_ts": now + 20000,
            "end_ts": now + 23600,
        },
        headers=test_driver["headers"],
    )
    assert b_res.status_code == 201
    booking_id = b_res.json()["id"]
    order_id = b_res.json()["order_id"]

    # Construct webhook event
    payload = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "id": "pay_test_9999",
                    "order_id": order_id,
                    "amount": 20000,
                    "status": "captured",
                }
            }
        }
    }
    raw_body = json.dumps(payload).encode("utf-8")
    sig = hmac.new(
        settings.razorpay_webhook_secret.encode("utf-8"),
        raw_body,
        hashlib.sha256
    ).hexdigest()

    # Test bad signature
    bad_res = client.post(
        "/payments/webhook",
        content=raw_body,
        headers={"X-Razorpay-Signature": "invalid_signature"}
    )
    assert bad_res.status_code == 400

    # Test good signature
    good_res = client.post(
        "/payments/webhook",
        content=raw_body,
        headers={"X-Razorpay-Signature": sig}
    )
    assert good_res.status_code == 200

    # Verify status in DB
    with get_db() as db:
        b = db.execute("SELECT status FROM bookings WHERE id = ?", (booking_id,)).fetchone()
        assert b["status"] == "CONFIRMED"

    # Idempotency test: replay webhook
    replay_res = client.post(
        "/payments/webhook",
        content=raw_body,
        headers={"X-Razorpay-Signature": sig}
    )
    assert replay_res.status_code == 200

