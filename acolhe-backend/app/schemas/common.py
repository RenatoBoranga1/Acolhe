from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    app: str
    timestamp: datetime


class UserSnapshot(BaseModel):
    id: str
    display_name: str
    biometrics_enabled: bool
    discreet_mode: bool
    auto_lock_minutes: int
