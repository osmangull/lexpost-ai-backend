import json
import logging
import os

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _init_firebase() -> bool:
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        if firebase_admin._apps:
            _firebase_initialized = True
            return True
        from firebase_admin import credentials
        sa_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if not sa_json:
            logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON env var not set — notifications disabled.")
            return False
        cred = credentials.Certificate(json.loads(sa_json))
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase initialized.")
        return True
    except Exception as e:
        logger.error(f"Firebase init failed: {e}")
        return False


async def send_gazette_notifications(new_count: int) -> int:
    """
    Yeni gazete kayıtları kaydedildikten sonra çağrılır.
    notification_hour <= current_hour olan ve bugün henüz bildirim almamış
    tüm aktif cihazlara FCM bildirimi gönderir.
    Gönderilen cihaz sayısını döner.
    """
    if not _init_firebase():
        return 0

    from firebase_admin import messaging
    from app.db.supabase_client import get_supabase
    from datetime import datetime
    import pytz

    tz = pytz.timezone("Europe/Istanbul")
    now_trt = datetime.now(tz)
    today = now_trt.date().isoformat()
    current_hour = now_trt.hour

    db = get_supabase()
    res = (
        db.table("device_tokens")
        .select("id, fcm_token")
        .eq("notifications_enabled", True)
        .lte("notification_hour", current_hour)
        .execute()
    )
    all_tokens = res.data or []

    # Bugün zaten bildirim almışları filtrele
    tokens = [t for t in all_tokens if t.get("last_notified_date") != today]
    if not tokens:
        logger.info("send_gazette_notifications: no eligible tokens.")
        return 0

    title = "📋 Yeni Resmi Gazete Yayınları"
    body = (
        f"Bugün {new_count} yeni hukuki güncelleme yayınlandı."
        if new_count > 1
        else "Bugün 1 yeni hukuki güncelleme yayınlandı."
    )

    sent = 0
    for row in tokens:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default", badge=new_count)
                    )
                ),
                token=row["fcm_token"],
            )
            messaging.send(msg)
            db.table("device_tokens").update({"last_notified_date": today}).eq("id", row["id"]).execute()
            sent += 1
        except Exception as e:
            logger.error(f"Notification failed for token ...{row['fcm_token'][-10:]}: {e}")

    logger.info(f"send_gazette_notifications: sent to {sent}/{len(tokens)} devices.")
    return sent
