import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import date

from app.core.scraper import fetch_gazette_index, _detect_document_type
from app.db.models import DocumentType


def test_detect_document_type_yonetmelik():
    assert _detect_document_type("Sağlık Bakanlığı Yönetmeliği") == DocumentType.YONETMELIK


def test_detect_document_type_teblig():
    assert _detect_document_type("Vergi Usul Kanunu Genel Tebliği") == DocumentType.TEBLIG


def test_detect_document_type_karar():
    assert _detect_document_type("Bakanlar Kurulu Kararı") == DocumentType.KARAR


def test_detect_document_type_unknown():
    assert _detect_document_type("Duyuru Metni") is None


@pytest.mark.asyncio
async def test_fetch_gazette_index_http_error():
    """Should return empty list on HTTP error, not raise."""
    with patch("app.core.scraper.httpx.AsyncClient") as mock_cls:
        mock_client = AsyncMock()
        mock_cls.return_value.__aenter__.return_value = mock_client
        import httpx
        mock_client.get.side_effect = httpx.HTTPStatusError(
            "404", request=MagicMock(), response=MagicMock(status_code=404)
        )
        result = await fetch_gazette_index(date(2025, 1, 1))
        assert result == []
