from __future__ import annotations

from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class SupporterProfile(UUIDTimestampMixin, Base):
    __tablename__ = "supporter_profiles"

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True
    )
    display_name: Mapped[str] = mapped_column(String(120))
    role_type: Mapped[str] = mapped_column(String(30), default="supporter")
    specialties: Mapped[list[str]] = mapped_column(JSON, default=list)
    verification_status: Mapped[str] = mapped_column(
        String(30), default="unverified"
    )
    is_available: Mapped[bool] = mapped_column(Boolean, default=False)
    max_active_sessions: Mapped[int] = mapped_column(Integer, default=2)
    training_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    guidelines_accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)


class SupportRequest(UUIDTimestampMixin, Base):
    __tablename__ = "support_requests"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    conversation_id: Mapped[str | None] = mapped_column(
        ForeignKey("conversations.id"), nullable=True, index=True
    )
    status: Mapped[str] = mapped_column(String(30), default="waiting")
    risk_level: Mapped[str] = mapped_column(String(20), default="moderate")
    situation_type: Mapped[str] = mapped_column(String(60), default="support_request")
    priority_score: Mapped[float] = mapped_column(Float, default=0.0)
    summary_text: Mapped[str] = mapped_column(Text, default="")
    summary_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    requester_alias: Mapped[str] = mapped_column(String(120), default="Pessoa atendida")
    consent_to_human_handoff: Mapped[bool] = mapped_column(Boolean, default=False)
    assigned_supporter_id: Mapped[str | None] = mapped_column(
        ForeignKey("supporter_profiles.id"), nullable=True, index=True
    )
    assigned_specialist_id: Mapped[str | None] = mapped_column(
        ForeignKey("supporter_profiles.id"), nullable=True, index=True
    )
    assigned_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    close_reason: Mapped[str | None] = mapped_column(Text, nullable=True)


class HumanChatSession(UUIDTimestampMixin, Base):
    __tablename__ = "human_chat_sessions"

    support_request_id: Mapped[str] = mapped_column(
        ForeignKey("support_requests.id"), index=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    supporter_id: Mapped[str] = mapped_column(
        ForeignKey("supporter_profiles.id"), index=True
    )
    status: Mapped[str] = mapped_column(String(30), default="active")
    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    close_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    copilot_snapshot: Mapped[dict] = mapped_column(JSON, default=dict)


class HumanMessage(UUIDTimestampMixin, Base):
    __tablename__ = "human_messages"

    session_id: Mapped[str] = mapped_column(
        ForeignKey("human_chat_sessions.id"), index=True
    )
    sender_id: Mapped[str] = mapped_column(String(36), index=True)
    sender_role: Mapped[str] = mapped_column(String(30))
    content: Mapped[str] = mapped_column(Text)
    is_flagged: Mapped[bool] = mapped_column(Boolean, default=False)
    risk_signal_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    message_metadata: Mapped[dict] = mapped_column(JSON, default=dict)


class SupportAuditLog(UUIDTimestampMixin, Base):
    __tablename__ = "support_audit_logs"

    actor_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    action: Mapped[str] = mapped_column(String(80))
    target_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    metadata_safe: Mapped[dict] = mapped_column(JSON, default=dict)


class SupportReport(UUIDTimestampMixin, Base):
    __tablename__ = "support_reports"

    reporter_id: Mapped[str] = mapped_column(String(36), index=True)
    reported_user_id: Mapped[str] = mapped_column(String(36), index=True)
    session_id: Mapped[str] = mapped_column(
        ForeignKey("human_chat_sessions.id"), index=True
    )
    reason: Mapped[str] = mapped_column(String(80))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(30), default="open")


class SupportModerationAlert(UUIDTimestampMixin, Base):
    __tablename__ = "support_moderation_alerts"

    supporter_profile_id: Mapped[str] = mapped_column(
        ForeignKey("supporter_profiles.id"), index=True
    )
    session_id: Mapped[str | None] = mapped_column(
        ForeignKey("human_chat_sessions.id"), nullable=True, index=True
    )
    message_id: Mapped[str | None] = mapped_column(
        ForeignKey("human_messages.id"), nullable=True, index=True
    )
    alert_type: Mapped[str] = mapped_column(String(80))
    severity: Mapped[str] = mapped_column(String(20), default="moderate")
    rationale: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="open")
