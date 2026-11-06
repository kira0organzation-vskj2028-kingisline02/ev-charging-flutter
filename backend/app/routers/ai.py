from fastapi import APIRouter, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..deps import require_role
from ..schemas import AiListingIn, AiListingOut
from ..services.ai import generate_listing

router = APIRouter(prefix="/ai", tags=["ai"])
limiter = Limiter(key_func=get_remote_address)

@router.post("/listing", response_model=AiListingOut)
@limiter.limit("5/minute")
async def ai_listing_writer(
    request: Request,
    body: AiListingIn,
    user: dict = Depends(require_role("host", "admin")),
):
    details = body.model_dump()
    result = await generate_listing(details)
    return AiListingOut(
        description=result.get("description", "Quality EV charging location with reliable access."),
        suggested_price_min=float(result.get("suggested_price_min", 12.0)),
        suggested_price_max=float(result.get("suggested_price_max", 18.0)),
    )

