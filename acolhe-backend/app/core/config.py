from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Acolhe API"
    environment: str = "development"
    api_prefix: str = "/api/v1"
    debug: bool = False
    database_url: str = "sqlite:///./acolhe.db"
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    seed_demo_data: bool = True
    rate_limit_per_minute: int = 45
    llm_enabled: bool = False
    llm_api_key: str | None = None
    llm_base_url: str = "https://api.openai.com/v1"
    llm_model: str = "gpt-4.1-mini"
    llm_timeout_seconds: float = 20.0
    prompt_path: str = "app/prompts/acolhe_system_prompt.md"
    primary_user_name: str = "Usuaria Acolhe"
    primary_user_pin: str = Field(default="2468", min_length=4, max_length=8)

    @property
    def cors_origins_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
