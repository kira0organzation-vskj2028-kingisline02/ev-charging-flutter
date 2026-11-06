from app.db import get_db

def test_registration_and_otp(client):
    email = "newuser@example.com"
    res = client.post("/auth/register", json={
        "name": "New User",
        "email": email,
        "password": "SecretPassword123!",
        "role": "driver",
    })
    assert res.status_code == 201

    # Retrieve OTP directly from DB for verification test
    with get_db() as db:
        user = db.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        assert user is not None
        assert user["is_verified"] == 0

        # Attempt login before verification -> 403
        login_res = client.post("/auth/login", json={"email": email, "password": "SecretPassword123!"})
        assert login_res.status_code == 403

        # Simulate getting code from email
        # We can update attempts or directly test verify-otp with bad code
        bad_otp_res = client.post("/auth/verify-otp", json={"email": email, "code": "000000"})
        assert bad_otp_res.status_code == 400

        # Now manually set verified in DB to test successful login
        db.execute("UPDATE users SET is_verified = 1 WHERE email = ?", (email,))

    # Now login succeeds
    login_res = client.post("/auth/login", json={"email": email, "password": "SecretPassword123!"})
    assert login_res.status_code == 200
    data = login_res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == email

    # Test token refresh
    refresh_res = client.post("/auth/refresh", json={"refresh_token": data["refresh_token"]})
    assert refresh_res.status_code == 200
    ref_data = refresh_res.json()
    assert "access_token" in ref_data
    assert "refresh_token" in ref_data

    # Old refresh token should now be revoked
    revoked_res = client.post("/auth/refresh", json={"refresh_token": data["refresh_token"]})
    assert revoked_res.status_code == 401

