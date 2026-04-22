from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.common import UserSnapshot


class PinSetupRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=8)
    display_name: str | None = Field(default=None, max_length=120)


class PinVerifyRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=8)


class AuthPreferencesRequest(BaseModel):
    biometrics_enabled: bool
    discreet_mode: bool
    auto_lock_minutes: int = Field(ge=1, le=60)


class AuthStatusResponse(BaseModel):
    user: UserSnapshot


class PinVerifyResponse(BaseModel):
    valid: bool
    message: str
    user: UserSnapshot | None = None
