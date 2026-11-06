import pytest
from app.services.pricing import calculate, calculate_refund

def test_commission_split():
    # 1 hour at 100/hr -> 10000 paise
    # 12% commission -> 1200 paise, 8800 host payout
    p = calculate(100.0, 0, 3600)
    assert p["amount"] == 10000
    assert p["commission"] == 1200
    assert p["host_payout"] == 8800
    assert p["amount"] == p["commission"] + p["host_payout"]
    assert p["hours"] == 1.0

def test_fractional_hours():
    # 2.5 hours at 150/hr -> 375.0 INR -> 37500 paise
    p = calculate(150.0, 0, 9000)
    assert p["amount"] == 37500
    assert p["commission"] + p["host_payout"] == p["amount"]
    assert p["hours"] == 2.5

def test_refund_rules():
    amount = 10000
    start = 10000

    # More than 2 hours before start (diff > 7200s): 100% refund
    ref_amt, pct = calculate_refund(amount, start, start - 7500, "driver")
    assert pct == 100
    assert ref_amt == 10000

    # Between 30 mins and 2 hours before start: 50% refund
    ref_amt, pct = calculate_refund(amount, start, start - 3600, "driver")
    assert pct == 50
    assert ref_amt == 5000

    # Less than 30 mins before start: 0% refund
    ref_amt, pct = calculate_refund(amount, start, start - 1000, "driver")
    assert pct == 0
    assert ref_amt == 0

    # Cancelled by host: Always 100%
    ref_amt, pct = calculate_refund(amount, start, start - 100, "host")
    assert pct == 100
    assert ref_amt == 10000

