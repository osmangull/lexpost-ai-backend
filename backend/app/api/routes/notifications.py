from fastapi import APIRouter, HTTPException

from app.db.supabase_client import get_supabase
from app.schemas.notifications import RegisterTokenRequest, UpdateNotificationSettingsRequest

router = APIRouter()


@router.post("/register", status_code=201)
async def register_token(request: RegisterTokenRequest):
    """FCM token'ı kaydet veya güncelle (upsert)."""
    db = get_supabase()
    db.table("device_tokens").upsert(
        {
            "fcm_token": request.fcm_token,
            "notification_hour": request.notification_hour,
            "user_id": request.user_id,
            "notifications_enabled": True,
        },
        on_conflict="fcm_token",
    ).execute()
    return {"status": "registered"}


@router.put("/settings")
async def update_settings(request: UpdateNotificationSettingsRequest):
    """Bildirim saati veya açık/kapalı durumunu güncelle."""
    db = get_supabase()
    update_data = {}
    if request.notification_hour is not None:
        update_data["notification_hour"] = request.notification_hour
    if request.notifications_enabled is not None:
        update_data["notifications_enabled"] = request.notifications_enabled

    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update.")

    db.table("device_tokens").update(update_data).eq("fcm_token", request.fcm_token).execute()
    return {"status": "updated"}


@router.delete("/unregister")
async def unregister_token(fcm_token: str):
    """Token'ı sil (uygulama kaldırıldığında veya bildirim kapatıldığında)."""
    db = get_supabase()
    db.table("device_tokens").delete().eq("fcm_token", fcm_token).execute()
    return {"status": "unregistered"}
