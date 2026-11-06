from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from ..db import get_db
from ..deps import current_user
from ..schemas import ReviewCreate, ReviewOut

router = APIRouter(prefix="/reviews", tags=["reviews"])

@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
def create_review(body: ReviewCreate, user: dict = Depends(current_user)):
    with get_db() as db:
        booking = db.execute("SELECT * FROM bookings WHERE id = ?", (body.booking_id,)).fetchone()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        if booking["driver_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Only the driver who booked the session can submit a review")

        if booking["status"] != "COMPLETED":
            raise HTTPException(status_code=400, detail="Reviews can only be submitted after the charging session is completed")

        existing_review = db.execute("SELECT id FROM reviews WHERE booking_id = ?", (body.booking_id,)).fetchone()
        if existing_review:
            raise HTTPException(status_code=400, detail="A review has already been submitted for this booking")

        cur = db.execute(
            "INSERT INTO reviews (booking_id, rating, comment) VALUES (?, ?, ?)",
            (body.booking_id, body.rating, body.comment)
        )
        review_id = cur.lastrowid
        review = db.execute("SELECT * FROM reviews WHERE id = ?", (review_id,)).fetchone()
        user_info = db.execute("SELECT name FROM users WHERE id = ?", (user["id"],)).fetchone()

    return ReviewOut(
        id=review["id"],
        booking_id=review["booking_id"],
        rating=review["rating"],
        comment=review["comment"],
        created_at=review["created_at"],
        reviewer_name=user_info["name"] if user_info else "Driver",
    )

@router.get("/charger/{charger_id}", response_model=List[ReviewOut])
def get_charger_reviews(charger_id: int):
    with get_db() as db:
        rows = db.execute("""
            SELECT r.*, u.name as reviewer_name
            FROM reviews r
            JOIN bookings b ON r.booking_id = b.id
            JOIN users u ON b.driver_id = u.id
            WHERE b.charger_id = ?
            ORDER BY r.created_at DESC
        """, (charger_id,)).fetchall()

    return [
        ReviewOut(
            id=r["id"],
            booking_id=r["booking_id"],
            rating=r["rating"],
            comment=r["comment"],
            created_at=r["created_at"],
            reviewer_name=r["reviewer_name"],
        ) for r in rows
    ]

