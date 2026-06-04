from pydantic import BaseModel, EmailStr


class SignupIn(BaseModel):
    name: str
    email: EmailStr
    password: str


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class UserOut(BaseModel):
    id: str
    email: str
    name: str | None = None
    created_at: str | None = None


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class MeOut(BaseModel):
    id: str
    email: str
    name: str | None = None
    created_at: str | None = None
