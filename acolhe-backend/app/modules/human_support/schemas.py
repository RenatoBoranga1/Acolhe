from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class SupportSummaryPayload(BaseModel):
    context_main: str
    emotional_state: str
    risk_level: str
    situation_type: str
    points_to_avoid: list[str] = Field(default_factory=list)
    suggested_next_steps: list[str] = Field(default_factory=list)
    safety_alerts: list[str] = Field(default_factory=list)
    supporter_copilot_suggestions: list[str] = Field(default_factory=list)
    supporter_reminders: list[str] = Field(default_factory=list)
    summary_text: str
    priority_score: float


class SupportPresencePayload(BaseModel):
    user_id: str
    profile_id: str
    display_name: str
    role_type: str
    presence_status: Literal["online", "offline", "away", "busy"]
    is_available: bool
    active_sessions: int
    updated_at: datetime


class SupporterProfilePayload(BaseModel):
    id: str
    user_id: str
    display_name: str
    role_type: str
    specialties: list[str] = Field(default_factory=list)
    verification_status: str
    is_available: bool
    max_active_sessions: int
    training_completed: bool
    guidelines_accepted_at: datetime | None = None
    presence_status: Literal["online", "offline", "away", "busy"] | None = None
    active_session_count: int = 0


class SupportRequestCreate(BaseModel):
    conversation_id: str | None = None
    consent_to_human_handoff: bool = True
    requester_alias: str = Field(
        default="Pessoa atendida", min_length=2, max_length=120
    )


class SupportRequestPayload(BaseModel):
    id: str
    user_id: str
    conversation_id: str | None = None
    status: str
    risk_level: str
    situation_type: str
    priority_score: float
    requester_alias: str
    assigned_supporter_id: str | None = None
    assigned_specialist_id: str | None = None
    created_at: datetime
    assigned_at: datetime | None = None
    closed_at: datetime | None = None
    close_reason: str | None = None
    safe_summary: SupportSummaryPayload
    session_id: str | None = None
    queue_status_label: str
    distribution_score: float | None = None
    recommended_specialty: str | None = None


class SupportRequestStatusPayload(BaseModel):
    request: SupportRequestPayload | None = None
    active_session_id: str | None = None


class SupporterStatusUpdate(BaseModel):
    is_available: bool
    max_active_sessions: int = Field(default=2, ge=1, le=10)


class SupporterGuidelinesAckResponse(BaseModel):
    accepted: bool = True
    profile: SupporterProfilePayload


class QueueItemPayload(BaseModel):
    request: SupportRequestPayload
    waiting_minutes: int
    priority_bucket: str
    distribution_score: float = 0
    matching_reasons: list[str] = Field(default_factory=list)


class SessionCloseRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=240)


class SessionTransferRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=240)
    target_specialty: str | None = Field(default=None, max_length=80)


class SupportReportRequest(BaseModel):
    reason: Literal[
        "inadequate_language",
        "pressure_or_judgment",
        "safety_concern",
        "identity_misrepresentation",
        "other",
    ]
    description: str | None = Field(default=None, max_length=1500)


class GenericSupportActionResponse(BaseModel):
    ok: bool = True
    message: str


class HumanMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=5000)


class HumanMessagePayload(BaseModel):
    id: str
    session_id: str
    sender_id: str
    sender_role: str
    content: str
    created_at: datetime
    is_flagged: bool = False
    risk_signal_detected: bool = False


class HumanChatSessionPayload(BaseModel):
    id: str
    support_request_id: str
    user_id: str
    supporter_id: str
    status: str
    started_at: datetime | None = None
    ended_at: datetime | None = None
    close_reason: str | None = None
    supporter_profile: SupporterProfilePayload | None = None
    safe_summary: SupportSummaryPayload | None = None
    messages: list[HumanMessagePayload] = Field(default_factory=list)
    copilot_suggestions: list[str] = Field(default_factory=list)
    supporter_reminders: list[str] = Field(default_factory=list)


class SupportReportPayload(BaseModel):
    id: str
    reporter_id: str
    reported_user_id: str
    session_id: str
    reason: str
    description: str | None = None
    status: str
    created_at: datetime


class SupportModerationAlertPayload(BaseModel):
    id: str
    supporter_profile_id: str
    session_id: str | None = None
    message_id: str | None = None
    alert_type: str
    severity: str
    rationale: str
    status: str
    created_at: datetime


class SupportMetricsPayload(BaseModel):
    average_first_assignment_minutes: float
    average_session_minutes: float
    sessions_per_day: list[dict[str, Any]] = Field(default_factory=list)
    sessions_by_supporter: list[dict[str, Any]] = Field(default_factory=list)
    sessions_by_risk: dict[str, int] = Field(default_factory=dict)
    transfer_rate: float
    abandonment_rate: float
    total_closed_sessions: int


class SupporterDashboardPayload(BaseModel):
    profile: SupporterProfilePayload
    queue: list[QueueItemPayload] = Field(default_factory=list)
    active_sessions: list[HumanChatSessionPayload] = Field(default_factory=list)
    recent_sessions: list[HumanChatSessionPayload] = Field(default_factory=list)
    presence: SupportPresencePayload
    metrics: SupportMetricsPayload
    open_moderation_alerts: int = 0


class AdminDashboardPayload(BaseModel):
    queue: list[QueueItemPayload] = Field(default_factory=list)
    active_sessions: list[HumanChatSessionPayload] = Field(default_factory=list)
    open_reports: list[SupportReportPayload] = Field(default_factory=list)
    moderation_alerts: list[SupportModerationAlertPayload] = Field(
        default_factory=list
    )
    supporter_presence: list[SupportPresencePayload] = Field(default_factory=list)
    metrics: SupportMetricsPayload


class SupportRealtimeEnvelope(BaseModel):
    event: str
    payload: dict[str, Any] = Field(default_factory=dict)


class SupporterVerifyRequest(BaseModel):
    role_type: Literal["supporter", "specialist", "admin"] = "specialist"
    specialties: list[str] = Field(default_factory=list, max_length=8)
    verification_status: Literal["verified", "suspended"] = "verified"
