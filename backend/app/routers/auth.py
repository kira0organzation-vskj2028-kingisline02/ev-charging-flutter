import time
import hashlib
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..config import settings
from ..db import get_db
from ..deps import current_user, record_audit
from ..security import (
    hash_password,
    verify_password,
    make_access_token,
    new_refresh_token,
    hash_otp,
    generate_otp_code,
)
from ..services.email import send_otp_email
from ..schemas import (
    RegisterIn,
    VerifyOtpIn,
    ResendOtpIn,
    LoginIn,
    RefreshIn,
    TokenResponse,
    UserOut,
    FcmTokenIn,
)

router = APIRouter(prefix="/auth", tags=["auth"])
limiter = Limiter(key_func=get_remote_address)

@router.post("/register", status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register(request: Request, body: RegisterIn):
    ip = request.client.host if request.client else ""
    with get_db() as db:
        existing = db.execute("SELECT id, is_verified FROM users WHERE email = ?", (body.email.lower(),)).fetchone()
        hashed_pw = hash_password(body.password)

        if existing:
            if existing["is_verified"]:
                raise HTTPException(status_code=400, detail="Email is already registered. Please log in.")
            # Unverified account exists: update details and generate fresh OTP
            db.execute(
                """UPDATE users SET name = ?, phone = ?, role = ?, password_hash = ?
                   WHERE id = ?""",
                (body.name, body.phone, body.role, hashed_pw, existing["id"]),
            )
            user_id = existing["id"]
        else:
            cur = db.execute(
                """INSERT INTO users (name, email, phone, role, password_hash, is_verified)
                   VALUES (?, ?, ?, ?, ?, 0)""",
                (body.name, body.email.lower(), body.phone, body.role, hashed_pw),
            )
            user_id = cur.lastrowid

        code = generate_otp_code()
        code_h = hash_otp(code)
        expires_at = int(time.time()) + 600  # 10 minutes

        # Clear any existing OTPs for this email
        db.execute("DELETE FROM email_otps WHERE email = ?", (body.email.lower(),))
        db.execute(
            "INSERT INTO email_otps (email, code_hash, expires_at, attempts) VALUES (?, ?, ?, 0)",
            (body.email.lower(), code_h, expires_at),
        )

        send_otp_email(body.email.lower(), code)
        record_audit(db, user_id, "REGISTER", f"Registered as {body.role}", ip)

    return {"message": "Account created. Verification code sent to email.", "email": body.email.lower()}

@router.post("/resend-otp")
@limiter.limit("3/minute")
def resend_otp(request: Request, body: ResendOtpIn):
    email = body.email.lower()
    with get_db() as db:
        user = db.execute("SELECT id, is_verified FROM users WHERE email = ?", (email,)).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        if user["is_verified"]:
            return {"message": "Email is already verified. Please log in."}

        code = generate_otp_code()
        code_h = hash_otp(code)
        expires_at = int(time.time()) + 600

        db.execute("DELETE FROM email_otps WHERE email = ?", (email,))
        db.execute(
            "INSERT INTO email_otps (email, code_hash, expires_at, attempts) VALUES (?, ?, ?, 0)",
            (email, code_h, expires_at),
        )
        send_otp_email(email, code)
    return {"message": "New verification code sent."}

@router.post("/verify-otp")
@limiter.limit("10/minute")
def verify_otp(request: Request, body: VerifyOtpIn):
    ip = request.client.host if request.client else ""
    email = body.email.lower()
    now = int(time.time())

    with get_db() as db:
        otp_row = db.execute(
            "SELECT code_hash, expires_at, attempts FROM email_otps WHERE email = ?",
            (email,)
        ).fetchone()

        if not otp_row:
            raise HTTPException(status_code=400, detail="No verification request found for this email")

        if otp_row["attempts"] >= 5:
            db.execute("DELETE FROM email_otps WHERE email = ?", (email,))
            raise HTTPException(status_code=400, detail="Too many failed attempts. Please register or request a new code.")

        if now > otp_row["expires_at"]:
            db.execute("DELETE FROM email_otps WHERE email = ?", (email,))
            raise HTTPException(status_code=400, detail="Verification code has expired")

        code_h = hash_otp(body.code)
        if code_h != otp_row["code_hash"]:
            db.execute("UPDATE email_otps SET attempts = attempts + 1 WHERE email = ?", (email,))
            raise HTTPException(status_code=400, detail="Incorrect verification code")

        # Mark user as verified
        db.execute("UPDATE users SET is_verified = 1 WHERE email = ?", (email,))
        db.execute("DELETE FROM email_otps WHERE email = ?", (email,))

        user_row = db.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        user_id = user_row["id"] if user_row else None
        record_audit(db, user_id, "VERIFY_OTP_SUCCESS", "Email verified", ip)

    return {"message": "Email verified successfully. You can now log in."}

@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
def login(request: Request, body: LoginIn):
    ip = request.client.host if request.client else ""
    email = body.email.lower()

    with get_db() as db:
        user = db.execute(
            "SELECT * FROM users WHERE email = ?", (email,)
        ).fetchone()

        if not user or not verify_password(user["password_hash"], body.password):
            record_audit(db, None, "LOGIN_FAILED", f"Failed login attempt for {email}", ip)
            raise HTTPException(status_code=401, detail="Invalid email or password")

        if not user["is_verified"]:
            raise HTTPException(status_code=403, detail="Email is not verified. Please verify your email first.")

        access_token = make_access_token(user["id"], user["role"])
        raw_refresh, refresh_hash = new_refresh_token()
        refresh_expires = int(time.time()) + (settings.refresh_token_days * 86400)

        db.execute(
            "INSERT INTO refresh_tokens (user_id, token_hash, expires_at, revoked) VALUES (?, ?, ?, 0)",
            (user["id"], refresh_hash, refresh_expires),
        )
        record_audit(db, user["id"], "LOGIN_SUCCESS", "Logged in", ip)

        user_out = UserOut(
            id=user["id"],
            name=user["name"],
            email=user["email"],
            role=user["role"],
            phone=user["phone"],
            is_verified=bool(user["is_verified"]),
            created_at=user["created_at"],
        )

        return TokenResponse(
            access_token=access_token,
            refresh_token=raw_refresh,
            token_type="bearer",
            user=user_out,
        )

@router.post("/refresh", response_model=TokenResponse)
def refresh_token(body: RefreshIn):
    token_hash = hashlib.sha256(body.refresh_token.encode("utf-8")).hexdigest()
    now = int(time.time())

    with get_db() as db:
        token_row = db.execute(
            "SELECT * FROM refresh_tokens WHERE token_hash = ? AND revoked = 0",
            (token_hash,)
        ).fetchone()

        if not token_row or now > token_row["expires_at"]:
            raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

        # Token rotation: revoke old token
        db.execute("UPDATE refresh_tokens SET revoked = 1 WHERE id = ?", (token_row["id"],))

        user = db.execute("SELECT * FROM users WHERE id = ?", (token_row["user_id"],)).fetchone()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        # Issue new pair
        access_token = make_access_token(user["id"], user["role"])
        new_raw_refresh, new_hash = new_refresh_token()
        refresh_expires = now + (settings.refresh_token_days * 86400)

        db.execute(
            "INSERT INTO refresh_tokens (user_id, token_hash, expires_at, revoked) VALUES (?, ?, ?, 0)",
            (user["id"], new_hash, refresh_expires),
        )

        user_out = UserOut(
            id=user["id"],
            name=user["name"],
            email=user["email"],
            role=user["role"],
            phone=user["phone"],
            is_verified=bool(user["is_verified"]),
            created_at=user["created_at"],
        )

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_raw_refresh,
            token_type="bearer",
            user=user_out,
        )

@router.post("/logout")
def logout(user: dict = Depends(current_user)):
    with get_db() as db:
        db.execute("UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?", (user["id"],))
    return {"message": "Logged out successfully"}

@router.get("/me", response_model=UserOut)
def get_me(user: dict = Depends(current_user)):
    with get_db() as db:
        u = db.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
        if not u:
            raise HTTPException(status_code=404, detail="User not found")
        return UserOut(
            id=u["id"],
            name=u["name"],
            email=u["email"],
            role=u["role"],
            phone=u["phone"],
            is_verified=bool(u["is_verified"]),
            created_at=u["created_at"],
        )

@router.put("/fcm-token")
def update_fcm_token(body: FcmTokenIn, user: dict = Depends(current_user)):
    with get_db() as db:
        db.execute("UPDATE users SET fcm_token = ? WHERE id = ?", (body.token, user["id"]))
    return {"message": "FCM token updated"}

