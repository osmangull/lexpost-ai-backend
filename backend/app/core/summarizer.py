"""
Hibrit Özetleyici: Kural Tabanlı + TF-IDF
- Kural tabanlı: Resmi Gazete'nin sabit yapısından (MADDE, yürürlük, kurum) bilgi çeker
- TF-IDF: En önemli cümleleri matematiksel olarak puanlayarak seçer
- Harici AI API gerektirmez, tamamen offline çalışır
"""

import logging
import math
import re
from collections import Counter
from typing import Optional

logger = logging.getLogger(__name__)


# PDF imza/başlık blokları — bunlar içerik değil, meta bilgi
_JUNK_PATTERNS = [
    re.compile(r'cumhurbaşkan[ıi]\s+karar[ıi]', re.IGNORECASE),
    re.compile(r'recep\s+tayyip\s+erdo[ğg]an', re.IGNORECASE),
    re.compile(r'^(bakanlar\s+kurulu|resm[iî]\s+gazete|t\.c\.\s+cumhurbaşkanlığı)', re.IGNORECASE),
    re.compile(r'karar\s+say[ıi]s[ıi]\s*:\s*\d+\s*$', re.IGNORECASE),
    re.compile(r'^sayfa\s+\d+', re.IGNORECASE),
    re.compile(r'^\d+\s*/\s*\d+$'),  # sayfa numarası "1 / 5"
]


def _clean_text(text: str) -> str:
    """
    PDF'den gelen ham metni temizle.
    - Harf oranı düşük satırları at
    - Büyük harfli başlık/imza bloklarını at
    - İzole sembolleri temizle
    """
    lines = []
    for line in text.splitlines():
        line = line.strip()
        if not line or len(line) < 4:
            continue

        letters = sum(1 for c in line if c.isalpha())
        if len(line) > 5 and letters / len(line) < 0.40:
            continue

        # Bilinen junk kalıplarını at
        if any(p.search(line) for p in _JUNK_PATTERNS):
            continue

        # Çok kısa ve tamamen büyük harf → başlık/imza bloğu, at
        upper = sum(1 for c in line if c.isupper())
        if letters > 0 and upper / letters > 0.75 and len(line) < 80:
            continue

        # Satır içi izole sembolleri temizle
        line = re.sub(r'(?<!\w)[^\w\s\-\(\)\.,;:\'\"]{1,3}(?!\w)', ' ', line)
        line = re.sub(r'\s+', ' ', line).strip()
        if len(line) < 4:
            continue
        lines.append(line)

    clean = " ".join(lines)
    clean = re.sub(r'\s+', ' ', clean).strip()
    return clean


def _is_clean_sentence(sent: str, title: str) -> bool:
    """Cümlenin kaliteli olup olmadığını kontrol et."""
    if not sent or len(sent) < 20:
        return False

    # Sembol/rakam oranı çok yüksekse bozuk
    letters = sum(1 for c in sent if c.isalpha())
    if letters / len(sent) < 0.55:
        return False

    # Büyük harf oranı >%60 → imza/başlık bloğu
    upper = sum(1 for c in sent if c.isupper())
    if letters > 0 and upper / letters > 0.60:
        return False

    # Bilinen junk kalıpları
    if any(p.search(sent) for p in _JUNK_PATTERNS):
        return False

    # Başlıkla çok benzer (tekrar) → reddet
    title_words = set(_tokenize(title))
    sent_words = set(_tokenize(sent))
    if title_words and len(title_words & sent_words) / len(title_words) > 0.50:
        return False

    return True


def _title_to_summary(title: str, document_type: str) -> str:
    """
    Başlıktan anlamlı bir özet cümlesi türet.
    PDF içeriği yetersizse kullanılır.
    Türkçe ek ekleme yapmaz — sabit kalıplar kullanır.
    """
    t = title.upper()

    # 1. Yürürlükten kaldırma
    if "YÜRÜRLÜKTEN KALDIR" in t:
        return f"Bu {document_type}, ilgili mevzuatı yürürlükten kaldırmaktadır."

    # 2. Değişiklik
    if "DEĞİŞİKLİK" in t:
        return f"Bu {document_type}, mevcut düzenlemeye değişiklik getirmektedir."

    # 3. Fiyatlandırma
    if "FİYATLANDIRMA" in t or "ÜCRET" in t:
        return f"Bu {document_type}, ilgili ürün veya hizmetlerin fiyatlandırılmasına ilişkin hüküm içermektedir."

    # 4. Kamulaştırma / enerji
    if "KAMULAŞTIRMA" in t or "ENERJİ" in t or "PETROL" in t:
        return f"Bu {document_type}, kamulaştırma ve enerji altyapısına ilişkin düzenleme içermektedir."

    # 5. Personel / İnsan kaynakları / istihdam
    if "PERSONEL" in t or "İNSAN KAYNAKLARI" in t or "İSTİHDAM" in t or "UZMAN" in t:
        return f"Bu {document_type}, personel istihdamı ve çalışma esaslarına ilişkin hüküm içermektedir."

    # 6. Özelleştirme
    if "ÖZELLEŞTİRME" in t:
        return f"Bu {document_type}, özelleştirme kapsamında alınan kararları içermektedir."

    # 7. İthalat / ihracat / ticaret
    if "İTHALAT" in t or "İHRACAT" in t or "TİCARET" in t:
        return f"Bu {document_type}, ithalat/ihracat uygulamalarına ilişkin düzenleme getirmektedir."

    # 8. Eğitim / öğretim
    if "EĞİTİM" in t or "ÖĞRETİM" in t or "OKUL" in t:
        return f"Bu {document_type}, eğitim ve öğretim alanında düzenleme içermektedir."

    # 9. "X Yönetmeliği / Tebliği" → X alanında düzenleme
    clean = re.sub(r'\s*\([^)]{0,50}\)', '', title).strip()
    m = re.match(r'(.{10,60}?)\s+(?:Yönetmeliği|Tebliği|Kararı)\s*$', clean, re.IGNORECASE)
    if m:
        konu = m.group(1).strip()
        return f"Bu {document_type}, {konu} alanında düzenleme içermektedir."

    # 10. "X İlişkin / X Hakkında / X Dair" → konuyu al
    m = re.search(r'(.{5,50}?)\s+(?:İlişkin|Hakkında|Dair)\b', clean, re.IGNORECASE)
    if m:
        konu = m.group(1).strip().lstrip('–- ')
        if len(konu) >= 5:
            return f"Bu {document_type}, {konu} konusunda düzenleme getirmektedir."

    # 11. Genel fallback
    return f"Bu {document_type}, Resmi Gazete'de yayımlanmıştır. Tam metin için kaynağa başvurun."


# ── Türkçe stop words ─────────────────────────────────────────────────────────
TR_STOPWORDS = {
    "ve", "ile", "de", "da", "ki", "bu", "bir", "için", "olan",
    "olarak", "veya", "ya", "gibi", "kadar", "daha", "en", "her",
    "çok", "az", "ise", "ancak", "ayrıca", "fakat", "ama", "üzere", "göre",
    "olup", "olduğu", "edilmiş", "edilmekte", "yapılmış", "söz",
    "konusu", "ilgili", "hakkında", "ilişkin", "tarihli", "sayılı", "madde",
    "fıkra", "bent", "hüküm", "kapsamında", "çerçevesinde", "itibarıyla",
    "müddetçe", "itibaren", "başlamak", "olmak", "bulunmak",
}

YURURLUK_PATTERNS = [
    r"(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{4})\s*(?:tarihinde|tarihinden itibaren|itibarıyla)?\s*(?:yürürlüğe)",
    r"yürürlük.*?(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{4})",
    r"(\d{1,2}\s+\w+\s+\d{4})\s*(?:tarihinde|tarihinden)",
    r"Bu\s+(?:Yönetmelik|Tebliğ|Karar).*?(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{4})",
]

KURUM_PATTERNS = [
    r"^(.{5,60}(?:Bakanlığı|Kurumu|Kurulu|Başkanlığı|Müsteşarlığı|İdaresi|Ajansı))",
    r"(.{5,60}(?:Bakanlığı|Kurumu|Kurulu|Başkanlığı))\s+tarafından",
]

CTA_TEMPLATES = {
    "Yönetmelik": [
        "Uyum süreci için yönetmelik maddelerini inceleyin.",
        "İlgili uygulama usullerini ve geçiş hükümlerini değerlendirin.",
        "Mesleki yükümlülükler açısından değişiklikleri takip edin.",
    ],
    "Tebliğ": [
        "Müvekkil portföyünüzü bu düzenleme çerçevesinde değerlendirin.",
        "Vergi ve idari yükümlülükler için tebliği yakından takip edin.",
        "Uygulama tarihlerine dikkat ederek gerekli bildirimleri yapın.",
    ],
    "Karar": [
        "İlgili emsal kararları ile birlikte değerlendirin.",
        "Müvekkillerinizi bu karar doğrultusunda bilgilendirin.",
        "İdari ve hukuki sonuçları için uzman görüşü alın.",
    ],
}


def _split_sentences(text: str) -> list[str]:
    text = re.sub(r'\s+', ' ', text).strip()
    sentences = re.split(r'(?<=[.!?])\s+(?=[A-ZÇĞİÖŞÜa-z])', text)
    return [s.strip() for s in sentences if len(s.strip()) > 30]


def _tokenize(text: str) -> list[str]:
    words = re.findall(r'[a-zA-ZçğıöşüÇĞİÖŞÜ]{3,}', text.lower())
    return [w for w in words if w not in TR_STOPWORDS]


def _tfidf_score(sentences: list[str]) -> list[tuple[float, str]]:
    if not sentences:
        return []

    sentence_words = []
    for sent in sentences:
        sentence_words.append(_tokenize(sent))

    total_sentences = len(sentences)
    doc_freq = Counter()
    for words in sentence_words:
        for w in set(words):
            doc_freq[w] += 1

    idf = {
        w: math.log((total_sentences + 1) / (freq + 1)) + 1
        for w, freq in doc_freq.items()
    }

    scored = []
    for i, (sent, words) in enumerate(zip(sentences, sentence_words)):
        if not words:
            scored.append((0.0, sent))
            continue
        tf = Counter(words)
        score = sum(tf[w] * idf.get(w, 1.0) for w in words) / len(words)
        if i == 0:
            score *= 1.3
        scored.append((score, sent))

    return sorted(scored, key=lambda x: x[0], reverse=True)


def _extract_effective_date(text: str) -> Optional[str]:
    for pattern in YURURLUK_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    return None


def _extract_institution(title: str, text: str) -> Optional[str]:
    for pattern in KURUM_PATTERNS:
        match = re.search(pattern, title, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    for pattern in KURUM_PATTERNS:
        match = re.search(pattern, text[:500], re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return None


def _extract_articles(text: str) -> list[str]:
    articles = []
    pattern = r'MADDE\s+\d+\s*[–\-—]?\s*\(?\d*\)?\s*(.{40,200}?)(?=MADDE\s+\d+|$)'
    matches = re.findall(pattern, text, re.IGNORECASE | re.DOTALL)
    for m in matches[:3]:
        clean = re.sub(r'\s+', ' ', m).strip()
        if len(clean) > 40:
            articles.append(clean[:150])
    return articles


def _strip_madde_prefix(text: str) -> str:
    """'MADDE 1 –' veya 'MADDE 2 ' gibi ön ekleri kaldır."""
    return re.sub(r'^MADDE\s+\d+\s*[–\-—:.]?\s*', '', text, flags=re.IGNORECASE).strip()


def _build_body(scored: list[tuple[float, str]], title: str, document_type: str) -> Optional[str]:
    """
    En yüksek puanlı, kaliteli cümleyi seç.
    Hiç kaliteli cümle yoksa None döndür (fallback içerik üretme).
    """
    for score, sent in scored:
        if _is_clean_sentence(sent, title):
            clean = _strip_madde_prefix(sent)
            if len(clean) > 160:
                cut = clean[:160].rsplit(' ', 1)[0]
                return cut + "."
            return clean

    return None


def _build_bullets(
    articles: list[str],
    scored: list[tuple[float, str]],
    effective_date: Optional[str],
    title: str,
    document_type: str = "Karar",
) -> list[str]:
    """2 madde noktası oluştur."""
    bullets = []

    # MADDE içeriklerinden al (başlıkla benzer olmayanlar)
    for article in articles[:2]:
        trimmed = _strip_madde_prefix(article)[:120]
        if trimmed not in bullets and _is_clean_sentence(trimmed, title):
            bullets.append(trimmed)

    # TF-IDF'ten tamamla (body'de kullanılmayan cümleler)
    for score, sent in scored[1:]:
        if len(bullets) >= 2:
            break
        trimmed = sent[:120]
        if trimmed not in bullets and _is_clean_sentence(trimmed, title):
            bullets.append(trimmed)

    # Yürürlük tarihi varsa bir bullet olarak ekle
    if effective_date:
        yururluk = f"Yürürlük tarihi: {effective_date}"
        if len(bullets) >= 2:
            bullets[-1] = yururluk
        else:
            bullets.append(yururluk)

    # Belge tipine özgü anlamlı fallback'ler
    doc_fallbacks = {
        "Yönetmelik": ["Uygulama usulleri ve geçiş hükümleri incelenmelidir.", "Yönetmelik kapsamındaki yükümlülükler değerlendirilmelidir."],
        "Tebliğ": ["İdari yükümlülükler ve uygulama tarihleri kontrol edilmelidir.", "Müvekkillerin bu tebliğden etkilenip etkilenmediği değerlendirilmelidir."],
        "Karar": ["Kararın hukuki sonuçları ve etkileri incelenmelidir.", "İlgili mevzuat kapsamında değerlendirilmesi önerilir."],
    }
    fallbacks = doc_fallbacks.get(document_type, doc_fallbacks["Karar"])
    while len(bullets) < 2:
        bullets.append(fallbacks[len(bullets) % 2])

    return bullets[:2]


def _build_cta(document_type: str, institution: Optional[str]) -> str:
    templates = CTA_TEMPLATES.get(document_type, CTA_TEMPLATES["Karar"])
    cta = templates[hash(institution or document_type) % len(templates)]
    return cta


def summarize_legal_text_sync(title: str, raw_content: str, document_type: str = "Karar") -> str:
    """
    Hibrit kural tabanlı + TF-IDF özetleyici.
    Özet başlığı TEKRAR ETMEZ — iOS UI'da başlık zaten gösterilir.
    """
    text = _clean_text(raw_content)[:5000]

    effective_date = _extract_effective_date(text)
    institution = _extract_institution(title, text)
    articles = _extract_articles(text)

    sentences = _split_sentences(text)
    scored = _tfidf_score(sentences)

    body = _build_body(scored, title, document_type)
    if body is None:
        # PDF içeriği yetersiz — başlıktan kural tabanlı özet üret
        logger.info(f"İçerik yetersiz, başlıktan özet üretiliyor: '{title[:50]}'")
        return _title_to_summary(title, document_type)

    bullets = _build_bullets(articles, scored, effective_date, title, document_type)
    cta = _build_cta(document_type, institution)

    summary = f"{body}\n• {bullets[0]}\n• {bullets[1]}\n⚖️ Not: {cta}"

    logger.info(f"Özet üretildi: '{title[:50]}' ({len(summary.split())} kelime)")
    return summary


async def summarize_legal_text(title: str, raw_content: str, document_type: str = "Karar") -> str:
    """Groq ile özet üret. Başarısız olursa TF-IDF fallback'e geç."""
    from app.config import get_settings
    settings = get_settings()

    if settings.groq_api_key:
        try:
            result = await _summarize_with_groq(title, raw_content, document_type, settings.groq_api_key)
            if result:
                return result
        except Exception as e:
            logger.warning(f"Groq summarization failed, falling back to TF-IDF: {e}")

    return summarize_legal_text_sync(title, raw_content, document_type)


async def _summarize_with_groq(title: str, raw_content: str, document_type: str, api_key: str) -> str:
    """Groq API ile Türkçe hukuki özet üret."""
    import re as _re
    from groq import AsyncGroq

    content_preview = raw_content[:3000].strip()

    prompt = f"""Türk Resmi Gazetesi'nde yayımlanan aşağıdaki {document_type} belgesini avukatlar için kısaca özetle.

Başlık: {title}

Belge içeriği:
{content_preview}

Yanıtın tam olarak şu yapıda olsun — köşeli parantez, yıldız işareti veya başka işaret KULLANMA, sadece düz metin yaz:

Tek cümlelik özet — belgenin ne hakkında olduğunu açık şekilde ifade et.
• İlk önemli madde veya etki (tek cümle)
• İkinci önemli madde veya etki (tek cümle)
⚖️ Not: Bu belgeyle ilgili dikkat edilmesi gereken pratik husus (tek cümle)

Kurallar: Türkçe yaz. Gerçek içeriğe dayan. Köşeli parantez veya markdown kullanma."""

    client = AsyncGroq(api_key=api_key)
    response = await client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,
        max_tokens=300,
    )

    result = response.choices[0].message.content.strip()

    # Kalan şablon kalıplarını temizle
    result = _re.sub(r'\[.*?\]', '', result)          # [köşeli parantez içi]
    result = _re.sub(r'\*\*.*?\*\*', '', result)       # **kalın**
    result = _re.sub(r'\*([^*]+)\*', r'\1', result)    # *italik*
    result = _re.sub(r'^\s*#+\s*', '', result, flags=_re.MULTILINE)  # ## başlık
    result = _re.sub(r'\n{3,}', '\n\n', result)
    result = result.strip()

    if not result:
        return ""

    logger.info(f"Groq özet üretildi: '{title[:50]}'")
    return result


async def generate_social_caption(summary: str, document_type: str) -> str:
    """Özetten sosyal medya caption'ı üret (kural tabanlı)."""
    lines = [l.strip() for l in summary.splitlines() if l.strip()]
    first_line = lines[0] if lines else "Hukuki Güncelleme"
    # Caption için başlık ayrıca gerekli — summary artık başlık içermiyor
    emoji = {"Yönetmelik": "📋", "Tebliğ": "📢", "Karar": "⚖️"}.get(document_type, "📄")
    return f"{emoji} {first_line} | Resmi Gazete'de yayımlandı. Detaylar için profilimizdeki bağlantıya göz atın."
