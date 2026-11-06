import time
from app.db import get_db

def test_booking_flow_and_double_booking(client, test_driver, test_host, test_charger):
    now = int(time.time())
    start_ts = now + 10000
    end_ts = start_ts + 7200  # 2 hours

    # 1. Driver creates booking
    res = client.post(
        "/bookings",
        json={
            "charger_id": test_charger,
            "start_ts": start_ts,
            "end_ts": end_ts,
        },
        headers=test_driver["headers"],
    )
    assert res.status_code == 201
    booking = res.json()
    assert booking["status"] == "PENDING_PAYMENT"
    booking_id = booking["id"]

    # 2. Clashing booking should be rejected with 409 Conflict
    clash_res = client.post(
        "/bookings",
        json={
            "charger_id": test_charger,
            "start_ts": start_ts + 1800,  # Overlaps!
            "end_ts": end_ts + 1800,
        },
        headers=test_driver["headers"],
    )
    assert clash_res.status_code == 409

    # 3. Host attempting to book their own charger should be rejected
    host_book_res = client.post(
        "/bookings",
        json={
            "charger_id": test_charger,
            "start_ts": end_ts + 1000,
            "end_ts": end_ts + 4600,
        },
        headers=test_host["headers"],
    )
    assert host_book_res.status_code == 400

    # 4. Confirm booking using test-confirm
    confirm_res = client.post(f"/payments/test-confirm/{booking_id}", headers=test_driver["headers"])
    assert confirm_res.status_code == 200

    # 5. Host marks completed
    complete_res = client.post(f"/bookings/{booking_id}/complete", headers=test_host["headers"])
    assert complete_res.status_code == 200

    # 6. Check host earnings
    earnings_res = client.get("/host/earnings", headers=test_host["headers"])
    assert earnings_res.status_code == 200
    earnings_data = earnings_res.json()
    assert earnings_data["completed_sessions"] >= 1

