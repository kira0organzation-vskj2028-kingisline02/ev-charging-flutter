import json
from fastapi import APIRouter, HTTPException, Request, Depends, status
from loguru import logger

from ..config import settings
from ..db import get_db
from ..deps import current_user, require_role, record_audit
from ..services.razorpay_client import verify_webhook_signature

router = APIRouter(prefix="/payments", tags=["payments"])

@router.post("/webhook")
async def razorpay_webhook(request: Request):
    body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature", "")

    if not verify_webhook_signature(body, signature):
        logger.warning("Invalid Razorpay webhook signature")
        raise HTTPException(status_code=400, detail="Invalid signature")

    try:
        event = json.loads(body.decode("utf-8"))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    event_type = event.get("event")
    logger.info(f"Received Razorpay webhook event: {event_type}")

    if event_type == "payment.captured":
        payload = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payload.get("order_id")
        payment_id = payload.get("id")

        if not order_id:
            return {"ok": True, "detail": "No order_id found"}

        with get_db() as db:
            payment = db.execute("SELECT * FROM payments WHERE provider_ref = ?", (order_id,)).fetchone()
            if not payment:
                logger.warning(f"No payment record found for order_id: {order_id}")
                return {"ok": True, "detail": "Order not found in database"}

            # Idempotency check
            if payment["status"] == "PAID":
                logger.info(f"Payment for order {order_id} already marked as PAID")
                return {"ok": True, "detail": "Already processed"}

            # Update payment and booking atomically
            db.execute("BEGIN IMMEDIATE")
            try:
                db.execute(
                    "UPDATE payments SET status = 'PAID', payment_id = ? WHERE id = ?",
                    (payment_id, payment["id"])
                )
                db.execute(
                    "UPDATE bookings SET status = 'CONFIRMED' WHERE id = ?",
                    (payment["booking_id"],)
                )
                db.execute("COMMIT")
                record_audit(db, None, "PAYMENT_CONFIRMED", f"Order {order_id} captured as {payment_id}", "")
                logger.info(f"Booking #{payment['booking_id']} successfully CONFIRMED via webhook")
            except Exception as e:
                db.execute("ROLLBACK")
                logger.error(f"Failed to confirm booking: {e}")
                raise HTTPException(status_code=500, detail="Database error updating booking")

    elif event_type == "payment.failed":
        payload = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payload.get("order_id")
        if order_id:
            with get_db() as db:
                db.execute("UPDATE payments SET status = 'FAILED' WHERE provider_ref = ?", (order_id,))
                record_audit(db, None, "PAYMENT_FAILED", f"Order {order_id} payment failed", "")

    return {"ok": True}

@router.post("/test-confirm/{booking_id}")
def test_confirm_booking(booking_id: int, user: dict = Depends(current_user)):
    """
    Convenience endpoint for local development / testing without live Razorpay webhooks.
    Allows confirming a PENDING_PAYMENT booking directly.
    """
    with get_db() as db:
        b = db.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        if user["role"] != "admin" and b["driver_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Not authorized to confirm this booking")

        if b["status"] != "PENDING_PAYMENT":
            return {"message": f"Booking is already in status: {b['status']}"}

        db.execute("BEGIN IMMEDIATE")
        try:
            db.execute("UPDATE payments SET status = 'PAID', payment_id = ? WHERE booking_id = ?",
                       (f"pay_mock_{booking_id}", booking_id))
            db.execute("UPDATE bookings SET status = 'CONFIRMED' WHERE id = ?", (booking_id,))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise

    return {"message": f"Booking #{booking_id} confirmed for testing.", "status": "CONFIRMED"}

