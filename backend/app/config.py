from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "LexPost AI"
    app_version: str = "1.0.0"
    debug: bool = False

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str

    # Firebase
    firebase_credentials_path: str = "firebase-credentials.json"

    # Gazette Scraper
    gazette_base_url: str = "https://www.resmigazete.gov.tr"
    scraper_schedule_times: list[str] = ["11:00", "17:00"]
    target_document_types: list[str] = ["Yönetmelik", "Tebliğ", "Karar"]

    # Assets
    fonts_dir: str = "assets/fonts"
    backgrounds_dir: str = "assets/backgrounds"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    return Settings()
