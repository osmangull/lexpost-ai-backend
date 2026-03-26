from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.db.supabase_client import get_supabase
from app.schemas.gazette import LegalUpdateOut
from app.services.gazette_service import process_daily_gazette

router = APIRouter()


@router.get("/", response_model=list[LegalUpdateOut])
async def list_updates(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    document_type: Optional[str] = None,
):
    db = get_supabase()
    query = db.table("legal_updates").select("*").order("gazette_date", desc=True).range(offset, offset + limit - 1)
    if document_type:
        query = query.eq("document_type", document_type)
    result = query.execute()
    return result.data


@router.get("/{update_id}", response_model=LegalUpdateOut)
async def get_update(update_id: str):
    db = get_supabase()
    result = db.table("legal_updates").select("*").eq("id", update_id).single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Legal update not found")
    return result.data


@router.get("/today-count")
async def today_count():
    """
    Bugüne ait DB'deki kayıt sayısını döner.
    Pull-to-refresh'te gazeteyi scrape etmeden veri tazeliğini kontrol etmek için kullanılır.
    """
    db = get_supabase()
    today = date.today().isoformat()
    result = (
        db.table("legal_updates")
        .select("id", count="exact")
        .eq("gazette_date", today)
        .execute()
    )
    return {"date": today, "count": result.count or 0}


@router.post("/scrape")
async def trigger_scrape(target_date: Optional[date] = None):
    """Manually trigger a gazette scrape (admin use)."""
    updates = await process_daily_gazette(target_date)
    return {"message": f"Scraped and saved {len(updates)} updates", "count": len(updates)}
