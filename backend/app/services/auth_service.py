from fastapi import HTTPException, status
from supabase import Client
from app.schemas.auth import SignupIn, LoginIn, TokenOut, UserOut, MeOut


def _build_token_out(session, name: str | None = None) -> TokenOut:
    user = session.user
    return TokenOut(
        access_token=session.session.access_token,
        refresh_token=session.session.refresh_token,
        user=UserOut(
            id=str(user.id),
            email=user.email or "",
            name=name,
            created_at=str(user.created_at) if user.created_at else None,
        ),
    )

def signup(data: SignupIn, supabase: Client) -> TokenOut:
    try:
        result = supabase.auth.sign_up(
            {"email": data.email, "password": data.password}
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    # Supabase retorna user sem identities quando o e-mail já está cadastrado
    if result.user and not result.user.identities:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este e-mail já está cadastrado.",
        )

    if not result.session:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sessão não retornada. Desative 'Confirm email' no Supabase (Authentication → Settings).",
        )

    user_id = str(result.user.id)

    try:
        supabase.table("profiles").insert(
            {"id": user_id, "name": data.name}
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Usuário criado no Auth, mas falha ao salvar perfil: {exc}",
        ) from exc

    return _build_token_out(result, name=data.name)

def login(data: LoginIn, supabase: Client) -> TokenOut:
    try:
        result = supabase.auth.sign_in_with_password(
            {"email": data.email, "password": data.password}
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Credenciais inválidas: {exc}",
        ) from exc

    if not result.session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Falha ao criar sessão.",
        )

    profile = (
        supabase.table("profiles")
        .select("name")
        .eq("id", str(result.user.id))
        .single()
        .execute()
    )
    name = profile.data.get("name") if profile.data else None

    return _build_token_out(result, name=name)


def refresh(refresh_token: str, supabase: Client) -> TokenOut:
    try:
        result = supabase.auth.refresh_session(refresh_token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido ou expirado.",
        ) from exc

    if not result.session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Não foi possível renovar a sessão.",
        )

    profile = (
        supabase.table("profiles")
        .select("name")
        .eq("id", str(result.user.id))
        .single()
        .execute()
    )
    name = profile.data.get("name") if profile.data else None

    return _build_token_out(result, name=name)


def logout(access_token: str, supabase: Client) -> None:
    try:
        supabase.auth.sign_out()
    except Exception:
        pass


def me(user_id: str, supabase: Client) -> MeOut:
    try:
        profile = (
            supabase.table("profiles")
            .select("id, name, created_at")
            .eq("id", user_id)
            .single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Perfil não encontrado.",
        ) from exc

    data = profile.data or {}

    auth_user = supabase.auth.admin.get_user_by_id(user_id)
    email = auth_user.user.email if auth_user and auth_user.user else ""

    return MeOut(
        id=data.get("id", user_id),
        email=email,
        name=data.get("name"),
        created_at=str(data.get("created_at", "")),
    )
