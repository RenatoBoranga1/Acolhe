from __future__ import annotations

from pydantic import BaseModel, Field


class SettingsUpdateRequest(BaseModel):
    quick_exit_enabled: bool
    notifications_hidden: bool
    discreet_mode: bool
    discreet_app_name: str = Field(min_length=2, max_length=120)
    notification_title: str = Field(min_length=2, max_length=120)
    export_format: str = Field(default="json", max_length=20)


class SettingsResponse(BaseModel):
    id: str
    quick_exit_enabled: bool
    notifications_hidden: bool
    discreet_mode: bool
    discreet_app_name: str
    notification_title: str
    export_format: str


class ExportBundleResponse(BaseModel):
    profile: dict
    settings: dict
    conversations: list[dict]
    incident_records: list[dict]
    trusted_contacts: list[dict]
    safety_plan: dict | None
