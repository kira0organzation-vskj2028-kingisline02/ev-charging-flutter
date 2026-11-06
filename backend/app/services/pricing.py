from ..config import settings

def calculate(price_per_hour: float, start_ts: int, end_ts: int) -> dict:
    if end_ts <= start_ts:
        raise ValueError("end_ts must be greater than start_ts")
    hours = (end_ts - start_ts) / 3600.0
    amount = int(round(price_per_hour * hours * 100))  # paise
    commission = int(round(amount * settings.commission_percent / 100))
    host_payout = amount - commission
    return {
        "amount": amount,
        "commission": commission,
        "host_payout": host_payout,
        "hours": round(hours, 2),
    }

def calculate_refund(amount: int, start_ts: int, current_ts: int, cancelled_by: str = "driver") -> tuple[int, int]:
    """
    Returns (refund_amount_in_paise, refund_percentage)
    Rules:
    - Cancelled by host: 100%
    - More than 2 hours before start (diff > 7200s): 100%
    - Between 30 minutes and 2 hours before start (1800s <= diff <= 7200s): 50%
    - Less than 30 minutes before start (diff < 1800s): 0%
    """
    if cancelled_by == "host":
        return amount, 100
    
    diff_seconds = start_ts - current_ts
    if diff_seconds > 7200:
        return amount, 100
    elif diff_seconds >= 1800:
        refund_amount = int(round(amount * 0.50))
        return refund_amount, 50
    else:
        return 0, 0

