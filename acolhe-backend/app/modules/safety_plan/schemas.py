from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class SafetyPlanUpsertRequest(BaseModel):
    safe_locations: list[str]
    warning_signs: list[str]
    immediate_steps: list[str]
    priority_contacts: list[str]
    personal_notes: str | None = None
    emergency_checklist: list[str]


class SafetyPlanResponse(BaseModel):
    id: str
    safe_locations: list[str]
    warning_signs: list[str]
    immediate_steps: list[str]
    priority_contacts: list[str]
    personal_notes: str | None
    emergency_checklist: list[str]
    updated_at: datetime
