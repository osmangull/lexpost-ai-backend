from typing import Optional
from pydantic import BaseModel
from app.db.models import FontStyle


class GeneratePostRequest(BaseModel):
    legal_update_id: str
    template_id: Optional[str] = None
    user_image_base64: Optional[str] = None
    font_style: FontStyle = FontStyle.CLASSIC
    user_id: str
    custom_text: Optional[str] = None
    custom_category: Optional[str] = None   # badge alanı (ör. "Yönetmelik")
    custom_title: Optional[str] = None      # başlık alanı
    text_color: Optional[str] = None        # hex renk ör. "#FFFFFF"
    accent_color: Optional[str] = None      # hex renk ör. "#D4AF37"
    font_size_delta: int = 0                # -4 küçük, 0 orta, +6 büyük


class ManualPostRequest(BaseModel):
    user_image_base64: str
    custom_text: str = ""
    custom_category: Optional[str] = None
    custom_title: Optional[str] = None
    font_style: FontStyle = FontStyle.CLASSIC
    user_id: str
    text_color: Optional[str] = None
    accent_color: Optional[str] = None
    font_size_delta: int = 0


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
