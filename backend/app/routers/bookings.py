import time
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..config import settings
from ..db import get_db
from ..deps import current_user, record_audit
from ..services.pricing import calculate, calculate_refund
from ..services.razorpay_client import create_order, refund_payment
from ..schemas import (
    BookingPricePreviewIn,
    BookingPricePreviewOut,
    BookingCreate,
    BookingOut,
    CancelBookingResponse,
)

router = APIRouter(prefix="/bookings", tags=["bookings"])
limiter = Limiter(key_func=get_remote_address)

@router.post("/preview", response_model=BookingPricePreviewOut)
def preview_price(body: BookingPricePreviewIn):
    if body.end_ts <= body.start_ts:
        raise HTTPException(status_code=400, detail="end_ts must be after start_ts")

    with get_db() as db:
        charger = db.execute("SELECT * FROM chargers WHERE id = ?", (body.charger_id,)).fetchone()
        if not charger:
            raise HTTPException(status_code=404, detail="Charger not found")

        price_per_hour = charger["price_per_hour"]
        if price_per_hour is None:
            price_per_hour = round(charger["price_per_kwh"] * min(charger["power_kw"], 7.4), 2)

    pricing = calculate(price_per_hour, body.start_ts, body.end_ts)
    return BookingPricePreviewOut(
        amount=pricing["amount"],
        commission=pricing["commission"],
        host_payout=pricing["host_payout"],
        hours=pricing["hours"],
    )

@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
def create_booking(request: Request, body: BookingCreate, user: dict = Depends(current_user)):
    now = int(time.time())
    if body.start_ts < now - 300:
        raise HTTPException(status_code=400, detail="Start time cannot be in the past")
    if body.end_ts <= body.start_ts:
        raise HTTPException(status_code=400, detail="End time must be after start time")
    if (body.end_ts - body.start_ts) > (8 * 3600):
        raise HTTPException(status_code=400, detail="Booking cannot exceed 8 hours")

    with get_db() as db:
        charger = db.execute("SELECT * FROM chargers WHERE id = ?", (body.charger_id,)).fetchone()
        if not charger:
            raise HTTPException(status_code=404, detail="Charger not found")
        if not charger["is_active"]:
            raise HTTPException(status_code=400, detail="Charger is currently inactive")

        # Host cannot book their own charger
        if charger["host_id"] == user["id"] and user["role"] != "admin":
            raise HTTPException(status_code=400, detail="Hosts cannot book their own chargers")

        price_per_hour = charger["price_per_hour"]
        if price_per_hour is None:
            price_per_hour = round(charger["price_per_kwh"] * min(charger["power_kw"], 7.4), 2)

        pricing = calculate(price_per_hour, body.start_ts, body.end_ts)

        # Immediate lock to prevent double booking race conditions
        db.execute("BEGIN IMMEDIATE")
        try:
            clash = db.execute("""
                SELECT 1 FROM bookings
                WHERE charger_id = ?
                  AND status IN ('PENDING_PAYMENT','CONFIRMED','ACTIVE')
                  AND start_ts < ? AND end_ts > ?
                LIMIT 1
            """, (body.charger_id, body.end_ts, body.start_ts)).fetchone()

            if clash:
                db.execute("ROLLBACK")
                raise HTTPException(status_code=409, detail="This time slot is already reserved. Please select another slot.")

            cur = db.execute("""
                INSERT INTO bookings (charger_id, driver_id, start_ts, end_ts, status, amount, commission, host_payout, payout_status)
                VALUES (?, ?, ?, ?, 'PENDING_PAYMENT', ?, ?, ?, 'PENDING')
            """, (
                body.charger_id, user["id"], body.start_ts, body.end_ts,
                pricing["amount"], pricing["commission"], pricing["host_payout"]
            ))
            booking_id = cur.lastrowid

            # Create payment order via Razorpay / mock
            order = create_order(pricing["amount"], receipt=f"booking_{booking_id}")
            order_id = order["id"]

            db.execute("""
                INSERT INTO payments (booking_id, provider_ref, status, amount)
                VALUES (?, ?, 'CREATED', ?)
            """, (booking_id, order_id, pricing["amount"]))

            db.execute("COMMIT")
        except HTTPException:
            raise
        except Exception as e:
            db.execute("ROLLBACK")
            raise HTTPException(status_code=500, detail=f"Booking creation error: {str(e)}")

        record_audit(db, user["id"], "BOOKING_CREATED", f"Booking #{booking_id} for charger #{body.charger_id}", request.client.host if request.client else "")

    return BookingOut(
        id=booking_id,
        charger_id=body.charger_id,
        driver_id=user["id"],
        start_ts=body.start_ts,
        end_ts=body.end_ts,
        status="PENDING_PAYMENT",
        amount=pricing["amount"],
        commission=pricing["commission"],
        host_payout=pricing["host_payout"],
        payout_status="PENDING",
        created_at=time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(now)),
        charger_title=charger["title"],
        charger_address=charger["address"],
        connector_type=charger["connector_type"],
        power_kw=charger["power_kw"],
        order_id=order_id,
        key_id=settings.razorpay_key_id or "rzp_test_chargebridge",
    )

@router.get("/mine", response_model=List[BookingOut])
def get_my_bookings(
    as_host: bool = Query(False),
    user: dict = Depends(current_user),
):
    with get_db() as db:
        if as_host:
            rows = db.execute("""
                SELECT b.*, c.title as charger_title, c.address as charger_address,
                       c.connector_type, c.power_kw, u.name as driver_name,
                       p.provider_ref as order_id
                FROM bookings b
                JOIN chargers c ON b.charger_id = c.id
                JOIN users u ON b.driver_id = u.id
                LEFT JOIN payments p ON p.booking_id = b.id
                WHERE c.host_id = ?
                ORDER BY b.start_ts DESC
            """, (user["id"],)).fetchall()
        else:
            rows = db.execute("""
                SELECT b.*, c.title as charger_title, c.address as charger_address,
                       c.connector_type, c.power_kw, u.name as driver_name,
                       p.provider_ref as order_id
                FROM bookings b
                JOIN chargers c ON b.charger_id = c.id
                JOIN users u ON b.driver_id = u.id
                LEFT JOIN payments p ON p.booking_id = b.id
                WHERE b.driver_id = ?
                ORDER BY b.start_ts DESC
            """, (user["id"],)).fetchall()

    return [
        BookingOut(
            id=r["id"],
            charger_id=r["charger_id"],
            driver_id=r["driver_id"],
            start_ts=r["start_ts"],
            end_ts=r["end_ts"],
            status=r["status"],
            amount=r["amount"],
            commission=r["commission"],
            host_payout=r["host_payout"],
            payout_status=r["payout_status"],
            created_at=r["created_at"],
            charger_title=r["charger_title"],
            charger_address=r["charger_address"],
            connector_type=r["connector_type"],
            power_kw=r["power_kw"],
            driver_name=r["driver_name"],
            order_id=r["order_id"],
            key_id=settings.razorpay_key_id or "rzp_test_chargebridge",
        ) for r in rows
    ]

@router.get("/{booking_id}", response_model=BookingOut)
def get_booking(booking_id: int, user: dict = Depends(current_user)):
    with get_db() as db:
        b = db.execute("""
            SELECT b.*, c.title as charger_title, c.address as charger_address,
                   c.connector_type, c.power_kw, c.host_id, u.name as driver_name,
                   p.provider_ref as order_id
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            JOIN users u ON b.driver_id = u.id
            LEFT JOIN payments p ON p.booking_id = b.id
            WHERE b.id = ?
        """, (booking_id,)).fetchone()

        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        # Ownership check
        if user["role"] != "admin" and b["driver_id"] != user["id"] and b["host_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Not authorized to view this booking")

        return BookingOut(
            id=b["id"],
            charger_id=b["charger_id"],
            driver_id=b["driver_id"],
            start_ts=b["start_ts"],
            end_ts=b["end_ts"],
            status=b["status"],
            amount=b["amount"],
            commission=b["commission"],
            host_payout=b["host_payout"],
            payout_status=b["payout_status"],
            created_at=b["created_at"],
            charger_title=b["charger_title"],
            charger_address=b["charger_address"],
            connector_type=b["connector_type"],
            power_kw=b["power_kw"],
            driver_name=b["driver_name"],
            order_id=b["order_id"],
            key_id=settings.razorpay_key_id or "rzp_test_chargebridge",
        )

@router.post("/{booking_id}/cancel", response_model=CancelBookingResponse)
def cancel_booking(booking_id: int, user: dict = Depends(current_user)):
    now = int(time.time())

    with get_db() as db:
        b = db.execute("""
            SELECT b.*, c.host_id
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            WHERE b.id = ?
        """, (booking_id,)).fetchone()

        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        is_driver = (b["driver_id"] == user["id"])
        is_host = (b["host_id"] == user["id"])
        is_admin = (user["role"] == "admin")

        if not (is_driver or is_host or is_admin):
            raise HTTPException(status_code=403, detail="Not authorized to cancel this booking")

        if b["status"] in ("CANCELLED", "COMPLETED", "EXPIRED"):
            raise HTTPException(status_code=400, detail=f"Booking is already {b['status']}")

        cancelled_by = "host" if is_host else "driver"
        refund_amount, refund_percent = calculate_refund(b["amount"], b["start_ts"], now, cancelled_by=cancelled_by)

        payment = db.execute("SELECT * FROM payments WHERE booking_id = ? AND status = 'PAID'", (booking_id,)).fetchone()
        if payment and refund_amount > 0:
            try:
                refund_payment(payment["payment_id"] or payment["provider_ref"], refund_amount)
                db.execute("UPDATE payments SET status = 'REFUNDED' WHERE id = ?", (payment["id"],))
            except Exception:
                pass

        db.execute("UPDATE bookings SET status = 'CANCELLED' WHERE id = ?", (booking_id,))
        record_audit(db, user["id"], "BOOKING_CANCELLED", f"Booking #{booking_id} cancelled by {cancelled_by}. Refund: {refund_percent}%", "")

    return CancelBookingResponse(
        status="CANCELLED",
        refund_amount=refund_amount,
        refund_percent=refund_percent,
        message=f"Booking cancelled successfully. {refund_percent}% refund (₹{refund_amount / 100:.2f}) processed.",
    )

@router.post("/{booking_id}/complete")
def complete_booking(booking_id: int, user: dict = Depends(current_user)):
    with get_db() as db:
        b = db.execute("""
            SELECT b.*, c.host_id
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            WHERE b.id = ?
        """, (booking_id,)).fetchone()

        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        if user["role"] != "admin" and b["host_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Only the host or admin can mark a session complete")

        if b["status"] not in ("CONFIRMED", "ACTIVE"):
            raise HTTPException(status_code=400, detail=f"Cannot complete a booking with status {b['status']}")

        db.execute("UPDATE bookings SET status = 'COMPLETED', payout_status = 'PENDING' WHERE id = ?", (booking_id,))
        record_audit(db, user["id"], "BOOKING_COMPLETED", f"Booking #{booking_id} marked COMPLETED", "")

    return {"message": "Session marked as completed. Host payout scheduled."}

