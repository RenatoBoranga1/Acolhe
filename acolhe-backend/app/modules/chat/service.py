from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import Conversation, Message, User
from app.modules.chat.intelligence.response_orchestrator_service import ResponseOrchestratorService
from app.modules.chat.schemas import (
    ChatMessageResponse,
    ContextMessagePayload,
    ConversationPayload,
    MessagePayload,
)
from app.repositories.auth_repository import AuthRepository
from app.repositories.chat_repository import ChatRepository


class ChatService:
    def __init__(self) -> None:
        self.chat_repository = ChatRepository()
        self.auth_repository = AuthRepository()
        self.response_orchestrator = ResponseOrchestratorService()

    def _current_user(self, session: Session) -> User:
        user = self.auth_repository.get_primary_user(session)
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

    def _conversation_payload(self, conversation: Conversation, messages: list[Message]) -> ConversationPayload:
        return ConversationPayload(
            id=conversation.id,
            title=conversation.title,
            last_risk_level=conversation.last_risk_level,
            updated_at=conversation.updated_at,
            discreet_mode=conversation.discreet_mode,
            messages=[self._message_payload(message) for message in messages],
        )

    def list_conversations(self, session: Session) -> list[ConversationPayload]:
        user = self._current_user(session)
        conversations = self.chat_repository.list_conversations(session, user.id)
        payloads: list[ConversationPayload] = []
        for conversation in conversations:
            messages = self.chat_repository.list_messages(session, conversation.id)
            payloads.append(self._conversation_payload(conversation, messages))
        return payloads

    def new_conversation(self, session: Session, title: str, discreet_mode: bool) -> ConversationPayload:
        user = self._current_user(session)
        conversation = self.chat_repository.create_conversation(
            session,
            user.id,
            title=title,
            discreet_mode=discreet_mode,
        )
        return self._conversation_payload(conversation, [])

    def send_message(
        self,
        session: Session,
        *,
        conversation_id: str | None,
        message: str,
        discreet_mode: bool,
        client_history: list[ContextMessagePayload] | None = None,
    ) -> ChatMessageResponse:
        user = self._current_user(session)
        conversation = (
            self.chat_repository.get_conversation(session, conversation_id) if conversation_id else None
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
        stored_messages = self.chat_repository.list_messages(session, conversation.id, limit=50)
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
        self.chat_repository.update_conversation_risk(session, conversation, api_risk.level)
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
        )
