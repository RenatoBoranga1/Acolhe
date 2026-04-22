from __future__ import annotations

from sqlalchemy import Boolean, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class User(UUIDTimestampMixin, Base):
    __tablename__ = "users"

    display_name: Mapped[str] = mapped_column(String(120), default="Usuaria Acolhe")
    hashed_pin: Mapped[str] = mapped_column(String(255))
    biometrics_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    discreet_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    notifications_hidden: Mapped[bool] = mapped_column(Boolean, default=True)
    auto_lock_minutes: Mapped[int] = mapped_column(Integer, default=5)
    locale: Mapped[str] = mapped_column(String(12), default="pt-BR")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
