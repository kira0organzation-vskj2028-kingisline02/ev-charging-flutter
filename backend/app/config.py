import os
from pydantic_settings import BaseSettings, SettingsConfigDict

_backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_default_db = os.path.join(_backend_dir, "chargebridge.db")

class Settings(BaseSettings):
    app_env: str = "development"
    db_path: str = _default_db
    jwt_secret: str = "super-secret-chargebridge-jwt-key-for-development-32bytes-min"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    commission_percent: int = 12
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""
    gemini_api_key: str = ""
    sentry_dsn: str = ""
    smtp_host: str = ""
    smtp_user: str = ""
    smtp_password: str = ""
    cors_origins: str = "*"
    upload_dir: str = "./uploads"

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"),
        extra="ignore"
    )

settings = Settings()

