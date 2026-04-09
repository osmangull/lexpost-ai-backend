import logging
from datetime import date
from typing import Optional

from app.core.scraper import fetch_gazette_index, extract_pdf_text, extract_html_text
from app.core.summarizer import summarize_legal_text
from app.db.supabase_client import get_supabase

logger = logging.getLogger(__name__)


async def process_daily_gazette(target_date: Optional[date] = None) -> list[dict]:
    """
    Full pipeline: scrape -> PDF extract -> AI summarize -> persist to Supabase.
    Returns list of persisted update records.
    """
    db = get_supabase()
    updates = await fetch_gazette_index(target_date)
    results = []

    for update in updates:
        # Skip duplicates
        existing = (
            db.table("legal_updates")
            .select("id")
            .eq("source_url", update.source_url)
            .execute()
        )
        if existing.data:
            logger.debug(f"Skipping duplicate: {update.title[:60]}")
            continue

        # Belge içeriğini çek: PDF → PyMuPDF, HTM/HTML → BeautifulSoup
        raw_content = update.raw_content
        url_lower = update.source_url.lower()
        if url_lower.endswith(".pdf"):
            raw_content = await extract_pdf_text(update.source_url)
        elif url_lower.endswith((".htm", ".html")):
            raw_content = await extract_html_text(update.source_url)

        # Hibrit özetleme (kural tabanlı + TF-IDF)
        ai_summary = None
        if raw_content:
            try:
                ai_summary = await summarize_legal_text(
                    update.title, raw_content, update.document_type.value
                )
            except Exception as e:
                logger.error(f"Summarization failed for '{update.title[:60]}': {e}")

        record = {
            "title": update.title,
            "document_type": update.document_type.value,
            "gazette_date": update.gazette_date.isoformat(),
            "gazette_number": update.gazette_number,
            "source_url": update.source_url,
            "raw_content": raw_content,
            "ai_summary": ai_summary,
        }

        response = db.table("legal_updates").insert(record).execute()
        if response.data:
            results.append(response.data[0])
            logger.info(f"Persisted: {update.title[:60]}")

    logger.info(f"Pipeline complete: {len(results)} new updates saved.")

    if results:
        try:
            from app.services.notification_service import send_gazette_notifications
            await send_gazette_notifications(len(results))
        except Exception as e:
            logger.error(f"Notification dispatch failed: {e}")

    return results
