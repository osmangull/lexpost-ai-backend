"""
One-time fix script:
1. Re-fetches gazette number for records where gazette_number = 'N/A'
2. Re-generates AI summary for all records using the fixed summarizer
"""
import asyncio
import sys
import os
import re

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

import httpx
from bs4 import BeautifulSoup
from supabase import create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

db = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

GAZETTE_BASE_URL = "https://www.resmigazete.gov.tr"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "tr-TR,tr;q=0.9",
}


def extract_gazette_number_from_soup(soup: BeautifulSoup) -> str:
    """Extract gazette number from fihrist page."""
    try:
        full_text = soup.get_text(" ")

        # "33194 Sayılı" format
        m = re.search(r'\b(\d{5})\s+Sayılı', full_text)
        if m:
            return m.group(1)

        # "Sayı : 33194" format
        m = re.search(r'Sayı\s*[:\-]?\s*(\d{4,5})', full_text)
        if m:
            return m.group(1)

        # Title tag
        title_tag = soup.find("title")
        if title_tag:
            m = re.search(r'\b(\d{5})\b', title_tag.get_text())
            if m:
                return m.group(1)

        # eskiler link URL
        for link in soup.find_all("a", href=True):
            href = link["href"]
            m = re.search(r'/(\d{5})(?:\.htm|/)', href)
            if m:
                return m.group(1)

    except Exception as e:
        print(f"  Error extracting number: {e}")
    return "N/A"


async def fetch_gazette_number_for_date(date_str: str) -> str:
    url = f"{GAZETTE_BASE_URL}/fihrist?tarih={date_str}"
    async with httpx.AsyncClient(headers=HEADERS, timeout=30.0, follow_redirects=True) as client:
        try:
            response = await client.get(url)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, "lxml")
            return extract_gazette_number_from_soup(soup)
        except Exception as e:
            print(f"  Failed to fetch {url}: {e}")
            return "N/A"


def regenerate_summary(title: str, raw_content: str, document_type: str):
    """Re-generate summary using fixed summarizer."""
    try:
        from app.core.summarizer import summarize_legal_text_sync
        return summarize_legal_text_sync(title, raw_content, document_type)
    except Exception as e:
        print(f"  Summarization error: {e}")
        return None


async def main():
    print("Fetching all records from Supabase...")
    result = db.table("legal_updates").select("id, title, document_type, gazette_date, gazette_number, raw_content, ai_summary").execute()
    records = result.data
    print(f"Found {len(records)} records.\n")

    # Group N/A records by date to minimize HTTP requests
    date_to_number: dict[str, str] = {}
    na_records = [r for r in records if r.get("gazette_number") in (None, "N/A", "")]

    print(f"== STEP 1: Fix gazette numbers ({len(na_records)} records with N/A) ==")
    unique_dates = list({r["gazette_date"] for r in na_records})
    for d in unique_dates:
        print(f"  Fetching gazette number for {d}...")
        num = await fetch_gazette_number_for_date(d)
        date_to_number[d] = num
        print(f"  -> {num}")
        await asyncio.sleep(1)  # be polite

    for record in na_records:
        d = record["gazette_date"]
        num = date_to_number.get(d, "N/A")
        if num != "N/A":
            db.table("legal_updates").update({"gazette_number": num}).eq("id", record["id"]).execute()
            print(f"  Updated gazette_number={num} for: {record['title'][:60]}")

    print(f"\n== STEP 2: Regenerate summaries for all {len(records)} records ==")
    updated = 0
    for record in records:
        raw = record.get("raw_content")
        if not raw:
            print(f"  SKIP (no raw_content): {record['title'][:60]}")
            continue
        new_summary = regenerate_summary(record["title"], raw, record["document_type"])
        if new_summary:
            db.table("legal_updates").update({"ai_summary": new_summary}).eq("id", record["id"]).execute()
            updated += 1
            print(f"  ✓ {record['title'][:60]}")
        else:
            print(f"  ✗ Failed: {record['title'][:60]}")

    print(f"\nDone. Updated {updated}/{len(records)} summaries.")


if __name__ == "__main__":
    asyncio.run(main())
