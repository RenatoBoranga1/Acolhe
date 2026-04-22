from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.resources.schemas import ResourceArticleResponse
from app.modules.resources.service import ResourcesService

router = APIRouter()
service = ResourcesService()


@router.get("", response_model=list[ResourceArticleResponse])
def list_resources(
    locale: str = Query(default="pt-BR"),
    session: Session = Depends(get_db),
) -> list[ResourceArticleResponse]:
    return service.list_articles(session, locale=locale)
