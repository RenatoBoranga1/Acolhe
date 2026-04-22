from __future__ import annotations

from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDTimestampMixin


class ResourceArticle(UUIDTimestampMixin, Base):
    __tablename__ = "resource_articles"

    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    locale: Mapped[str] = mapped_column(String(12), default="pt-BR")
    category: Mapped[str] = mapped_column(String(80))
    title: Mapped[str] = mapped_column(String(200))
    summary: Mapped[str] = mapped_column(Text)
    body: Mapped[str] = mapped_column(Text)
    cta_label: Mapped[str | None] = mapped_column(String(120), nullable=True)
    cta_kind: Mapped[str | None] = mapped_column(String(40), nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
