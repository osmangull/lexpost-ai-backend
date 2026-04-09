from typing import Optional
from pydantic import BaseModel, Field


class RegisterTokenRequest(BaseModel):
    fcm_token: str
    notification_hour: int = Field(default=8, ge=0, le=23)
    user_id: Optional[str] = None


class UpdateNotificationSettingsRequest(BaseModel):
    fcm_token: str
    notification_hour: Optional[int] = Field(default=None, ge=0, le=23)
    notifications_enabled: Optional[bool] = None
