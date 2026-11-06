import math
from app.services.geo import bounding_box, haversine_km

def test_bounding_box():
    lat, lng = 28.6139, 77.2090
    min_lat, max_lat, min_lng, max_lng = bounding_box(lat, lng, 10.0)
    assert min_lat < lat < max_lat
    assert min_lng < lng < max_lng

def test_haversine_distance():
    # Distance between New Delhi (28.6139, 77.2090) and Noida (28.5355, 77.3910) is approx 20 km
    dist = haversine_km(28.6139, 77.2090, 28.5355, 77.3910)
    assert 15.0 < dist < 25.0

    # Distance to identical point is 0
    assert haversine_km(28.6139, 77.2090, 28.6139, 77.2090) == 0.0

