import os
import json
import uuid
import io
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from cachetools import TTLCache
from PIL import Image

from ..config import settings
from ..db import get_db
from ..deps import current_user, require_role
from ..services.geo import bounding_box, haversine_km
from ..schemas import (
    ChargerCreate,
    ChargerUpdate,
    ChargerOut,
    ChargerDetailOut,
    AvailabilitySlot,
    ReviewOut,
)

router = APIRouter(prefix="/chargers", tags=["chargers"])

search_cache = TTLCache(maxsize=1000, ttl=45)

def clear_search_cache():
    search_cache.clear()

@router.get("", response_model=List[ChargerOut])
def search_chargers(
    lat: float = Query(28.6139, ge=-90, le=90),
    lng: float = Query(77.2090, ge=-180, le=180),
    radius_km: float = Query(50.0, gt=0, le=500),
    connector_type: Optional[str] = Query(None),
    min_power_kw: Optional[float] = Query(None, ge=0),
):
    cache_key = (round(lat, 3), round(lng, 3), round(radius_km, 1), connector_type, min_power_kw)
    if cache_key in search_cache:
        return search_cache[cache_key]

    min_lat, max_lat, min_lng, max_lng = bounding_box(lat, lng, radius_km)

    query = """
        SELECT c.*,
               COALESCE(AVG(r.rating), 0.0) as avg_rating,
               COUNT(r.id) as review_count
        FROM chargers c
        LEFT JOIN bookings b ON b.charger_id = c.id
        LEFT JOIN reviews r ON r.booking_id = b.id
        WHERE c.is_active = 1
          AND c.lat BETWEEN ? AND ?
          AND c.lng BETWEEN ? AND ?
    """
    params = [min_lat, max_lat, min_lng, max_lng]

    if connector_type:
        query += " AND c.connector_type = ?"
        params.append(connector_type)

    if min_power_kw is not None:
        query += " AND c.power_kw >= ?"
        params.append(min_power_kw)

    query += " GROUP BY c.id"

    with get_db() as db:
        rows = db.execute(query, params).fetchall()

    results = []
    for row in rows:
        dist = haversine_km(lat, lng, row["lat"], row["lng"])
        if dist <= radius_km:
            photos_list = []
            try:
                photos_list = json.loads(row["photos"] or "[]")
            except Exception:
                photos_list = []

            price_per_hour = row["price_per_hour"]
            if price_per_hour is None:
                price_per_hour = round(row["price_per_kwh"] * min(row["power_kw"], 7.4), 2)

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
                    price_per_hour=price_per_hour,
                    photos=photos_list,
                    is_active=bool(row["is_active"]),
                    is_featured=bool(row["is_featured"]),
                    created_at=row["created_at"],
                    distance_km=round(dist, 2),
                    avg_rating=round(float(row["avg_rating"]), 1) if row["review_count"] > 0 else None,
                    review_count=row["review_count"],
                )
            )

    # Sort featured first, then by closest distance
    results.sort(key=lambda x: (not x.is_featured, x.distance_km if x.distance_km is not None else 99999))
    search_cache[cache_key] = results
    return results

@router.get("/{charger_id}", response_model=ChargerDetailOut)
def get_charger_detail(charger_id: int):
    with get_db() as db:
        row = db.execute("""
            SELECT c.*, u.name as host_name, u.email as host_email,
                   COALESCE(AVG(r.rating), 0.0) as avg_rating,
                   COUNT(r.id) as review_count
            FROM chargers c
            JOIN users u ON c.host_id = u.id
            LEFT JOIN bookings b ON b.charger_id = c.id
            LEFT JOIN reviews r ON r.booking_id = b.id
            WHERE c.id = ?
            GROUP BY c.id
        """, (charger_id,)).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Charger not found")

        # Availability
        avail_rows = db.execute(
            "SELECT day_of_week, start_time, end_time FROM availability WHERE charger_id = ? ORDER BY day_of_week, start_time",
            (charger_id,)
        ).fetchall()
        availability = [
            AvailabilitySlot(
                day_of_week=a["day_of_week"],
                start_time=a["start_time"],
                end_time=a["end_time"],
            ) for a in avail_rows
        ]

        # Reviews
        review_rows = db.execute("""
            SELECT r.id, r.booking_id, r.rating, r.comment, r.created_at, u.name as reviewer_name
            FROM reviews r
            JOIN bookings b ON r.booking_id = b.id
            JOIN users u ON b.driver_id = u.id
            WHERE b.charger_id = ?
            ORDER BY r.created_at DESC
            LIMIT 20
        """, (charger_id,)).fetchall()

        reviews = [
            ReviewOut(
                id=rv["id"],
                booking_id=rv["booking_id"],
                rating=rv["rating"],
                comment=rv["comment"],
                created_at=rv["created_at"],
                reviewer_name=rv["reviewer_name"],
            ) for rv in review_rows
        ]

        photos_list = []
        try:
            photos_list = json.loads(row["photos"] or "[]")
        except Exception:
            photos_list = []

        price_per_hour = row["price_per_hour"]
        if price_per_hour is None:
            price_per_hour = round(row["price_per_kwh"] * min(row["power_kw"], 7.4), 2)

        return ChargerDetailOut(
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
            price_per_hour=price_per_hour,
            photos=photos_list,
            is_active=bool(row["is_active"]),
            is_featured=bool(row["is_featured"]),
            created_at=row["created_at"],
            avg_rating=round(float(row["avg_rating"]), 1) if row["review_count"] > 0 else None,
            review_count=row["review_count"],
            host_name=row["host_name"],
            host_email=row["host_email"],
            availability=availability,
            reviews=reviews,
        )

@router.post("", response_model=ChargerOut, status_code=status.HTTP_201_CREATED)
def create_charger(body: ChargerCreate, user: dict = Depends(require_role("host", "admin"))):
    price_per_hour = body.price_per_hour
    if price_per_hour is None:
        price_per_hour = round(body.price_per_kwh * min(body.power_kw, 7.4), 2)

    with get_db() as db:
        cur = db.execute("""
            INSERT INTO chargers (host_id, title, description, lat, lng, address, connector_type, power_kw, price_per_kwh, price_per_hour, photos, is_active, is_featured)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '[]', 1, 0)
        """, (
            user["id"], body.title, body.description, body.lat, body.lng,
            body.address, body.connector_type, body.power_kw,
            body.price_per_kwh, price_per_hour
        ))
        charger_id = cur.lastrowid

        # Insert availability slots if provided
        for slot in body.availability:
            db.execute("""
                INSERT INTO availability (charger_id, day_of_week, start_time, end_time)
                VALUES (?, ?, ?, ?)
            """, (charger_id, slot.day_of_week, slot.start_time, slot.end_time))

        charger = db.execute("SELECT * FROM chargers WHERE id = ?", (charger_id,)).fetchone()

    clear_search_cache()
    return ChargerOut(
        id=charger["id"],
        host_id=charger["host_id"],
        title=charger["title"],
        description=charger["description"],
        lat=charger["lat"],
        lng=charger["lng"],
        address=charger["address"],
        connector_type=charger["connector_type"],
        power_kw=charger["power_kw"],
        price_per_kwh=charger["price_per_kwh"],
        price_per_hour=charger["price_per_hour"],
        photos=[],
        is_active=bool(charger["is_active"]),
        is_featured=bool(charger["is_featured"]),
        created_at=charger["created_at"],
        distance_km=None,
        avg_rating=None,
        review_count=0,
    )

@router.put("/{charger_id}", response_model=ChargerOut)
def update_charger(charger_id: int, body: ChargerUpdate, user: dict = Depends(require_role("host", "admin"))):
    with get_db() as db:
        existing = db.execute("SELECT * FROM chargers WHERE id = ?", (charger_id,)).fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Charger not found")

        # Ownership check
        if user["role"] != "admin" and existing["host_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="You do not own this charger")

        updates = []
        params = []
        for field, val in body.model_dump(exclude_unset=True).items():
            updates.append(f"{field} = ?")
            params.append(val)

        if updates:
            params.append(charger_id)
            db.execute(f"UPDATE chargers SET {', '.join(updates)} WHERE id = ?", params)

        updated = db.execute("SELECT * FROM chargers WHERE id = ?", (charger_id,)).fetchone()

    clear_search_cache()
    photos = []
    try:
        photos = json.loads(updated["photos"] or "[]")
    except Exception:
        pass

    return ChargerOut(
        id=updated["id"],
        host_id=updated["host_id"],
        title=updated["title"],
        description=updated["description"],
        lat=updated["lat"],
        lng=updated["lng"],
        address=updated["address"],
        connector_type=updated["connector_type"],
        power_kw=updated["power_kw"],
        price_per_kwh=updated["price_per_kwh"],
        price_per_hour=updated["price_per_hour"],
        photos=photos,
        is_active=bool(updated["is_active"]),
        is_featured=bool(updated["is_featured"]),
        created_at=updated["created_at"],
    )

@router.post("/{charger_id}/photos")
async def upload_charger_photo(
    charger_id: int,
    file: UploadFile = File(...),
    user: dict = Depends(require_role("host", "admin")),
):
    with get_db() as db:
        existing = db.execute("SELECT * FROM chargers WHERE id = ?", (charger_id,)).fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Charger not found")
        if user["role"] != "admin" and existing["host_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="You do not own this charger")

    # Validate file size (< 5MB)
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image exceeds 5MB limit")

    # Validate image format and re-encode with Pillow
    try:
        image = Image.open(io.BytesIO(content))
        image.verify()
        # Re-open for actual processing
        image = Image.open(io.BytesIO(content))
        if image.format not in ("JPEG", "PNG", "WEBP"):
            raise HTTPException(status_code=400, detail="Only JPEG, PNG, and WEBP formats supported")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")

    os.makedirs(settings.upload_dir, exist_ok=True)
    filename = f"charger_{charger_id}_{uuid.uuid4().hex[:10]}.webp"
    file_path = os.path.join(settings.upload_dir, filename)

    # Save as WebP
    image.convert("RGB").save(file_path, "WEBP", quality=85)
    relative_url = f"/uploads/{filename}"

    with get_db() as db:
        row = db.execute("SELECT photos FROM chargers WHERE id = ?", (charger_id,)).fetchone()
        photos = json.loads(row["photos"] or "[]")
        photos.append(relative_url)
        db.execute("UPDATE chargers SET photos = ? WHERE id = ?", (json.dumps(photos), charger_id))

    clear_search_cache()
    return {"url": relative_url, "photos": photos}

@router.put("/{charger_id}/availability")
def set_availability(
    charger_id: int,
    slots: List[AvailabilitySlot],
    user: dict = Depends(require_role("host", "admin")),
):
    with get_db() as db:
        existing = db.execute("SELECT * FROM chargers WHERE id = ?", (charger_id,)).fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail="Charger not found")
        if user["role"] != "admin" and existing["host_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="You do not own this charger")

        db.execute("DELETE FROM availability WHERE charger_id = ?", (charger_id,))
        for s in slots:
            db.execute(
                "INSERT INTO availability (charger_id, day_of_week, start_time, end_time) VALUES (?, ?, ?, ?)",
                (charger_id, s.day_of_week, s.start_time, s.end_time)
            )

    return {"message": "Availability schedule updated", "slots_count": len(slots)}

