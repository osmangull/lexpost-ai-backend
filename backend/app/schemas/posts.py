from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from app.db.models import FontStyle, PostStatus


class GeneratePostRequest(BaseModel):
    legal_update_id: str
    template_id: Optional[str] = None
    user_image_base64: Optional[str] = None  # kullanıcının kendi görseli (base64 JPEG)
    font_style: FontStyle = FontStyle.CLASSIC
    user_id: str
    custom_text: Optional[str] = None


class GeneratedPostOut(BaseModel):
    id: str
    legal_update_id: str
    template_id: Optional[str]
    font_style: FontStyle
    image_url: str
    caption: str
    status: PostStatus
    created_at: datetime

    class Config:
        from_attributes = True


class TemplateOut(BaseModel):
    id: str
    name: str
    theme: str
    background_filename: str
    background_url: Optional[str] = None
    preview_url: Optional[str] = None
    sort_order: int
    is_pro: bool = False

    class Config:
        from_attributes = True
