import base64
import logging
import re
import unicodedata
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


async def generate_post_image(
    legal_update_id: str,
    font_style: FontStyle,
    template_id: str = None,
    custom_text: str = None,
    user_image_base64: str = None,
) -> bytes:
    """Görsel oluştur ve JPEG bytes döndür. DB/Storage kaydı yapılmaz."""
    db = get_supabase()

    if not template_id and not user_image_base64:
        raise ValueError("template_id or user_image_base64 must be provided")

    update_res = db.table("legal_updates").select("*").eq("id", legal_update_id).single().execute()
    update = update_res.data
    if not update:
        raise ValueError(f"Legal update {legal_update_id} not found")

    if user_image_base64:
        background_source = base64.b64decode(user_image_base64)
    else:
        template_res = db.table("templates").select("*").eq("id", template_id).single().execute()
        template = template_res.data
        if not template:
            raise ValueError(f"Template {template_id} not found")
        background_source = str(Path(settings.backgrounds_dir) / template["background_filename"])

    ai_summary = update.get("ai_summary") or ""
    image_title = update.get("title", "Hukuki Güncelleme")

    if custom_text and custom_text.strip():
        body, bullets, cta = _prepare_custom_text(custom_text)
    else:
        body, bullets, cta = _parse_summary_parts(ai_summary)

    return render_post_image(background_source, image_title, body, bullets, cta, font_style)


async def generate_manual_post_image(
    user_image_base64: str,
    custom_text: str,
    font_style: FontStyle,
) -> bytes:
    """Manuel gönderi: kullanıcının görseli üzerine metin yaz, JPEG bytes döndür."""
    background_source = base64.b64decode(user_image_base64)
    body, bullets, cta = _prepare_custom_text(custom_text) if custom_text.strip() else ("", [], "")
    return render_post_image(background_source, "", body, bullets, cta, font_style)
