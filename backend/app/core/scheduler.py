"""
APScheduler: Runs gazette scraping at 11:00 and 17:00 TRT (UTC+3),
and a nightly cleanup job at 00:10 TRT that scrapes the day's gazette
then deletes records older than 5 days.
"""

import logging
from datetime import date, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz

logger = logging.getLogger(__name__)

_scheduler = AsyncIOScheduler(timezone=pytz.timezone("Europe/Istanbul"))


async def _run_gazette_scrape():
    from app.services.gazette_service import process_daily_gazette
    logger.info("Scheduled gazette scrape triggered.")
    await process_daily_gazette()


async def _run_nightly_job():
    """
    00:10 TRT: scrape today's gazette, then delete records older than 5 days.
    """
    from app.services.gazette_service import process_daily_gazette
    from app.db.supabase_client import get_supabase

    logger.info("Nightly job started: scrape + cleanup.")

    # 1. Scrape today's gazette
    try:
        results = await process_daily_gazette()
        logger.info(f"Nightly scrape: {len(results)} new records saved.")
    except Exception as e:
        logger.error(f"Nightly scrape failed: {e}")

    # 2. Delete records older than 5 days
    try:
        cutoff = (date.today() - timedelta(days=5)).isoformat()
        db = get_supabase()
        res = db.table("legal_updates").delete().lt("gazette_date", cutoff).execute()
        deleted = len(res.data) if res.data else 0
        logger.info(f"Cleanup: deleted {deleted} records older than {cutoff}.")
    except Exception as e:
        logger.error(f"Nightly cleanup failed: {e}")


async def start_scheduler():
    _scheduler.add_job(_run_gazette_scrape, CronTrigger(hour=11, minute=0), id="gazette_morning", replace_existing=True)
    _scheduler.add_job(_run_gazette_scrape, CronTrigger(hour=17, minute=0), id="gazette_evening", replace_existing=True)
    _scheduler.add_job(_run_nightly_job,    CronTrigger(hour=0,  minute=10), id="gazette_nightly", replace_existing=True)
    _scheduler.start()
    logger.info("Scheduler started: scrape at 11:00 & 17:00, nightly cleanup at 00:10 TRT")


async def stop_scheduler():
    _scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped.")
