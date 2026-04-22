from __future__ import annotations

from sqlalchemy import ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class SafetyPlan(UUIDTimestampMixin, Base):
    __tablename__ = "safety_plans"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    safe_locations: Mapped[list[str]] = mapped_column(JSON, default=list)
    warning_signs: Mapped[list[str]] = mapped_column(JSON, default=list)
    immediate_steps: Mapped[list[str]] = mapped_column(JSON, default=list)
    priority_contacts: Mapped[list[str]] = mapped_column(JSON, default=list)
    personal_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    emergency_checklist: Mapped[list[str]] = mapped_column(JSON, default=list)


class TrustedContact(UUIDTimestampMixin, Base):
    __tablename__ = "trusted_contacts"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    relationship: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    email: Mapped[str | None] = mapped_column(String(120), nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=1)
    ready_message: Mapped[str] = mapped_column(
        Text,
        default="Oi, preciso do seu apoio. Passei por uma situacao dificil e gostaria de conversar com voce.",
    )
