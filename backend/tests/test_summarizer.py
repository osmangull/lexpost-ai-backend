import pytest
from app.core.summarizer import (
    summarize_legal_text_sync,
    _extract_effective_date,
    _extract_articles,
    _tfidf_score,
    _split_sentences,
)

SAMPLE_TEXT = """
MADDE 1 - Bu Yönetmeliğin amacı, aile hekimliği uygulama usul ve esaslarını düzenlemektir.
MADDE 2 - Aile hekimi başına kayıtlı nüfus sayısı en fazla 4000 kişi olarak belirlenmiştir.
MADDE 3 - Bu Yönetmelik 01/07/2026 tarihinde yürürlüğe girer.
Yürürlük: 01/07/2026 tarihinden itibaren uygulanacaktır.
"""

SAMPLE_TITLE = "Aile Hekimliği Uygulama Yönetmeliğinde Değişiklik"


def test_extract_effective_date():
    date = _extract_effective_date(SAMPLE_TEXT)
    assert date is not None
    assert "2026" in date


def test_extract_articles():
    articles = _extract_articles(SAMPLE_TEXT)
    assert len(articles) >= 1
    assert any("aile hekimliği" in a.lower() for a in articles)


def test_tfidf_score_returns_sorted():
    sentences = _split_sentences(SAMPLE_TEXT)
    scored = _tfidf_score(sentences)
    if len(scored) >= 2:
        assert scored[0][0] >= scored[1][0]


def test_summarize_output_format():
    summary = summarize_legal_text_sync(SAMPLE_TITLE, SAMPLE_TEXT, "Yönetmelik")
    assert "**" in summary          # başlık
    assert "•" in summary           # maddeler
    assert "⚖️" in summary          # CTA
    assert SAMPLE_TITLE[:30] in summary


def test_summarize_empty_content():
    """Boş içerikle çökmemeli."""
    summary = summarize_legal_text_sync("Test Başlığı", "", "Karar")
    assert "**Test Başlığı**" in summary
    assert "•" in summary


@pytest.mark.asyncio
async def test_summarize_async_wrapper():
    from app.core.summarizer import summarize_legal_text
    summary = await summarize_legal_text(SAMPLE_TITLE, SAMPLE_TEXT, "Yönetmelik")
    assert "**" in summary
