from __future__ import annotations

from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class IncidentRecord(UUIDTimestampMixin, Base):
    __tablename__ = "incident_records"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    occurred_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    occurred_at: Mapped[str | None] = mapped_column(String(20), nullable=True)
    location: Mapped[str | None] = mapped_column(String(255), nullable=True)
    description: Mapped[str] = mapped_column(Text)
    people_involved: Mapped[list[str]] = mapped_column(JSON, default=list)
    witnesses: Mapped[list[str]] = mapped_column(JSON, default=list)
    attachments: Mapped[list[str]] = mapped_column(JSON, default=list)
    observations: Mapped[str | None] = mapped_column(Text, nullable=True)
    perceived_impacts: Mapped[list[str]] = mapped_column(JSON, default=list)
    chronological_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
