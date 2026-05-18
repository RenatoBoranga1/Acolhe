from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.modules.risk.schemas import RiskAssessmentResponse


class MessagePayload(BaseModel):
    id: str
    role: str
    content: str
    risk_level: str
    created_at: datetime


class ConversationPayload(BaseModel):
    id: str
    title: str
    last_risk_level: str
    created_at: datetime
    updated_at: datetime
    discreet_mode: bool
    messages: list[MessagePayload] = Field(default_factory=list)


class ContextMessagePayload(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=5000)


class ChatMessageRequest(BaseModel):
    conversation_id: str | None = None
    message: str = Field(min_length=1, max_length=5000)
    discreet_mode: bool = False
    history: list[ContextMessagePayload] = Field(default_factory=list, max_length=12)


class NewConversationRequest(BaseModel):
    title: str = Field(default="Nova conversa", min_length=2, max_length=160)
    discreet_mode: bool = False


class UpdateConversationRequest(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=160)
    discreet_mode: bool | None = None


class ConversationDeleteResponse(BaseModel):
    conversation_id: str
    deleted: bool = True


class PaginatedMessagesResponse(BaseModel):
    conversation_id: str
    page: int
    page_size: int
    total: int
    has_more: bool
    items: list[MessagePayload] = Field(default_factory=list)


class MessageFeedbackRequest(BaseModel):
    rating: Literal["helpful", "not_helpful", "unsafe", "repetitive"]
    note: str | None = Field(default=None, max_length=500)


class MessageFeedbackResponse(BaseModel):
    message_id: str
    stored: bool = True
    updated_at: datetime


class ChatMessageResponse(BaseModel):
    conversation_id: str
    assistant_message: MessagePayload
    risk: RiskAssessmentResponse
    ctas: list[str]
    suggestions: list[str]
    response_mode: str | None = None
    situation_type: str | None = None
    conversation_context: dict | None = None
    fallback_used: bool = False
    validation_repaired: bool = False
