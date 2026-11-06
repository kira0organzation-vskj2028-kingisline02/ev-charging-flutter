import json
import httpx
from loguru import logger
from ..config import settings

SYSTEM_PROMPT = """You are an assistant for an EV charger rental marketplace in India.
Given the host's details (location, connector type, kW, amenities),
write a friendly 60-word listing description and suggest a price
range per kWh based on typical local rates in INR.
Return JSON only, no markdown:
{"description": "...", "suggested_price_min": n, "suggested_price_max": n}
Never invent amenities that were not provided.
"""

def fallback_listing(details: dict) -> dict:
    location = details.get("location", "Prime Location")
    connector = details.get("connector_type", "Type2")
    kw = details.get("power_kw", 7.4)
    amenities = details.get("amenities", [])
    amenities_str = f" with {', '.join(amenities)}" if amenities else ""
    
    # Typical EV charging tariffs in India: AC ~ 12-18 INR/kWh, DC fast ~ 18-25 INR/kWh
    if kw > 22:
        p_min, p_max = 18.0, 24.0
    else:
        p_min, p_max = 12.0, 16.0

    desc = (
        f"Convenient and reliable EV charging spot in {location}. Features a {kw} kW {connector} "
        f"charger suitable for everyday EV charging{amenities_str}. Easy drive-in access, safe parking, "
        f"and friendly host support for a seamless charging experience."
    )
    return {
        "description": desc,
        "suggested_price_min": p_min,
        "suggested_price_max": p_max,
    }

async def generate_listing(details: dict) -> dict:
    if not settings.gemini_api_key:
        logger.info("No GEMINI_API_KEY provided; using smart template fallback.")
        return fallback_listing(details)

    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-1.5-flash:generateContent?key={settings.gemini_api_key}"
    )
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": SYSTEM_PROMPT + "\nDetails: " + json.dumps(details)}
                ]
            }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(text)
    except Exception as e:
        logger.warning(f"Gemini API request failed ({e}); falling back to template.")
        return fallback_listing(details)

