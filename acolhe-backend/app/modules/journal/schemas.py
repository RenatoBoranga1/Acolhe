from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field


class IncidentRecordCreate(BaseModel):
    occurred_on: date | None = None
    occurred_at: str | None = Field(default=None, max_length=20)
    location: str | None = Field(default=None, max_length=255)
    description: str = Field(min_length=10, max_length=6000)
    people_involved: list[str] = []
    witnesses: list[str] = []
    attachments: list[str] = []
    observations: str | None = None
    perceived_impacts: list[str] = []


class IncidentRecordResponse(BaseModel):
    id: str
    occurred_on: date | None
    occurred_at: str | None
    location: str | None
    description: str
    people_involved: list[str]
    witnesses: list[str]
    attachments: list[str]
    observations: str | None
    perceived_impacts: list[str]
    chronological_summary: str | None
    created_at: datetime
    updated_at: datetime


class IncidentSummaryResponse(BaseModel):
    record_id: str
    label: str
    disclaimer: str
    summary: str
