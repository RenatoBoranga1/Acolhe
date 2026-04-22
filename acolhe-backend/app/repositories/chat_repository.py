from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Conversation, Message, RiskAssessment


class ChatRepository:
    def list_conversations(self, session: Session, user_id: str) -> list[Conversation]:
        stmt = (
            select(Conversation)
            .where(Conversation.user_id == user_id)
            .order_by(Conversation.updated_at.desc())
        )
        return list(session.scalars(stmt))

    def get_conversation(self, session: Session, conversation_id: str) -> Conversation | None:
        return session.get(Conversation, conversation_id)

    def create_conversation(
        self,
        session: Session,
        user_id: str,
        *,
        title: str = "Nova conversa",
        discreet_mode: bool = False,
    ) -> Conversation:
        conversation = Conversation(
            user_id=user_id,
            title=title,
            discreet_mode=discreet_mode,
            last_risk_level="low",
        )
        session.add(conversation)
        session.commit()
        session.refresh(conversation)
        return conversation

    def list_messages(self, session: Session, conversation_id: str, limit: int = 50) -> list[Message]:
        stmt = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
            .limit(limit)
        )
        return list(session.scalars(stmt))

    def add_message(
        self,
        session: Session,
        *,
        conversation_id: str,
        role: str,
        content: str,
        risk_level: str,
        metadata: dict | None = None,
    ) -> Message:
        message = Message(
            conversation_id=conversation_id,
            role=role,
            content=content,
            risk_level=risk_level,
            message_metadata=metadata or {},
        )
        session.add(message)
        session.commit()
        session.refresh(message)
        return message

    def add_risk_assessment(
        self,
        session: Session,
        *,
        user_id: str,
        conversation_id: str | None,
        message_id: str | None,
        level: str,
        score: int,
        reasons: list[str],
        recommended_actions: list[str],
        requires_immediate_action: bool,
    ) -> RiskAssessment:
        assessment = RiskAssessment(
            user_id=user_id,
            conversation_id=conversation_id,
            message_id=message_id,
            level=level,
            score=score,
            reasons=reasons,
            recommended_actions=recommended_actions,
            requires_immediate_action=requires_immediate_action,
        )
        session.add(assessment)
        session.commit()
        session.refresh(assessment)
        return assessment

    def update_conversation_risk(
        self,
        session: Session,
        conversation: Conversation,
        risk_level: str,
    ) -> Conversation:
        conversation.last_risk_level = risk_level
        session.add(conversation)
        session.commit()
        session.refresh(conversation)
        return conversation
