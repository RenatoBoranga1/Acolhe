from __future__ import annotations

from sqlalchemy import delete, func, or_, select
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

    def get_conversation(
        self,
        session: Session,
        conversation_id: str,
        *,
        user_id: str | None = None,
    ) -> Conversation | None:
        stmt = select(Conversation).where(Conversation.id == conversation_id)
        if user_id is not None:
            stmt = stmt.where(Conversation.user_id == user_id)
        return session.scalar(stmt)

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

    def list_messages(
        self, session: Session, conversation_id: str, limit: int = 50
    ) -> list[Message]:
        stmt = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
            .limit(limit)
        )
        return list(session.scalars(stmt))

    def list_messages_page(
        self,
        session: Session,
        conversation_id: str,
        *,
        page: int = 1,
        page_size: int = 40,
    ) -> list[Message]:
        safe_page = max(page, 1)
        safe_page_size = min(max(page_size, 1), 100)
        offset = (safe_page - 1) * safe_page_size
        stmt = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.desc())
            .offset(offset)
            .limit(safe_page_size)
        )
        items = list(session.scalars(stmt))
        items.reverse()
        return items

    def count_messages(self, session: Session, conversation_id: str) -> int:
        stmt = (
            select(func.count())
            .select_from(Message)
            .where(Message.conversation_id == conversation_id)
        )
        return int(session.scalar(stmt) or 0)

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

    def get_message(
        self,
        session: Session,
        message_id: str,
        *,
        user_id: str | None = None,
    ) -> Message | None:
        stmt = (
            select(Message)
            .join(Conversation, Conversation.id == Message.conversation_id)
            .where(Message.id == message_id)
        )
        if user_id is not None:
            stmt = stmt.where(Conversation.user_id == user_id)
        return session.scalar(stmt)

    def update_message_metadata(
        self,
        session: Session,
        message: Message,
        metadata: dict,
    ) -> Message:
        message.message_metadata = metadata
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

    def update_conversation(
        self,
        session: Session,
        conversation: Conversation,
        *,
        title: str | None = None,
        discreet_mode: bool | None = None,
        status: str | None = None,
    ) -> Conversation:
        if title is not None:
            conversation.title = title
        if discreet_mode is not None:
            conversation.discreet_mode = discreet_mode
        if status is not None:
            conversation.status = status
        session.add(conversation)
        session.commit()
        session.refresh(conversation)
        return conversation

    def delete_conversation(self, session: Session, conversation: Conversation) -> None:
        message_ids = [
            row[0]
            for row in session.query(Message.id)
            .filter(Message.conversation_id == conversation.id)
            .all()
        ]
        if message_ids:
            session.execute(
                delete(RiskAssessment).where(
                    or_(
                        RiskAssessment.conversation_id == conversation.id,
                        RiskAssessment.message_id.in_(message_ids),
                    )
                )
            )
        else:
            session.execute(
                delete(RiskAssessment).where(
                    RiskAssessment.conversation_id == conversation.id
                )
            )
        session.execute(
            delete(Message).where(Message.conversation_id == conversation.id)
        )
        session.execute(delete(Conversation).where(Conversation.id == conversation.id))
        session.commit()
