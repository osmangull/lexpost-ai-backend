from enum import Enum


class DocumentType(str, Enum):
    YONETMELIK = "Yönetmelik"
    TEBLIG = "Tebliğ"
    KARAR = "Karar"


class FontStyle(str, Enum):
    CLASSIC = "classic"   # Playfair Display
    MODERN = "modern"     # Montserrat


class PostStatus(str, Enum):
    DRAFT = "draft"
    GENERATED = "generated"
    SHARED = "shared"
