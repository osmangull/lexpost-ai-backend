"""
Supabase Storage kurulumu:
1. 'template-backgrounds' bucket oluştur (public)
2. 'generated-posts' bucket oluştur (private)
3. Arka plan görsellerini yükle
4. Template DB kayıtlarını background_url ile güncelle
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

from pathlib import Path
from supabase import create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
BACKGROUNDS_DIR = Path(__file__).parent.parent / "backend" / "assets" / "backgrounds"

db = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def create_bucket(name: str, public: bool):
    try:
        db.storage.create_bucket(name, options={"public": public})
        print(f"  ✓ Bucket '{name}' oluşturuldu (public={public})")
    except Exception as e:
        err = str(e)
        if "already exists" in err.lower() or "Duplicate" in err or "409" in err:
            print(f"  – Bucket '{name}' zaten var, atlandı")
        else:
            print(f"  ✗ Bucket '{name}' oluşturulamadı: {e}")


def upload_backgrounds():
    """Background görsellerini Supabase Storage'a yükle."""
    templates = db.table("templates").select("id, background_filename, background_url").execute().data
    print(f"\n{len(templates)} template kaydı bulundu.")

    updated = 0
    for tmpl in templates:
        filename = tmpl.get("background_filename")
        if not filename:
            continue

        local_path = BACKGROUNDS_DIR / filename
        if not local_path.exists():
            print(f"  ✗ Dosya bulunamadı: {local_path}")
            continue

        # Upload
        storage_path = filename  # flat path inside bucket
        try:
            with open(local_path, "rb") as f:
                image_bytes = f.read()
            try:
                db.storage.from_("template-backgrounds").upload(
                    path=storage_path,
                    file=image_bytes,
                    file_options={"content-type": "image/jpeg", "upsert": "true"},
                )
            except Exception as e:
                if "already exists" in str(e).lower() or "Duplicate" in str(e):
                    pass  # OK, will still get URL
                else:
                    print(f"  ✗ Upload hatası {filename}: {e}")
                    continue

            # Get public URL
            pub_url = db.storage.from_("template-backgrounds").get_public_url(storage_path)
            print(f"  ✓ {filename} → {pub_url[:70]}...")

            # Update DB
            db.table("templates").update({"background_url": pub_url}).eq("id", tmpl["id"]).execute()
            updated += 1

        except Exception as e:
            print(f"  ✗ {filename}: {e}")

    print(f"\n{updated}/{len(templates)} template güncellendi.")


if __name__ == "__main__":
    print("== ADIM 1: Bucket'ları oluştur ==")
    create_bucket("template-backgrounds", public=True)
    create_bucket("generated-posts", public=True)

    print("\n== ADIM 2: Görselleri yükle ve DB güncelle ==")
    upload_backgrounds()

    print("\nTamamlandı!")
