import httpx
from jose import jwt, JWTError, jwk
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings

bearer_scheme = HTTPBearer()

_jwks_cache: dict | None = None


def _get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is None:
        url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
        resp = httpx.get(url, timeout=10)
        resp.raise_for_status()
        _jwks_cache = resp.json()
    return _jwks_cache


def _get_signing_key(token: str):
    jwks = _get_jwks()
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            return key_data
    return None


def decode_supabase_jwt(token: str) -> dict:
    try:
        header = jwt.get_unverified_header(token)
        alg = header.get("alg", "HS256")

        if alg == "ES256":
            key_data = _get_signing_key(token)
            if not key_data:
                raise JWTError("No matching key found in JWKS")
            payload = jwt.decode(
                token,
                key_data,
                algorithms=["ES256"],
                options={"verify_aud": False},
            )
        else:
            payload = jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido ou expirado.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    payload = decode_supabase_jwt(credentials.credentials)
    user_id: str | None = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sem subject.",
        )
    return {"user_id": user_id, "email": payload.get("email", ""), "payload": payload}
