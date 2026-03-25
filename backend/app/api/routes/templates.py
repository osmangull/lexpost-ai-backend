from fastapi import APIRouter

from app.db.supabase_client import get_supabase
from app.schemas.posts import TemplateOut

router = APIRouter()


@router.get("/", response_model=list[TemplateOut])
async def list_templates():
    db = get_supabase()
    result = db.table("templates").select("*").order("sort_order").execute()
    return result.data
