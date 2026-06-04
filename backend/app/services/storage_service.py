import uuid
import httpx
from supabase import Client
from app.config import settings

_STORAGE_HEADERS = {
    "apikey": settings.supabase_service_role_key,
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
}
_STORAGE_BASE = f"{settings.supabase_url}/storage/v1"


def upload(user_id: str, file_bytes: bytes, content_type: str, supabase: Client) -> str:
    ext = "jpg"
    if content_type == "image/png":
        ext = "png"
    elif content_type == "image/webp":
        ext = "webp"

    filename = f"{user_id}/{uuid.uuid4()}.{ext}"
    url = f"{_STORAGE_BASE}/object/{settings.supabase_bucket}/{filename}"
    resp = httpx.post(
        url,
        headers={**_STORAGE_HEADERS, "Content-Type": content_type},
        content=file_bytes,
        timeout=30,
    )
    resp.raise_for_status()
    return filename


def get_signed_url(path: str, supabase: Client, expires_in: int = 3600) -> str:
    try:
        url = f"{_STORAGE_BASE}/object/sign/{settings.supabase_bucket}/{path}"
        resp = httpx.post(
            url,
            headers={**_STORAGE_HEADERS, "Content-Type": "application/json"},
            json={"expiresIn": expires_in},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        signed = data.get("signedURL") or data.get("signedUrl") or ""
        if signed and signed.startswith("/"):
            signed = f"{settings.supabase_url}/storage/v1{signed}"
        return signed
    except Exception:
        return ""


def delete(path: str, supabase: Client) -> None:
    url = f"{_STORAGE_BASE}/object/{settings.supabase_bucket}"
    httpx.delete(
        url,
        headers={**_STORAGE_HEADERS, "Content-Type": "application/json"},
        json={"prefixes": [path]},
        timeout=10,
    )
