from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.chat.schemas import (
    ChatMessageRequest,
    ChatMessageResponse,
    ConversationDeleteResponse,
    ConversationPayload,
    MessageFeedbackRequest,
    MessageFeedbackResponse,
    NewConversationRequest,
    PaginatedMessagesResponse,
    UpdateConversationRequest,
)
from app.modules.chat.service import ChatService

router = APIRouter()
service = ChatService()


@router.get("/conversations", response_model=list[ConversationPayload])
def list_conversations(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[ConversationPayload]:
    return service.list_conversations(session, user_id=x_acolhe_user_id)


@router.get("/conversations/{conversation_id}", response_model=ConversationPayload)
def get_conversation(
    conversation_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> ConversationPayload:
    try:
        return service.get_conversation(
            session,
            conversation_id=conversation_id,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/conversations", response_model=ConversationPayload)
def create_conversation(
    payload: NewConversationRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> ConversationPayload:
    return service.new_conversation(
        session,
        payload.title,
        payload.discreet_mode,
        user_id=x_acolhe_user_id,
    )


@router.patch("/conversations/{conversation_id}", response_model=ConversationPayload)
def update_conversation(
    conversation_id: str,
    payload: UpdateConversationRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> ConversationPayload:
    try:
        return service.update_conversation(
            session,
            conversation_id=conversation_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/conversations/{conversation_id}", response_model=ConversationDeleteResponse
)
def delete_conversation(
    conversation_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> ConversationDeleteResponse:
    try:
        return service.delete_conversation(
            session,
            conversation_id=conversation_id,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=PaginatedMessagesResponse,
)
def list_messages(
    conversation_id: str,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=40, ge=1, le=100),
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> PaginatedMessagesResponse:
    try:
        return service.list_messages(
            session,
            conversation_id=conversation_id,
            page=page,
            page_size=page_size,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/message", response_model=ChatMessageResponse)
def send_message(
    payload: ChatMessageRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> ChatMessageResponse:
    try:
        return service.send_message(
            session,
            conversation_id=payload.conversation_id,
            message=payload.message,
            discreet_mode=payload.discreet_mode,
            client_history=payload.history,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/messages/{message_id}/feedback", response_model=MessageFeedbackResponse)
def leave_message_feedback(
    message_id: str,
    payload: MessageFeedbackRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> MessageFeedbackResponse:
    try:
        return service.leave_feedback(
            session,
            message_id=message_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
