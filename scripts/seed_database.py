"""
Seed script: Insert 10 default templates into Supabase.
Run: python scripts/seed_database.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

from supabase import create_client

def get_supabase():
    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    return create_client(url, key)

TEMPLATES = [
    # --- Law Theme (4 templates) ---
    {
        "name": "Adalet Sarayı",
        "theme": "law",
        "background_filename": "law_courthouse.jpg",
        "sort_order": 1,
        "is_pro": False,
    },
    {
        "name": "Terazi",
        "theme": "law",
        "background_filename": "law_scales.jpg",
        "sort_order": 2,
        "is_pro": False,
    },
    {
        "name": "Kütüphane",
        "theme": "law",
        "background_filename": "law_library.jpg",
        "sort_order": 3,
        "is_pro": False,
    },
    {
        "name": "Kanun Kitapları",
        "theme": "law",
        "background_filename": "law_books.jpg",
        "sort_order": 4,
        "is_pro": True,
    },
    # --- Office Theme (3 templates) ---
    {
        "name": "Modern Ofis",
        "theme": "office",
        "background_filename": "office_modern.jpg",
        "sort_order": 5,
        "is_pro": False,
    },
    {
        "name": "Ahşap Masa",
        "theme": "office",
        "background_filename": "office_desk.jpg",
        "sort_order": 6,
        "is_pro": False,
    },
    {
        "name": "Şehir Manzarası",
        "theme": "office",
        "background_filename": "office_cityview.jpg",
        "sort_order": 7,
        "is_pro": True,
    },
    # --- Minimalist Theme (3 templates) ---
    {
        "name": "Saf Beyaz",
        "theme": "minimalist",
        "background_filename": "minimal_white.jpg",
        "sort_order": 8,
        "is_pro": False,
    },
    {
        "name": "Lacivert",
        "theme": "minimalist",
        "background_filename": "minimal_navy.jpg",
        "sort_order": 9,
        "is_pro": False,
    },
    {
        "name": "Altın Çizgi",
        "theme": "minimalist",
        "background_filename": "minimal_gold.jpg",
        "sort_order": 10,
        "is_pro": True,
    },
]


def seed():
    db = get_supabase()

    existing = db.table("templates").select("id").execute()
    if existing.data:
        print(f"Templates table already has {len(existing.data)} rows. Skipping seed.")
        return

    result = db.table("templates").insert(TEMPLATES).execute()
    print(f"Seeded {len(result.data)} templates successfully.")
    for t in result.data:
        print(f"  [{t['sort_order']}] {t['name']} ({t['theme']})")


if __name__ == "__main__":
    seed()
