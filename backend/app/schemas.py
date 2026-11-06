from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List

# --- Auth Schemas ---
class RegisterIn(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8)
    role: str = Field("driver", pattern="^(driver|host|admin)$")
    phone: Optional[str] = None

class VerifyOtpIn(BaseModel):
    email: EmailStr
    code: str = Field(..., min_length=6, max_length=6)

class ResendOtpIn(BaseModel):
    email: EmailStr

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class RefreshIn(BaseModel):
    refresh_token: str

class UserOut(BaseModel):
    id: int
    name: str
    email: str
    role: str
    phone: Optional[str] = None
    is_verified: bool
    created_at: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut

class FcmTokenIn(BaseModel):
    token: str

# --- Charger Schemas ---
class AvailabilitySlot(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6)
    start_time: str = Field(..., pattern=r"^\d{2}:\d{2}$")
    end_time: str = Field(..., pattern=r"^\d{2}:\d{2}$")

class ChargerCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    description: Optional[str] = None
    lat: float = Field(..., ge=-90.0, le=90.0)
    lng: float = Field(..., ge=-180.0, le=180.0)
    address: str = Field(..., min_length=5)
    connector_type: str = Field(..., pattern="^(CCS2|Type2|CHAdeMO|GB/T|3-pin)$")
    power_kw: float = Field(..., gt=0)
    price_per_kwh: float = Field(..., ge=0)
    price_per_hour: Optional[float] = Field(None, ge=0)
    availability: List[AvailabilitySlot] = []

class ChargerUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    address: Optional[str] = None
    connector_type: Optional[str] = None
    power_kw: Optional[float] = None
    price_per_kwh: Optional[float] = None
    price_per_hour: Optional[float] = None
    is_active: Optional[int] = None
    is_featured: Optional[int] = None

class ChargerOut(BaseModel):
    id: int
    host_id: int
    title: str
    description: Optional[str] = None
    lat: float
    lng: float
    address: str
    connector_type: str
    power_kw: float
    price_per_kwh: float
    price_per_hour: Optional[float] = None
    photos: List[str] = []
    is_active: bool
    is_featured: bool
    created_at: str
    distance_km: Optional[float] = None
    avg_rating: Optional[float] = None
    review_count: Optional[int] = 0

# --- Review Schemas ---
class ReviewCreate(BaseModel):
    booking_id: int
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class ReviewOut(BaseModel):
    id: int
    booking_id: int
    rating: int
    comment: Optional[str] = None
    created_at: str
    reviewer_name: Optional[str] = None

class ChargerDetailOut(ChargerOut):
    host_name: Optional[str] = None
    host_email: Optional[str] = None
    availability: List[AvailabilitySlot] = []
    reviews: List[ReviewOut] = []

# --- Booking Schemas ---
class BookingPricePreviewIn(BaseModel):
    charger_id: int
    start_ts: int
    end_ts: int

class BookingPricePreviewOut(BaseModel):
    amount: int  # in paise
    commission: int  # in paise
    host_payout: int  # in paise
    hours: float

class BookingCreate(BaseModel):
    charger_id: int
    start_ts: int
    end_ts: int

class BookingOut(BaseModel):
    id: int
    charger_id: int
    driver_id: int
    start_ts: int
    end_ts: int
    status: str
    amount: int  # paise
    commission: int  # paise
    host_payout: int  # paise
    payout_status: str
    created_at: str
    charger_title: Optional[str] = None
    charger_address: Optional[str] = None
    connector_type: Optional[str] = None
    power_kw: Optional[float] = None
    driver_name: Optional[str] = None
    order_id: Optional[str] = None
    key_id: Optional[str] = None

class CancelBookingResponse(BaseModel):
    status: str
    refund_amount: int
    refund_percent: int
    message: str

# --- AI Schemas ---
class AiListingIn(BaseModel):
    location: str
    connector_type: str
    power_kw: float
    amenities: List[str] = []

class AiListingOut(BaseModel):
    description: str
    suggested_price_min: float
    suggested_price_max: float

# --- Host Schemas ---
class HostEarningsOut(BaseModel):
    total_earnings: int  # paise
    pending_payout: int  # paise
    completed_sessions: int
    active_chargers: int
    recent_bookings: List[BookingOut] = []

# --- Admin Schemas ---
class AdminStats(BaseModel):
    total_users: int
    total_chargers: int
    total_bookings: int
    total_revenue: int
    pending_payouts_count: int
    pending_payouts_amount: int
    db_size_bytes: int

