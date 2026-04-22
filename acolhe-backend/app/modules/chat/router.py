from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.chat.schemas import (
    ChatMessageRequest,
    ChatMessageResponse,
    ConversationPayload,
    NewConversationRequest,
)
from app.modules.chat.service import ChatService

router = APIRouter()
service = ChatService()


@router.get("/conversations", response_model=list[ConversationPayload])
def list_conversations(session: Session = Depends(get_db)) -> list[ConversationPayload]:
    return service.list_conversations(session)


@router.post("/conversations", response_model=ConversationPayload)
def create_conversation(
    payload: NewConversationRequest,
    session: Session = Depends(get_db),
) -> ConversationPayload:
    return service.new_conversation(session, payload.title, payload.discreet_mode)


@router.post("/message", response_model=ChatMessageResponse)
def send_message(
    payload: ChatMessageRequest,
    session: Session = Depends(get_db),
) -> ChatMessageResponse:
    try:
        return service.send_message(
            session,
            conversation_id=payload.conversation_id,
            message=payload.message,
            discreet_mode=payload.discreet_mode,
            client_history=payload.history,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
