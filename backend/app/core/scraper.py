"""
Official Gazette (Resmi Gazete) scraper.
Targets: Yönetmelik, Tebliğ, Karar
Schedule: 11:00 and 17:00 TRT (UTC+3)
"""

import logging
from datetime import date, datetime
from typing import Optional

import httpx
from bs4 import BeautifulSoup
import fitz  # PyMuPDF

from app.config import get_settings
from app.db.models import DocumentType
from app.schemas.gazette import LegalUpdateCreate

logger = logging.getLogger(__name__)
settings = get_settings()

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Cache-Control": "max-age=0",
}

DOCUMENT_TYPE_KEYWORDS: dict[str, DocumentType] = {
    "Yönetmelik": DocumentType.YONETMELIK,
    "Tebliğ": DocumentType.TEBLIG,
    "Karar": DocumentType.KARAR,
}


def _detect_document_type(title: str) -> Optional[DocumentType]:
    for keyword, doc_type in DOCUMENT_TYPE_KEYWORDS.items():
        if keyword.lower() in title.lower():
            return doc_type
    return None


async def fetch_gazette_index(target_date: Optional[date] = None) -> list[LegalUpdateCreate]:
    """Fetch and parse the Official Gazette fihrist page for a given date."""
    target_date = target_date or date.today()
    date_str = target_date.strftime("%Y-%m-%d")
    url = f"{settings.gazette_base_url}/fihrist?tarih={date_str}"

    logger.info(f"Scraping gazette for date: {target_date} | URL: {url}")
    updates: list[LegalUpdateCreate] = []

    async with httpx.AsyncClient(headers=HEADERS, timeout=30.0, follow_redirects=True) as client:
        try:
            response = await client.get(url)
            response.raise_for_status()
            response.encoding = "utf-8"
        except httpx.HTTPStatusError as e:
            logger.warning(f"HTTP error fetching gazette index: {e.response.status_code} | {url}")
            return updates
        except httpx.RequestError as e:
            logger.error(f"Network error fetching gazette: {e}")
            return updates

        soup = BeautifulSoup(response.text, "lxml")
        gazette_number = _extract_gazette_number(soup)

        # Resmi Gazete fihrist sayfası yapısı:
        #   <div class="html-subtitle"> YÖNETMELİKLER </div>
        #   <div class="fihrist-item"><a href="...eskiler...">Başlık</a></div>
        # html-subtitle'dan bölüm tipini alıp altındaki fihrist-item'lara uyguluyoruz.

        SECTION_TYPE_MAP = {
            "yönetmelik": DocumentType.YONETMELIK,
            "tebliğ": DocumentType.TEBLIG,
            "karar": DocumentType.KARAR,
        }

        html_content = soup.find(id="html-content") or soup
        current_section_type: Optional[DocumentType] = None

        for div in html_content.find_all("div"):
            cls = " ".join(div.get("class", []))

            # Bölüm başlığı — tipi güncelle
            if "html-subtitle" in cls:
                text = div.get_text(strip=True).lower()
                for keyword, doc_type in SECTION_TYPE_MAP.items():
                    if keyword in text:
                        current_section_type = doc_type
                        break
                else:
                    current_section_type = None
                continue

            # Belge satırı
            if "fihrist-item" not in cls:
                continue

            link = div.find("a", href=True)
            if not link:
                continue
            href = link["href"]
            if "eskiler" not in href or "ilanlar" in href:
                continue

            title = link.get_text(strip=True).lstrip("–- ").strip()
            if not title or len(title) < 10:
                continue

            # Başlıktan tip bul, yoksa bölüm tipini kullan
            doc_type = _detect_document_type(title) or current_section_type
            if not doc_type:
                continue

            source_url = href if href.startswith("http") else f"{settings.gazette_base_url}{href}"

            updates.append(
                LegalUpdateCreate(
                    title=title,
                    document_type=doc_type,
                    gazette_date=target_date,
                    gazette_number=gazette_number,
                    source_url=source_url,
                )
            )
            logger.debug(f"Found [{doc_type.value}]: {title[:80]}")

    logger.info(f"Scraped {len(updates)} relevant updates for {target_date}")
    return updates


def _extract_gazette_number(soup: BeautifulSoup) -> str:
    """Gazete sayısını sayfadan çıkar."""
    import re
    try:
        full_text = soup.get_text(" ")

        # 1. "33194 Sayılı" formatı (sayı önce gelir)
        m = re.search(r'\b(\d{5})\s+Sayılı', full_text)
        if m:
            return m.group(1)

        # 2. "Sayı : 33194" veya "Sayı: 33194" formatı (sayı sonra gelir)
        m = re.search(r'Sayı\s*[:\-]?\s*(\d{4,5})', full_text)
        if m:
            return m.group(1)

        # 3. Title tag içinde 5 haneli sayı
        title_tag = soup.find("title")
        if title_tag:
            m = re.search(r'\b(\d{5})\b', title_tag.get_text())
            if m:
                return m.group(1)

        # 4. eskiler link URL'inden çek: /eskiler/2026/03/33194.htm
        for link in soup.find_all("a", href=True):
            href = link["href"]
            m = re.search(r'/(\d{5})(?:\.htm|/)', href)
            if m:
                return m.group(1)

        # 5. Herhangi bir tag içinde tek başına 5 haneli sayı
        for tag in soup.find_all(["h1", "h2", "h3", "strong", "b", "p", "td", "th", "div", "span"]):
            direct_text = tag.get_text(strip=True)
            if re.fullmatch(r'\d{5}', direct_text):
                return direct_text

    except Exception:
        pass
    return "N/A"


async def extract_pdf_text(pdf_url: str) -> Optional[str]:
    """Download and extract text from a gazette PDF using PyMuPDF."""
    logger.info(f"Extracting PDF: {pdf_url}")
    async with httpx.AsyncClient(headers=HEADERS, timeout=60.0) as client:
        try:
            response = await client.get(pdf_url)
            response.raise_for_status()
        except (httpx.HTTPStatusError, httpx.RequestError) as e:
            logger.error(f"Failed to download PDF {pdf_url}: {e}")
            return None

    try:
        doc = fitz.open(stream=response.content, filetype="pdf")
        text_parts = [page.get_text("text") for page in doc]
        doc.close()
        full_text = "\n".join(text_parts).strip()
        return full_text if full_text else None
    except Exception as e:
        logger.error(f"PyMuPDF extraction failed for {pdf_url}: {e}")
        return None
