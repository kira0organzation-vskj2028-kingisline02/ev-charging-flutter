from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from .security import decode_token
from .db import get_db

bearer = HTTPBearer(auto_error=True)
optional_bearer = HTTPBearer(auto_error=False)

def get_db_conn():
    with get_db() as conn:
        yield conn

def current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    try:
        data = decode_token(creds.credentials)
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if data.get("type") != "access":
        raise HTTPException(status_code=401, detail="Wrong token type")
    return {"id": int(data["sub"]), "role": data["role"]}

def optional_user(creds: HTTPAuthorizationCredentials | None = Depends(optional_bearer)) -> dict | None:
    if not creds:
        return None
    try:
        data = decode_token(creds.credentials)
        if data.get("type") == "access":
            return {"id": int(data["sub"]), "role": data["role"]}
    except Exception:
        pass
    return None

def require_role(*roles: str):
    def checker(user: dict = Depends(current_user)):
        if user["role"] not in roles and "admin" != user["role"]:
            raise HTTPException(status_code=403, detail="Not allowed for your role")
        return user
    return checker

def record_audit(db, user_id: int | None, action: str, detail: str = "", ip: str = ""):
    try:
        db.execute(
            "INSERT INTO audit_logs (user_id, action, detail, ip) VALUES (?, ?, ?, ?)",
            (user_id, action, detail, ip)
        )
    except Exception:
        pass

