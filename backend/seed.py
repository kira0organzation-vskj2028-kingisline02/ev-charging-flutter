import os
import sys
import json
import time

# Ensure app is in python path
sys.path.insert(0, os.path.dirname(__file__))

from app.db import init_db, get_db
from app.security import hash_password

def seed():
    print("Initializing database schema...")
    init_db()

    with get_db() as db:
        # Check if already seeded
        cur = db.execute("SELECT COUNT(*) FROM users WHERE email = 'ramesh@example.com'")
        if cur.fetchone()[0] > 0:
            print("Database already contains seed data.")
            return

        print("Seeding demo users...")
        pw = hash_password("Password123!")

        # Host 1: Ramesh Kumar
        db.execute("""
            INSERT INTO users (name, email, phone, role, password_hash, is_verified)
            VALUES (?, ?, ?, ?, ?, 1)
        """, ("Ramesh Kumar", "ramesh@example.com", "9876543210", "host", pw))
        host1_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Host 2: Priya Sharma
        db.execute("""
            INSERT INTO users (name, email, phone, role, password_hash, is_verified)
            VALUES (?, ?, ?, ?, ?, 1)
        """, ("Priya Sharma", "priya@example.com", "9876543211", "host", pw))
        host2_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Driver: Ankit Patel
        db.execute("""
            INSERT INTO users (name, email, phone, role, password_hash, is_verified)
            VALUES (?, ?, ?, ?, ?, 1)
        """, ("Ankit Patel", "driver@example.com", "9876543212", "driver", pw))
        driver_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Admin: ChargeBridge Admin
        db.execute("""
            INSERT INTO users (name, email, phone, role, password_hash, is_verified)
            VALUES (?, ?, ?, ?, ?, 1)
        """, ("Admin", "admin@chargebridge.in", "9999999999", "admin", pw))

        print("Seeding chargers matching Stitch design...")
        # Charger 1: GreenNest Villa Charger (Featured Stitch Design location)
        c1_photos = json.dumps([
            "https://images.unsplash.com/photo-1593941707882-a5bba14938c7?auto=format&fit=crop&w=800&q=80"
        ])
        db.execute("""
            INSERT INTO chargers (
                host_id, title, description, lat, lng, address, connector_type,
                power_kw, price_per_kwh, price_per_hour, photos, is_active, is_featured
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1)
        """, (
            host1_id,
            "GreenNest Villa Charger",
            "SafeCharge™ certified fast charger in a secure, covered residential bay with 24/7 CCTV and 300 Mbps Wi-Fi.",
            12.9352,
            77.6245,
            "Plot 42, 5th Cross, Koramangala 4th Block, Bengaluru",
            "CCS2",
            22.0,
            16.0,
            250.0,
            c1_photos
        ))
        c1_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Charger 2: Indiranagar Fast Port
        c2_photos = json.dumps([
            "https://images.unsplash.com/photo-1558441719-869719326d9e?auto=format&fit=crop&w=800&q=80"
        ])
        db.execute("""
            INSERT INTO chargers (
                host_id, title, description, lat, lng, address, connector_type,
                power_kw, price_per_kwh, price_per_hour, photos, is_active, is_featured
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1)
        """, (
            host2_id,
            "Indiranagar 100ft Fast Port",
            "Prime location near 100ft Road. Monsoon-proof IP65 enclosure with wide ramp access for large electric SUVs.",
            12.9719,
            77.6412,
            "12th Main, 100ft Road, Indiranagar, Bengaluru",
            "CCS2",
            22.0,
            18.0,
            280.0,
            c2_photos
        ))
        c2_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        # Charger 3: HSR Layout Green Port
        db.execute("""
            INSERT INTO chargers (
                host_id, title, description, lat, lng, address, connector_type,
                power_kw, price_per_kwh, price_per_hour, photos, is_active, is_featured
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0)
        """, (
            host1_id,
            "HSR Sector 3 Solar Port",
            "Solar-powered overnight EV charging with Type 2 connector. Perfect for commute top-ups.",
            12.9116,
            77.6389,
            "14th Cross, Sector 3, HSR Layout, Bengaluru",
            "Type2",
            7.4,
            14.0,
            180.0,
            "[]"
        ))
        c3_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        print("Seeding weekly availability...")
        for cid in [c1_id, c2_id, c3_id]:
            for day in range(7):
                db.execute("""
                    INSERT INTO availability (charger_id, day_of_week, start_time, end_time)
                    VALUES (?, ?, '06:00', '23:00')
                """, (cid, day))

        print("Seeding sample completed booking & reviews...")
        past_start = int(time.time()) - 86400 * 2
        past_end = past_start + 7200
        db.execute("""
            INSERT INTO bookings (
                charger_id, driver_id, start_ts, end_ts, status, amount, commission, host_payout, payout_status
            ) VALUES (?, ?, ?, ?, 'COMPLETED', 35000, 3500, 31500, 'PAID')
        """, (c1_id, driver_id, past_start, past_end))
        booking1_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]

        db.execute("""
            INSERT INTO reviews (booking_id, rating, comment)
            VALUES (?, 5, 'Seamless charging for my Nexon EV! Host offered chilled drinking water and had a clear parking space ready. Clocked 22kW steady without heating.')
        """, (booking1_id,))

        print("Seed completed successfully!")

if __name__ == "__main__":
    seed()
