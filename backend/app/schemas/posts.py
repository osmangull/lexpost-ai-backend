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


class ManualPostRequest(BaseModel):
    user_image_base64: str
    custom_text: str = ""
    font_style: FontStyle = FontStyle.CLASSIC
    user_id: str


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
