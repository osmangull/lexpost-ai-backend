"""
APScheduler: Gazette scraping schedule (TRT = UTC+3)
- 00:10 : scrape + 5-day cleanup
- 01:00/03:00/05:00/07:00 : gece/sabah retry
- 12:00/15:00/18:00/20:00/22:00 : gün içi retry
İdempotent: DB'de bugün veri varsa sonraki joblar otomatik atlanır.
"""

import logging
from datetime import timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz

logger = logging.getLogger(__name__)

_scheduler = AsyncIOScheduler(timezone=pytz.timezone("Europe/Istanbul"))


async def _run_nightly_job():
    """00:10 TRT: scrape today's gazette + delete records older than 5 days."""
    from app.services.gazette_service import process_daily_gazette
    from app.db.supabase_client import get_supabase
    from datetime import datetime

    logger.info("Nightly job started: scrape + cleanup.")

    try:
        results = await process_daily_gazette()
        logger.info(f"Nightly scrape: {len(results)} new records saved.")
    except Exception as e:
        logger.error(f"Nightly scrape failed: {e}")

    try:
        today_trt = datetime.now(pytz.timezone("Europe/Istanbul")).date()
        cutoff = (today_trt - timedelta(days=5)).isoformat()
        db = get_supabase()
        res = db.table("legal_updates").delete().lt("gazette_date", cutoff).execute()
        deleted = len(res.data) if res.data else 0
        logger.info(f"Cleanup: deleted {deleted} records older than {cutoff}.")
    except Exception as e:
        logger.error(f"Nightly cleanup failed: {e}")


async def _run_idempotent_scrape():
    """Bugün için zaten veri varsa hiçbir şey yapmaz; yoksa scrape eder."""
    from app.services.gazette_service import process_daily_gazette
    from app.db.supabase_client import get_supabase
    from datetime import datetime

    today = datetime.now(pytz.timezone("Europe/Istanbul")).date().isoformat()
    db = get_supabase()
    existing = db.table("legal_updates").select("id").eq("gazette_date", today).limit(1).execute()
    if existing.data:
        logger.info(f"Idempotent scrape: today ({today}) already in DB, skipping.")
        return

    logger.info(f"Idempotent scrape: no data for {today}, starting scrape.")
    try:
        results = await process_daily_gazette()
        logger.info(f"Idempotent scrape done: {len(results)} new records.")
    except Exception as e:
        logger.error(f"Idempotent scrape failed: {e}")


async def start_scheduler():
    _scheduler.add_job(_run_nightly_job,       CronTrigger(hour=0,  minute=10), id="gazette_nightly",  replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=1,  minute=0),  id="gazette_retry_01", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=3,  minute=0),  id="gazette_retry_03", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=5,  minute=0),  id="gazette_retry_05", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=7,  minute=0),  id="gazette_retry_07", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=12, minute=0),  id="gazette_retry_12", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=15, minute=0),  id="gazette_retry_15", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=18, minute=0),  id="gazette_retry_18", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=20, minute=0),  id="gazette_retry_20", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=22, minute=0),  id="gazette_retry_22", replace_existing=True)
    _scheduler.start()
    logger.info("Scheduler started: nightly 00:10, retries 01/03/05/07/12/15/18/20/22 TRT")


async def stop_scheduler():
    _scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped.")
