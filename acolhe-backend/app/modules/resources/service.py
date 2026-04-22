from __future__ import annotations

from sqlalchemy.orm import Session

from app.modules.resources.schemas import ResourceArticleResponse
from app.repositories.resources_repository import ResourcesRepository


class ResourcesService:
    def __init__(self) -> None:
        self.repository = ResourcesRepository()

    def list_articles(self, session: Session, locale: str = "pt-BR") -> list[ResourceArticleResponse]:
        articles = self.repository.list_resources(session, locale=locale)
        return [
            ResourceArticleResponse(
                id=item.id,
                slug=item.slug,
                category=item.category,
                title=item.title,
                summary=item.summary,
                body=item.body,
                cta_label=item.cta_label,
                cta_kind=item.cta_kind,
            )
            for item in articles
        ]
