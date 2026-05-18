from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models import Conversation, Message, User
from app.modules.chat.intelligence.response_orchestrator_service import (
    ResponseOrchestratorService,
)
from app.modules.chat.schemas import (
    ChatMessageResponse,
    ContextMessagePayload,
    ConversationDeleteResponse,
    ConversationPayload,
    MessageFeedbackRequest,
    MessageFeedbackResponse,
    MessagePayload,
    PaginatedMessagesResponse,
    UpdateConversationRequest,
)
from app.repositories.auth_repository import AuthRepository
from app.repositories.chat_repository import ChatRepository


class ChatService:
    def __init__(self) -> None:
        self.chat_repository = ChatRepository()
        self.auth_repository = AuthRepository()
        self.response_orchestrator = ResponseOrchestratorService()

    def _current_user(
        self, session: Session, requested_user_id: str | None = None
    ) -> User:
        user = (
            self.auth_repository.get_user_by_id(session, requested_user_id)
            if requested_user_id
            else self.auth_repository.get_primary_user(session)
        )
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return user

    def _message_payload(self, message: Message) -> MessagePayload:
        return MessagePayload(
            id=message.id,
            role=message.role,
            content=message.content,
            risk_level=message.risk_level,
            created_at=message.created_at,
        )

    def _conversation_payload(
        self, conversation: Conversation, messages: list[Message]
    ) -> ConversationPayload:
        return ConversationPayload(
            id=conversation.id,
            title=conversation.title,
            last_risk_level=conversation.last_risk_level,
            created_at=conversation.created_at,
            updated_at=conversation.updated_at,
            discreet_mode=conversation.discreet_mode,
            messages=[self._message_payload(message) for message in messages],
        )

    def _conversation_or_error(
        self,
        session: Session,
        *,
        user_id: str,
        conversation_id: str,
    ) -> Conversation:
        conversation = self.chat_repository.get_conversation(
            session,
            conversation_id,
            user_id=user_id,
        )
        if conversation is None:
            raise ValueError("Conversa nao encontrada.")
        return conversation

    def list_conversations(
        self,
        session: Session,
        *,
        user_id: str | None = None,
    ) -> list[ConversationPayload]:
        user = self._current_user(session, user_id)
        conversations = self.chat_repository.list_conversations(session, user.id)
        payloads: list[ConversationPayload] = []
        for conversation in conversations:
            messages = self.chat_repository.list_messages_page(
                session,
                conversation.id,
                page=1,
                page_size=6,
            )
            payloads.append(self._conversation_payload(conversation, messages))
        return payloads

    def get_conversation(
        self,
        session: Session,
        *,
        conversation_id: str,
        user_id: str | None = None,
    ) -> ConversationPayload:
        user = self._current_user(session, user_id)
        conversation = self._conversation_or_error(
            session,
            user_id=user.id,
            conversation_id=conversation_id,
        )
        messages = self.chat_repository.list_messages_page(
            session,
            conversation.id,
            page=1,
            page_size=40,
        )
        return self._conversation_payload(conversation, messages)

    def new_conversation(
        self,
        session: Session,
        title: str,
        discreet_mode: bool,
        *,
        user_id: str | None = None,
    ) -> ConversationPayload:
        user = self._current_user(session, user_id)
        conversation = self.chat_repository.create_conversation(
            session,
            user.id,
            title=title,
            discreet_mode=discreet_mode,
        )
        return self._conversation_payload(conversation, [])

    def update_conversation(
        self,
        session: Session,
        *,
        conversation_id: str,
        payload: UpdateConversationRequest,
        user_id: str | None = None,
    ) -> ConversationPayload:
        user = self._current_user(session, user_id)
        conversation = self._conversation_or_error(
            session,
            user_id=user.id,
            conversation_id=conversation_id,
        )
        updated = self.chat_repository.update_conversation(
            session,
            conversation,
            title=payload.title.strip() if payload.title else None,
            discreet_mode=payload.discreet_mode,
        )
        messages = self.chat_repository.list_messages_page(
            session,
            updated.id,
            page=1,
            page_size=40,
        )
        return self._conversation_payload(updated, messages)

    def delete_conversation(
        self,
        session: Session,
        *,
        conversation_id: str,
        user_id: str | None = None,
    ) -> ConversationDeleteResponse:
        user = self._current_user(session, user_id)
        conversation = self._conversation_or_error(
            session,
            user_id=user.id,
            conversation_id=conversation_id,
        )
        self.chat_repository.delete_conversation(session, conversation)
        return ConversationDeleteResponse(conversation_id=conversation_id)

    def list_messages(
        self,
        session: Session,
        *,
        conversation_id: str,
        page: int,
        page_size: int,
        user_id: str | None = None,
    ) -> PaginatedMessagesResponse:
        user = self._current_user(session, user_id)
        conversation = self._conversation_or_error(
            session,
            user_id=user.id,
            conversation_id=conversation_id,
        )
        safe_page_size = min(max(page_size, 1), 100)
        items = self.chat_repository.list_messages_page(
            session,
            conversation.id,
            page=page,
            page_size=safe_page_size,
        )
        total = self.chat_repository.count_messages(session, conversation.id)
        return PaginatedMessagesResponse(
            conversation_id=conversation.id,
            page=page,
            page_size=safe_page_size,
            total=total,
            has_more=(page * safe_page_size) < total,
            items=[self._message_payload(item) for item in items],
        )

    def leave_feedback(
        self,
        session: Session,
        *,
        message_id: str,
        payload: MessageFeedbackRequest,
        user_id: str | None = None,
    ) -> MessageFeedbackResponse:
        user = self._current_user(session, user_id)
        message = self.chat_repository.get_message(session, message_id, user_id=user.id)
        if message is None:
            raise ValueError("Mensagem nao encontrada.")

        feedback_entry = {
            "rating": payload.rating,
            "note": (payload.note or "").strip(),
            "submitted_at": datetime.now(UTC).isoformat(),
        }
        metadata = dict(message.message_metadata or {})
        existing_feedback = list(metadata.get("feedback") or [])
        existing_feedback.append(feedback_entry)
        metadata["feedback"] = existing_feedback
        metadata["feedback_summary"] = payload.rating
        updated = self.chat_repository.update_message_metadata(
            session, message, metadata
        )
        return MessageFeedbackResponse(
            message_id=updated.id, updated_at=updated.updated_at
        )

    def send_message(
        self,
        session: Session,
        *,
        conversation_id: str | None,
        message: str,
        discreet_mode: bool,
        client_history: list[ContextMessagePayload] | None = None,
        user_id: str | None = None,
    ) -> ChatMessageResponse:
        user = self._current_user(session, user_id)
        conversation = (
            self.chat_repository.get_conversation(
                session,
                conversation_id,
                user_id=user.id,
            )
            if conversation_id
            else None
        )
        if conversation is None:
            conversation = self.chat_repository.create_conversation(
                session,
                user.id,
                title="Conversa segura",
                discreet_mode=discreet_mode,
            )

        user_message = self.chat_repository.add_message(
            session,
            conversation_id=conversation.id,
            role="user",
            content=message,
            risk_level="low",
        )
        stored_messages = self.chat_repository.list_messages(
            session, conversation.id, limit=50
        )
        request_history = [
            {"role": item.role, "content": item.content}
            for item in (client_history or [])
        ]
        orchestration = self.response_orchestrator.respond(
            conversation_id=conversation.id,
            latest_message=message,
            stored_messages=stored_messages,
            client_history=request_history,
        )
        api_risk = orchestration.risk.to_response()

        user_message.risk_level = api_risk.level
        session.add(user_message)
        session.commit()

        self.chat_repository.add_risk_assessment(
            session,
            user_id=user.id,
            conversation_id=conversation.id,
            message_id=user_message.id,
            level=api_risk.level,
            score=api_risk.score,
            reasons=api_risk.reasons,
            recommended_actions=api_risk.recommended_actions,
            requires_immediate_action=api_risk.requires_immediate_action,
        )
        self.chat_repository.update_conversation_risk(
            session, conversation, api_risk.level
        )
        assistant_message = self.chat_repository.add_message(
            session,
            conversation_id=conversation.id,
            role="assistant",
            content=orchestration.assistant_text,
            risk_level=api_risk.level,
            metadata={
                "ctas": orchestration.ctas,
                "conversation_memory": orchestration.memory.to_dict(),
                "risk_assessment": orchestration.risk.to_dict(),
                "situation": orchestration.situation.to_dict(),
                "response_mode": orchestration.response_mode.to_dict(),
                "validation": orchestration.validation.to_dict(),
                "metrics": orchestration.metrics.to_dict(),
            },
        )
        suggestions = [
            "Nao sei por onde comecar",
            "Quero entender se isso foi assedio",
            "Estou com medo",
            "Quero registrar o que aconteceu",
            "Quero pensar nos proximos passos",
            "Quero ajuda para falar com alguem de confianca",
        ]
        return ChatMessageResponse(
            conversation_id=conversation.id,
            assistant_message=self._message_payload(assistant_message),
            risk=api_risk,
            ctas=orchestration.ctas,
            suggestions=suggestions,
            response_mode=orchestration.response_mode.name,
            situation_type=orchestration.situation.type,
            conversation_context=orchestration.memory.to_dict(),
            fallback_used=orchestration.metrics.fallback_used,
            validation_repaired=orchestration.metrics.repaired,
        )
