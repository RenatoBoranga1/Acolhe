from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class AppSetting(UUIDTimestampMixin, Base):
    __tablename__ = "app_settings"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    quick_exit_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    notifications_hidden: Mapped[bool] = mapped_column(Boolean, default=True)
    discreet_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    discreet_app_name: Mapped[str] = mapped_column(String(120), default="Acolhe")
    notification_title: Mapped[str] = mapped_column(String(120), default="Nova atualizacao")
    export_format: Mapped[str] = mapped_column(String(20), default="json")
