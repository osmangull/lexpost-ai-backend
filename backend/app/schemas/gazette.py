from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, HttpUrl
from app.db.models import DocumentType


class LegalUpdateBase(BaseModel):
    title: str
    document_type: DocumentType
    gazette_date: date
    gazette_number: str
    source_url: str
    raw_content: Optional[str] = None


class LegalUpdateCreate(LegalUpdateBase):
    pass


class LegalUpdateOut(LegalUpdateBase):
    id: str
    ai_summary: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True
