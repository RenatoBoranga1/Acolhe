from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class TrustedContactCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    relationship: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=40)
    email: str | None = Field(default=None, max_length=120)
    priority: int = Field(default=1, ge=1, le=9)
    ready_message: str = Field(min_length=10, max_length=400)


class TrustedContactResponse(BaseModel):
    id: str
    name: str
    relationship: str
    phone: str | None
    email: str | None
    priority: int
    ready_message: str
    updated_at: datetime
