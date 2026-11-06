from typing import List
from fastapi import APIRouter, Depends
from ..db import get_db
from ..deps import current_user, require_role
from ..schemas import HostEarningsOut, BookingOut, ChargerOut
import json

router = APIRouter(prefix="/host", tags=["host"])

@router.get("/earnings", response_model=HostEarningsOut)
def get_host_earnings(user: dict = Depends(require_role("host", "admin"))):
    with get_db() as db:
        # Sum of completed payouts
        completed_stats = db.execute("""
            SELECT COALESCE(SUM(b.host_payout), 0) as total_earnings,
                   COUNT(b.id) as completed_sessions
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            WHERE c.host_id = ? AND b.status = 'COMPLETED'
        """, (user["id"],)).fetchone()

        # Sum of pending payouts
        pending_stats = db.execute("""
            SELECT COALESCE(SUM(b.host_payout), 0) as pending_payout
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            WHERE c.host_id = ? AND b.status = 'COMPLETED' AND b.payout_status = 'PENDING'
        """, (user["id"],)).fetchone()

        # Active chargers
        charger_stats = db.execute("""
            SELECT COUNT(id) as active_chargers
            FROM chargers
            WHERE host_id = ? AND is_active = 1
        """, (user["id"],)).fetchone()

        # Recent bookings
        recent = db.execute("""
            SELECT b.*, c.title as charger_title, c.address as charger_address,
                   c.connector_type, c.power_kw, u.name as driver_name,
                   p.provider_ref as order_id
            FROM bookings b
            JOIN chargers c ON b.charger_id = c.id
            JOIN users u ON b.driver_id = u.id
            LEFT JOIN payments p ON p.booking_id = b.id
            WHERE c.host_id = ?
            ORDER BY b.start_ts DESC
            LIMIT 10
        """, (user["id"],)).fetchall()

    recent_list = [
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
        ) for r in recent
    ]

    return HostEarningsOut(
        total_earnings=completed_stats["total_earnings"],
        pending_payout=pending_stats["pending_payout"],
        completed_sessions=completed_stats["completed_sessions"],
        active_chargers=charger_stats["active_chargers"],
        recent_bookings=recent_list,
    )

@router.get("/chargers", response_model=List[ChargerOut])
def get_my_chargers(user: dict = Depends(require_role("host", "admin"))):
    with get_db() as db:
        rows = db.execute("""
            SELECT c.*,
                   COALESCE(AVG(r.rating), 0.0) as avg_rating,
                   COUNT(r.id) as review_count
            FROM chargers c
            LEFT JOIN bookings b ON b.charger_id = c.id
            LEFT JOIN reviews r ON r.booking_id = b.id
            WHERE c.host_id = ?
            GROUP BY c.id
            ORDER BY c.created_at DESC
        """, (user["id"],)).fetchall()

    results = []
    for row in rows:
        photos_list = []
        try:
            photos_list = json.loads(row["photos"] or "[]")
        except Exception:
            pass

        results.append(
            ChargerOut(
                id=row["id"],
                host_id=row["host_id"],
                title=row["title"],
                description=row["description"],
                lat=row["lat"],
                lng=row["lng"],
                address=row["address"],
                connector_type=row["connector_type"],
                power_kw=row["power_kw"],
                price_per_kwh=row["price_per_kwh"],
                price_per_hour=row["price_per_hour"],
                photos=photos_list,
                is_active=bool(row["is_active"]),
                is_featured=bool(row["is_featured"]),
                created_at=row["created_at"],
                avg_rating=round(float(row["avg_rating"]), 1) if row["review_count"] > 0 else None,
                review_count=row["review_count"],
            )
        )
    return results

