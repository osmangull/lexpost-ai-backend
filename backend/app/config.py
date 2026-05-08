from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "LexPost"
    app_version: str = "1.0.0"
    debug: bool = False

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str

    # AI
    groq_api_key: str = ""

    # Firebase
    firebase_credentials_path: str = "firebase-credentials.json"

    # Gazette Scraper
    gazette_base_url: str = "https://www.resmigazete.gov.tr"
    scraper_schedule_times: list[str] = ["11:00", "17:00"]
    target_document_types: list[str] = ["Yönetmelik", "Tebliğ", "Karar"]

    # Assets
    fonts_dir: str = "assets/fonts"
    backgrounds_dir: str = "assets/backgrounds"

    # Premium
    promo_code: str = "LEXPOST2024"
    monthly_price: str = "₺149"
    yearly_price: str = "₺999"
    yearly_savings: str = "%44 tasarruf"

    # Bildirim
    notification_title: str = "LexPost"
    notification_body: str = "Günlük gazeten hazır, incelemek ister misin? 📰"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    return Settings()
