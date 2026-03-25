import pytest
from unittest.mock import patch, MagicMock
from app.services.image_service import _parse_summary_parts


def test_parse_summary_parts_full():
    summary = """**Sağlık Yönetmeliği Güncellendi**
Aile hekimliği yönetmeliği kapsamlı değişikliklerle yeniden düzenlendi.
• Hekim başına düşen hasta kotası artırıldı
• Hizmet standartları güncellendi
⚖️ Avukatlar için not: İdare hukukunda yeni düzenlemeyi inceleyin."""

    title, body, bullets, cta = _parse_summary_parts(summary)

    assert "Sağlık" in title
    assert len(bullets) == 2
    assert "kota" in bullets[0].lower() or "standart" in bullets[1].lower()
    assert "incel" in cta.lower()


def test_parse_summary_parts_minimal():
    """Should not crash on minimal input."""
    title, body, bullets, cta = _parse_summary_parts("Kısa başlık")
    assert title == "Kısa başlık"
    assert len(bullets) == 2  # padded to 2


def test_parse_summary_parts_empty():
    """Empty string falls back to defaults."""
    title, body, bullets, cta = _parse_summary_parts("")
    assert title == "Hukuki Güncelleme"
    assert len(bullets) == 2
