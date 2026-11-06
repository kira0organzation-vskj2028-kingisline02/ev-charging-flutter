import random
from locust import HttpUser, task, between

class ChargeBridgeUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        # Register or use test driver credentials
        self.email = f"user_{random.randint(1000, 999999)}@example.com"
        # Health check first
        self.client.get("/health")

    @task(5)
    def search_chargers(self):
        # Query chargers around New Delhi / NCR
        lat = 28.6139 + random.uniform(-0.1, 0.1)
        lng = 77.2090 + random.uniform(-0.1, 0.1)
        self.client.get(f"/chargers?lat={lat:.4f}&lng={lng:.4f}&radius_km=30")

    @task(2)
    def view_charger_detail(self):
        self.client.get("/chargers/1")

