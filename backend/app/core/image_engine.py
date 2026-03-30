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
    badge_text: str = "HUKUK GÜNCELLEMESİ",
    text_color: tuple = (255, 255, 255),
    accent_color: tuple = (212, 175, 55),
    font_size_delta: int = 0,
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
        badge_text: Üst badge metni (ör. kategori)
        text_color: RGB tuple for main text
        accent_color: RGB tuple for lines/bullets/badge
        font_size_delta: Font boyutu ayarı (-4, 0, +6)
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

    d = font_size_delta
    font_title  = _get_font(font_style, "title", FONT_SIZES["title"]  + d)
    font_body   = _get_font(font_style, "body",  FONT_SIZES["body"]   + d)
    font_bullet = _get_font(font_style, "body",  FONT_SIZES["bullet"] + d)
    font_cta    = _get_font(font_style, "body",  FONT_SIZES["cta"]    + d)

    body_color_use   = text_color
    bullet_color_use = tuple(max(0, c - 30) for c in text_color)

    y_cursor = PADDING + 30

    # --- Üst şerit: badge ---
    badge_font = _get_font(font_style, "body", FONT_SIZES["badge"] + d)
    draw.text((PADDING, y_cursor), badge_text.upper(), font=badge_font, fill=accent_color)
    y_cursor += FONT_SIZES["badge"] + d + 16

    # --- Title ---
    _title_sizes = [48 + d, 42 + d, 38 + d, 34 + d, 30 + d]
    title_font = font_title
    title_lines = _wrap_text(title, title_font, TEXT_AREA_WIDTH, draw)
    for _sz in _title_sizes[1:]:
        if len(title_lines) > 5:
            title_font = _get_font(font_style, "title", _sz)
            title_lines = _wrap_text(title, title_font, TEXT_AREA_WIDTH, draw)
        else:
            break
    title_size = title_font.size
    for line in title_lines:
        draw.text((PADDING, y_cursor), line, font=title_font, fill=text_color)
        y_cursor += title_size + 6

    # Vurgu çizgisi
    y_cursor += 10
    draw.rectangle([(PADDING, y_cursor), (PADDING + 160, y_cursor + 3)], fill=accent_color)
    y_cursor += 24

    # --- Body ---
    if summary_body and summary_body.strip():
        paragraphs = [p.strip() for p in summary_body.split("\n") if p.strip()]
        rendered = 0
        for para in paragraphs:
            if rendered >= 10:
                break
            is_bullet = para.startswith("•")
            text_para = para.lstrip("• ").strip() if is_bullet else para
            font_para = font_bullet if is_bullet else font_body
            size_para = FONT_SIZES["bullet"] + d if is_bullet else FONT_SIZES["body"] + d
            indent = 28 if is_bullet else 0
            max_w = TEXT_AREA_WIDTH - indent

            if is_bullet:
                draw.text((PADDING, y_cursor), "-", font=font_bullet, fill=accent_color)

            wrapped = _wrap_text(text_para, font_para, max_w, draw)
            for line in wrapped:
                if rendered >= 10:
                    break
                draw.text((PADDING + indent, y_cursor), line, font=font_para,
                          fill=bullet_color_use if is_bullet else body_color_use)
                y_cursor += size_para + 5
                rendered += 1
            y_cursor += 4
        y_cursor += 10

    # --- Bullets ---
    for bullet in bullets[:2]:
        if not bullet.strip():
            continue
        draw.text((PADDING, y_cursor), "-", font=font_bullet, fill=accent_color)
        bullet_lines = _wrap_text(bullet, font_bullet, TEXT_AREA_WIDTH - 20, draw)
        for line in bullet_lines:
            draw.text((PADDING + 20, y_cursor), line, font=font_bullet, fill=bullet_color_use)
            y_cursor += FONT_SIZES["bullet"] + d + 4
        y_cursor += 8

    # --- Alt bölüm ---
    bottom_y = CANVAS_SIZE[1] - PADDING - 60
    draw.line([(PADDING, bottom_y), (CANVAS_SIZE[0] - PADDING, bottom_y)], fill=(*accent_color, 120), width=1)

    # CTA
    cta_short = cta[:70] + "…" if len(cta) > 70 else cta
    draw.text((PADDING, bottom_y + 12), cta_short, font=font_cta, fill=accent_color)

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
