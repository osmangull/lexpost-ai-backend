import logging
import re
import unicodedata
import uuid
from pathlib import Path

from app.config import get_settings
from app.core.image_engine import render_post_image
from app.db.models import FontStyle
from app.db.supabase_client import get_supabase

logger = logging.getLogger(__name__)
settings = get_settings()


def _strip_unsupported(text: str) -> str:
    """Emoji ve font dışı Unicode karakterleri kaldırır."""
    return "".join(
        ch for ch in text
        if unicodedata.category(ch) not in ("So", "Cs")  # Symbol-other, Surrogate
        and ord(ch) < 0xFFFD
    ).strip()


def _prepare_custom_text(custom_text: str) -> tuple[str, list[str], str]:
    """
    Kullanıcının düzenlediği metni image engine için hazırlar.
    - ⚖️ / 'Avukatlar için not:' satırını CTA olarak ayırır
    - Emoji ve desteklenmeyen karakterleri temizler
    - Kalan satırları body olarak döndürür (• satırları dahil)
    """
    cta = "Detaylar için resmi gazeteyi inceleyin."
    body_lines = []

    for raw_line in custom_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if "Avukatlar için" in line or "\u2696" in line:
            cleaned = re.sub(r".*Avukatlar için not:\s*", "", line).strip()
            if cleaned:
                cta = _strip_unsupported(cleaned)
            continue
        body_lines.append(_strip_unsupported(line))

    return "\n".join(body_lines), [], cta


def _parse_summary_parts(ai_summary: str) -> tuple[str, list[str], str]:
    """
    Parse structured summary into (body, bullets, cta).
    Yeni format (başlık artık summary'de YOK — update["title"] ayrı kullanılır):
        [Body sentence]
        • [Bullet 1]
        • [Bullet 2]
        ⚖️ Avukatlar için not: [CTA]
    """
    lines = [l.strip() for l in ai_summary.splitlines() if l.strip()]

    body_lines = []
    bullets = []
    cta = "Detaylar için resmi gazeteyi inceleyin."

    for line in lines:
        if line.startswith("•"):
            bullets.append(line.lstrip("• ").strip())
        elif "⚖️" in line or "Avukatlar için" in line:
            cta = re.sub(r"⚖️\s*Avukatlar için not:\s*", "", line).strip()
        else:
            body_lines.append(line)

    body = "\n".join(body_lines)
    # Bullet yoksa boş döndür — engine bullet bölümünü atlar
    return body, bullets[:2], cta


async def generate_and_store_post(
    legal_update_id: str,
    template_id: str,
    font_style: FontStyle,
    user_id: str,
    custom_text: str = None,
) -> dict:
    """Generate post image, upload to Supabase Storage, persist record."""
    db = get_supabase()

    # Fetch legal update
    update_res = db.table("legal_updates").select("*").eq("id", legal_update_id).single().execute()
    update = update_res.data
    if not update:
        raise ValueError(f"Legal update {legal_update_id} not found")

    # Fetch template background
    template_res = db.table("templates").select("*").eq("id", template_id).single().execute()
    template = template_res.data
    if not template:
        raise ValueError(f"Template {template_id} not found")

    background_path = Path(settings.backgrounds_dir) / template["background_filename"]
    ai_summary = update.get("ai_summary") or ""

    # Başlık direkt legal update'ten alınır — uzunluk sınırı yok, engine satır sararak gösterir
    image_title = update.get("title", "Hukuki Güncelleme")

    if custom_text and custom_text.strip():
        body, bullets, cta = _prepare_custom_text(custom_text)
    else:
        body, bullets, cta = _parse_summary_parts(ai_summary)
    image_bytes = render_post_image(str(background_path), image_title, body, bullets, cta, font_style)

    # Upload to Supabase Storage
    filename = f"{user_id}/{legal_update_id}_{uuid.uuid4().hex[:8]}.jpg"
    upload_res = db.storage.from_("generated-posts").upload(
        path=filename,
        file=image_bytes,
        file_options={"content-type": "image/jpeg"},
    )
    image_url = db.storage.from_("generated-posts").get_public_url(filename)

    # Persist post record
    record = {
        "user_id": user_id,
        "legal_update_id": legal_update_id,
        "template_id": template_id,
        "font_style": font_style.value,
        "image_url": image_url,
        "caption": f"{image_title}\n\n{body}",
        "status": "generated",
    }
    post_res = db.table("generated_posts").insert(record).execute()
    return post_res.data[0]
