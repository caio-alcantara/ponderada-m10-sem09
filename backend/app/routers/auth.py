from fastapi import APIRouter, Depends, status
from fastapi.responses import Response
from supabase import Client
from app.clients.supabase_client import get_supabase
from app.core.security import get_current_user
from app.schemas.auth import SignupIn, LoginIn, RefreshIn, TokenOut, MeOut
import app.services.auth_service as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def signup(data: SignupIn, supabase: Client = Depends(get_supabase)):
    return auth_service.signup(data, supabase)


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, supabase: Client = Depends(get_supabase)):
    return auth_service.login(data, supabase)


@router.post("/refresh", response_model=TokenOut)
def refresh(data: RefreshIn, supabase: Client = Depends(get_supabase)):
    return auth_service.refresh(data.refresh_token, supabase)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    auth_service.logout(current_user["payload"].get("access_token", ""), supabase)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=MeOut)
def me(
    current_user: dict = Depends(get_current_user),
    supabase: Client = Depends(get_supabase),
):
    return auth_service.me(current_user["user_id"], supabase)
