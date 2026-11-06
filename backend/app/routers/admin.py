import os
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query

from ..config import settings
from ..db import get_db
from ..deps import require_role, record_audit
from ..schemas import AdminStats, UserOut, BookingOut

router = APIRouter(prefix="/admin", tags=["admin"])

@router.get("/stats", response_model=AdminStats)
def get_stats(user: dict = Depends(require_role("admin"))):
    with get_db() as db:
        user_cnt = db.execute("SELECT COUNT(id) FROM users").fetchone()[0]
        charger_cnt = db.execute("SELECT COUNT(id) FROM chargers").fetchone()[0]
        booking_cnt = db.execute("SELECT COUNT(id) FROM bookings").fetchone()[0]
        revenue_sum = db.execute("SELECT COALESCE(SUM(commission), 0) FROM bookings WHERE status IN ('CONFIRMED','COMPLETED')").fetchone()[0]
        pending_payouts = db.execute("SELECT COUNT(id), COALESCE(SUM(host_payout), 0) FROM bookings WHERE status = 'COMPLETED' AND payout_status = 'PENDING'").fetchone()

    db_size = 0
    if os.path.exists(settings.db_path):
        db_size = os.path.getsize(settings.db_path)

    return AdminStats(
        total_users=user_cnt,
        total_chargers=charger_cnt,
        total_bookings=booking_cnt,
        total_revenue=revenue_sum,
        pending_payouts_count=pending_payouts[0],
        pending_payouts_amount=pending_payouts[1],
        db_size_bytes=db_size,
    )

@router.get("/users", response_model=List[UserOut])
def list_users(limit: int = 50, offset: int = 0, user: dict = Depends(require_role("admin"))):
    with get_db() as db:
        rows = db.execute("SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?", (limit, offset)).fetchall()

    return [
        UserOut(
            id=r["id"],
            name=r["name"],
            email=r["email"],
            role=r["role"],
            phone=r["phone"],
            is_verified=bool(r["is_verified"]),
            created_at=r["created_at"],
        ) for r in rows
    ]

@router.get("/bookings", response_model=List[BookingOut])
def list_all_bookings(status: Optional[str] = None, limit: int = 50, user: dict = Depends(require_role("admin"))):
    with get_db() as db:
        query = """
            SELECT b.*, c.title as charger_title, c.address as charger_address,
                   c.connector_type, c.power_kw, u.name as driver_name,
                   p.provider_ref as order_id
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            JOIN users u ON b.driver_id = u.id
            LEFT JOIN payments p ON p.booking_id = b.id
        """
        params = []
        if status:
            query += " WHERE b.status = ?"
            params.append(status)
        query += " ORDER BY b.created_at DESC LIMIT ?"
        params.append(limit)

        rows = db.execute(query, params).fetchall()

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
        ) for r in rows
    ]

@router.post("/payouts/{booking_id}/mark-paid")
def mark_payout_paid(booking_id: int, user: dict = Depends(require_role("admin"))):
    with get_db() as db:
        b = db.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        db.execute("UPDATE bookings SET payout_status = 'PAID' WHERE id = ?", (booking_id,))
        record_audit(db, user["id"], "PAYOUT_PAID", f"Marked host payout for booking #{booking_id} as PAID", "")

    return {"message": f"Payout for booking #{booking_id} marked as PAID"}

