"""
APScheduler: Gazette scraping schedule (TRT = UTC+3)
- 00:10 : scrape + 5-day cleanup
- 01:00/02:00/03:00/06:00/09:00 : erken sabah retry
- 11:00/14:00/17:00 : gün içi retry (gazete bazen 09:00'dan sonra yayınlanır)
"""

import logging
from datetime import date, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz

logger = logging.getLogger(__name__)

_scheduler = AsyncIOScheduler(timezone=pytz.timezone("Europe/Istanbul"))


async def _run_nightly_job():
    """00:10 TRT: scrape today's gazette + delete records older than 5 days."""
    from app.services.gazette_service import process_daily_gazette
    from app.db.supabase_client import get_supabase

    logger.info("Nightly job started: scrape + cleanup.")

    try:
        results = await process_daily_gazette()
        logger.info(f"Nightly scrape: {len(results)} new records saved.")
    except Exception as e:
        logger.error(f"Nightly scrape failed: {e}")

    try:
        cutoff = (date.today() - timedelta(days=5)).isoformat()
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

    import pytz
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
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=2,  minute=0),  id="gazette_retry_02", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=3,  minute=0),  id="gazette_retry_03", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=6,  minute=0),  id="gazette_retry_06", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=9,  minute=0),  id="gazette_retry_09", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=11, minute=0),  id="gazette_retry_11", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=14, minute=0),  id="gazette_retry_14", replace_existing=True)
    _scheduler.add_job(_run_idempotent_scrape, CronTrigger(hour=17, minute=0),  id="gazette_retry_17", replace_existing=True)
    _scheduler.start()
    logger.info("Scheduler started: nightly 00:10, retries 01/02/03/06/09/11/14/17 TRT")


async def stop_scheduler():
    _scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped.")
