from fastapi import APIRouter
from pydantic import BaseModel

from app.config import get_settings

router = APIRouter()


class PromoRequest(BaseModel):
    code: str


@router.post("/validate-promo")
async def validate_promo(request: PromoRequest):
    settings = get_settings()
    valid = request.code.upper().strip() == settings.promo_code.upper().strip()
    return {"valid": valid}


@router.get("/pricing")
async def get_pricing():
    settings = get_settings()
    return {
        "monthly_price": settings.monthly_price,
        "yearly_price": settings.yearly_price,
        "yearly_savings": settings.yearly_savings,
        "notification_title": settings.notification_title,
        "notification_body": settings.notification_body,
    }
