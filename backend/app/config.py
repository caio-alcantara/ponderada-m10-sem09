from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_jwt_secret: str
    supabase_bucket: str = "skin-photos"

    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"

    backend_cors_origins: str = "*"
    env: str = "dev"


settings = Settings()
