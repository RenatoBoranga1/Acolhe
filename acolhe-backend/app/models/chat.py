from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class Conversation(UUIDTimestampMixin, Base):
    __tablename__ = "conversations"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(160), default="Conversa segura")
    status: Mapped[str] = mapped_column(String(20), default="active")
    discreet_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    last_risk_level: Mapped[str] = mapped_column(String(20), default="low")


class Message(UUIDTimestampMixin, Base):
    __tablename__ = "messages"

    conversation_id: Mapped[str] = mapped_column(ForeignKey("conversations.id"), index=True)
    role: Mapped[str] = mapped_column(String(20))
    content: Mapped[str] = mapped_column(Text)
    risk_level: Mapped[str] = mapped_column(String(20), default="low")
    message_metadata: Mapped[dict] = mapped_column(JSON, default=dict)
