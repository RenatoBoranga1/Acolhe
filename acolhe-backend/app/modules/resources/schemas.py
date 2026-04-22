from __future__ import annotations

from pydantic import BaseModel


class ResourceArticleResponse(BaseModel):
    id: str
    slug: str
    category: str
    title: str
    summary: str
    body: str
    cta_label: str | None
    cta_kind: str | None
