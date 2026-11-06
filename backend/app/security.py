import hashlib
import secrets
import time
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from .config import settings

ph = PasswordHasher()

def hash_password(p: str) -> str:
    return ph.hash(p)

def verify_password(hashed: str, p: str) -> bool:
    try:
        return ph.verify(hashed, p)
    except (VerifyMismatchError, Exception):
        return False

def make_access_token(user_id: int, role: str) -> str:
    now = int(time.time())
    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": now,
        "exp": now + settings.access_token_minutes * 60,
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])

def new_refresh_token() -> tuple[str, str]:
    raw = secrets.token_urlsafe(48)
    return raw, hashlib.sha256(raw.encode("utf-8")).hexdigest()

def hash_otp(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()

def generate_otp_code() -> str:
    return f"{secrets.randbelow(900000) + 100000:06d}"

