"""
Image rendering engine using Pillow.
Renders legal summaries onto background images with Playfair Display / Montserrat fonts.
Output: 1080x1080 px (Instagram square format)
"""

import io
import logging
import textwrap
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

from app.config import get_settings
from app.db.models import FontStyle

logger = logging.getLogger(__name__)
settings = get_settings()

CANVAS_SIZE = (1080, 1080)
PADDING = 80
TEXT_AREA_WIDTH = CANVAS_SIZE[0] - (PADDING * 2)

FONT_FILES = {
    FontStyle.CLASSIC: {
        "title": "PlayfairDisplay-Bold.ttf",
        "body": "PlayfairDisplay-Regular.ttf",
    },
    FontStyle.MODERN: {
        "title": "Montserrat-Bold.ttf",
        "body": "Montserrat-Regular.ttf",
    },
}

FONT_SIZES = {
    "title": 48,
    "body": 32,
    "bullet": 28,
    "cta": 26,
    "badge": 22,
}

OVERLAY_OPACITY = 175  # biraz daha koyu → metin daha okunaklı
TEXT_COLOR = (255, 255, 255)
ACCENT_COLOR = (212, 175, 55)   # Altın
BODY_COLOR = (225, 225, 225)
BULLET_TEXT_COLOR = (210, 210, 210)


def _get_font(font_style: FontStyle, role: str, size: Optional[int] = None) -> ImageFont.FreeTypeFont:
    font_dir = Path(settings.fonts_dir)
    filename = FONT_FILES[font_style][role]
    font_path = font_dir / filename
    font_size = size or FONT_SIZES.get(role, 32)
    try:
        return ImageFont.truetype(str(font_path), font_size)
    except OSError:
        logger.warning(f"Font not found: {font_path}, falling back to default")
        return ImageFont.load_default()


def _add_dark_overlay(image: Image.Image, opacity: int = OVERLAY_OPACITY) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, opacity))
    base = image.convert("RGBA")
    combined = Image.alpha_composite(base, overlay)
    return combined.convert("RGB")


def _wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int, draw: ImageDraw.ImageDraw) -> list[str]:
    words = text.split()
    lines = []
    current_line = ""
    for word in words:
        test_line = f"{current_line} {word}".strip()
        bbox = draw.textbbox((0, 0), test_line, font=font)
        if bbox[2] <= max_width:
            current_line = test_line
        else:
            if current_line:
                lines.append(current_line)
            current_line = word
    if current_line:
        lines.append(current_line)
    return lines


def render_post_image(
    background_source: "str | bytes",
    title: str,
    summary_body: str,
    bullets: list[str],
    cta: str,
    font_style: FontStyle = FontStyle.CLASSIC,
) -> bytes:
    """
    Render a 1080x1080 post image and return as JPEG bytes.

    Args:
        background_source: Absolute path string OR raw image bytes (user-uploaded)
        title: Bold headline text
        summary_body: 1-2 sentence body text
        bullets: List of exactly 2 bullet point strings
        cta: Call-to-action text (bottom)
        font_style: Classic (Playfair) or Modern (Montserrat)
    """
    # Load and resize background
    if isinstance(background_source, bytes):
        bg = Image.open(io.BytesIO(background_source))
    else:
        bg = Image.open(background_source)
    bg = ImageOps.exif_transpose(bg).convert("RGB")
    bg = bg.resize(CANVAS_SIZE, Image.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(radius=1.5))  # subtle blur for depth
    image = _add_dark_overlay(bg)

    draw = ImageDraw.Draw(image)

    font_title = _get_font(font_style, "title", FONT_SIZES["title"])
    font_body = _get_font(font_style, "body", FONT_SIZES["body"])
    font_bullet = _get_font(font_style, "body", FONT_SIZES["bullet"])
    font_cta = _get_font(font_style, "body", FONT_SIZES["cta"])

    y_cursor = PADDING + 30

    # --- Üst şerit: "HUKUK GÜNCELLEMESİ" badge ---
    badge_font = _get_font(font_style, "body", FONT_SIZES["badge"])
    badge_text = "HUKUK GÜNCELLEMESİ"
    draw.text((PADDING, y_cursor), badge_text, font=badge_font, fill=ACCENT_COLOR)
    y_cursor += FONT_SIZES["badge"] + 16

    # --- Title ---
    # Başlık kaç satır gerektiriyorsa o kadar göster; font gerektiğinde küçültülür
    # Hedef: başlığın tamamı görselde görünsün
    _title_sizes = [48, 42, 38, 34, 30]
    title_font = font_title
    title_lines = _wrap_text(title, title_font, TEXT_AREA_WIDTH, draw)
    for _sz in _title_sizes[1:]:
        if len(title_lines) > 5:
            title_font = _get_font(font_style, "title", _sz)
            title_lines = _wrap_text(title, title_font, TEXT_AREA_WIDTH, draw)
        else:
            break
    title_size = title_font.size
    for line in title_lines:          # satır sınırı yok — tüm satırlar çizilir
        draw.text((PADDING, y_cursor), line, font=title_font, fill=TEXT_COLOR)
        y_cursor += title_size + 6

    # Altın çizgi
    y_cursor += 10
    draw.rectangle([(PADDING, y_cursor), (PADDING + 160, y_cursor + 3)], fill=ACCENT_COLOR)
    y_cursor += 24

    # --- Body ---
    # • ile başlayan satırlar inline bullet olarak, diğerleri normal paragraf olarak çizilir.
    if summary_body and summary_body.strip():
        paragraphs = [p.strip() for p in summary_body.split("\n") if p.strip()]
        rendered = 0
        for para in paragraphs:
            if rendered >= 10:
                break
            is_bullet = para.startswith("•")
            text = para.lstrip("• ").strip() if is_bullet else para
            font_para = font_bullet if is_bullet else font_body
            size_para = FONT_SIZES["bullet"] if is_bullet else FONT_SIZES["body"]
            indent = 28 if is_bullet else 0
            max_w = TEXT_AREA_WIDTH - indent

            if is_bullet:
                draw.text((PADDING, y_cursor), "-", font=font_bullet, fill=ACCENT_COLOR)

            wrapped = _wrap_text(text, font_para, max_w, draw)
            for line in wrapped:
                if rendered >= 10:
                    break
                draw.text((PADDING + indent, y_cursor), line, font=font_para,
                          fill=BULLET_TEXT_COLOR if is_bullet else BODY_COLOR)
                y_cursor += size_para + 5
                rendered += 1
            y_cursor += 4
        y_cursor += 10

    # --- Bullets (ai_summary'den parse edilenler — custom_text'te boş gelir) ---
    for bullet in bullets[:2]:
        if not bullet.strip():
            continue
        draw.text((PADDING, y_cursor), "-", font=font_bullet, fill=ACCENT_COLOR)
        bullet_lines = _wrap_text(bullet, font_bullet, TEXT_AREA_WIDTH - 20, draw)
        for line in bullet_lines:
            draw.text((PADDING + 20, y_cursor), line, font=font_bullet, fill=BULLET_TEXT_COLOR)
            y_cursor += FONT_SIZES["bullet"] + 4
        y_cursor += 8

    # --- Alt bölüm: ince çizgi + CTA + branding ---
    bottom_y = CANVAS_SIZE[1] - PADDING - 60
    draw.line([(PADDING, bottom_y), (CANVAS_SIZE[0] - PADDING, bottom_y)], fill=(255, 255, 255, 60), width=1)

    # CTA
    cta_short = cta[:70] + "…" if len(cta) > 70 else cta
    draw.text((PADDING, bottom_y + 12), cta_short, font=font_cta, fill=ACCENT_COLOR)

    # Branding sağ alt
    watermark_font = _get_font(font_style, "body", 20)
    wm_text = "LexPost AI"
    wm_bbox = draw.textbbox((0, 0), wm_text, font=watermark_font)
    wm_w = wm_bbox[2] - wm_bbox[0]
    draw.text((CANVAS_SIZE[0] - PADDING - wm_w, bottom_y + 14), wm_text, font=watermark_font, fill=(160, 160, 160))

    # Output as JPEG bytes
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=92, optimize=True)
    return buffer.getvalue()
