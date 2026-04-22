from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ResourceArticle


class ResourcesRepository:
    def list_resources(self, session: Session, locale: str = "pt-BR") -> list[ResourceArticle]:
        stmt = (
            select(ResourceArticle)
            .where(ResourceArticle.locale == locale, ResourceArticle.is_published.is_(True))
            .order_by(ResourceArticle.category.asc(), ResourceArticle.title.asc())
        )
        return list(session.scalars(stmt))
