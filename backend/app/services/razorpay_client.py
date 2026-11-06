import hmac
import hashlib
import uuid
from loguru import logger
from ..config import settings

try:
    import razorpay
except ImportError:
    razorpay = None

def get_client():
    if (
        razorpay
        and settings.razorpay_key_id
        and settings.razorpay_key_secret
        and not settings.razorpay_key_id.startswith("rzp_test_chargebridge")
        and settings.app_env != "test"
    ):
        return razorpay.Client(auth=(settings.razorpay_key_id, settings.razorpay_key_secret))
    return None

def create_order(amount: int, receipt: str) -> dict:
    client = get_client()
    if client:
        try:
            return client.order.create({
                "amount": amount,
                "currency": "INR",
                "receipt": receipt,
            })
        except Exception as e:
            logger.warning(f"Razorpay API error creating order ({e}); using mock fallback.")
    # Mock order for testing / development without active Razorpay account
    mock_order_id = f"order_mock_{uuid.uuid4().hex[:14]}"
    logger.info(f"Using mock Razorpay order: {mock_order_id} for amount ₹{amount / 100:.2f}")
    return {
        "id": mock_order_id,
        "amount": amount,
        "currency": "INR",
        "receipt": receipt,
        "status": "created",
    }

def verify_webhook_signature(body: bytes, signature: str) -> bool:
    if not settings.razorpay_webhook_secret:
        # Development fallback
        return True
    expected = hmac.new(
        settings.razorpay_webhook_secret.encode("utf-8"),
        body,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

def refund_payment(payment_id: str, amount_paise: int) -> dict:
    client = get_client()
    if client:
        try:
            return client.payment.refund(payment_id, {"amount": amount_paise})
        except Exception as e:
            logger.error(f"Razorpay refund error: {e}")
            raise
    mock_refund_id = f"rfnd_mock_{uuid.uuid4().hex[:14]}"
    logger.info(f"Mock refund {mock_refund_id} for payment {payment_id}: ₹{amount_paise / 100:.2f}")
    return {
        "id": mock_refund_id,
        "payment_id": payment_id,
        "amount": amount_paise,
        "status": "processed",
    }
