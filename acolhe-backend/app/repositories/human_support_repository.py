from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.models import (
    HumanChatSession,
    HumanMessage,
    SupportAuditLog,
    SupportReport,
    SupportRequest,
    SupporterProfile,
)


class HumanSupportRepository:
    def get_supporter_profile_by_user_id(
        self, session: Session, user_id: str
    ) -> SupporterProfile | None:
        stmt = select(SupporterProfile).where(SupporterProfile.user_id == user_id)
        return session.scalar(stmt)

    def get_supporter_profile(
        self, session: Session, profile_id: str
    ) -> SupporterProfile | None:
        stmt = select(SupporterProfile).where(SupporterProfile.id == profile_id)
        return session.scalar(stmt)

    def list_supporter_profiles(
        self,
        session: Session,
        *,
        role_types: list[str] | None = None,
        available_only: bool = False,
    ) -> list[SupporterProfile]:
        stmt = select(SupporterProfile).order_by(SupporterProfile.created_at.asc())
        if role_types:
            stmt = stmt.where(SupporterProfile.role_type.in_(role_types))
        if available_only:
            stmt = stmt.where(SupporterProfile.is_available.is_(True))
        return list(session.scalars(stmt))

    def save_supporter_profile(
        self, session: Session, profile: SupporterProfile
    ) -> SupporterProfile:
        session.add(profile)
        session.commit()
        session.refresh(profile)
        return profile

    def get_current_request_for_user(
        self, session: Session, user_id: str
    ) -> SupportRequest | None:
        stmt = (
            select(SupportRequest)
            .where(
                SupportRequest.user_id == user_id,
                SupportRequest.status.in_(("waiting", "assigned", "active")),
            )
            .order_by(SupportRequest.created_at.desc())
        )
        return session.scalar(stmt)

    def get_support_request(
        self, session: Session, request_id: str
    ) -> SupportRequest | None:
        stmt = select(SupportRequest).where(SupportRequest.id == request_id)
        return session.scalar(stmt)

    def save_support_request(
        self, session: Session, support_request: SupportRequest
    ) -> SupportRequest:
        session.add(support_request)
        session.commit()
        session.refresh(support_request)
        return support_request

    def list_queue(self, session: Session) -> list[SupportRequest]:
        stmt = (
            select(SupportRequest)
            .where(SupportRequest.status.in_(("waiting", "assigned")))
            .order_by(desc(SupportRequest.priority_score), SupportRequest.created_at.asc())
        )
        return list(session.scalars(stmt))

    def list_active_sessions_for_supporter(
        self, session: Session, supporter_profile_id: str
    ) -> list[HumanChatSession]:
        stmt = (
            select(HumanChatSession)
            .where(
                HumanChatSession.supporter_id == supporter_profile_id,
                HumanChatSession.status.in_(("assigned", "active")),
            )
            .order_by(HumanChatSession.created_at.desc())
        )
        return list(session.scalars(stmt))

    def count_active_sessions_for_supporter(
        self, session: Session, supporter_profile_id: str
    ) -> int:
        stmt = (
            select(func.count())
            .select_from(HumanChatSession)
            .where(
                HumanChatSession.supporter_id == supporter_profile_id,
                HumanChatSession.status.in_(("assigned", "active")),
            )
        )
        return int(session.scalar(stmt) or 0)

    def get_current_session_for_request(
        self, session: Session, support_request_id: str
    ) -> HumanChatSession | None:
        stmt = (
            select(HumanChatSession)
            .where(HumanChatSession.support_request_id == support_request_id)
            .order_by(HumanChatSession.created_at.desc())
        )
        return session.scalar(stmt)

    def get_session(
        self, session: Session, session_id: str
    ) -> HumanChatSession | None:
        stmt = select(HumanChatSession).where(HumanChatSession.id == session_id)
        return session.scalar(stmt)

    def save_session(
        self, session: Session, human_session: HumanChatSession
    ) -> HumanChatSession:
        session.add(human_session)
        session.commit()
        session.refresh(human_session)
        return human_session

    def list_messages(self, session: Session, session_id: str) -> list[HumanMessage]:
        stmt = (
            select(HumanMessage)
            .where(HumanMessage.session_id == session_id)
            .order_by(HumanMessage.created_at.asc())
        )
        return list(session.scalars(stmt))

    def add_message(
        self,
        session: Session,
        *,
        session_id: str,
        sender_id: str,
        sender_role: str,
        content: str,
        is_flagged: bool = False,
        risk_signal_detected: bool = False,
        message_metadata: dict | None = None,
    ) -> HumanMessage:
        message = HumanMessage(
            session_id=session_id,
            sender_id=sender_id,
            sender_role=sender_role,
            content=content,
            is_flagged=is_flagged,
            risk_signal_detected=risk_signal_detected,
            message_metadata=message_metadata or {},
        )
        session.add(message)
        session.commit()
        session.refresh(message)
        return message

    def save_report(self, session: Session, report: SupportReport) -> SupportReport:
        session.add(report)
        session.commit()
        session.refresh(report)
        return report

    def list_reports(self, session: Session) -> list[SupportReport]:
        stmt = select(SupportReport).order_by(SupportReport.created_at.desc())
        return list(session.scalars(stmt))

    def save_audit_log(
        self,
        session: Session,
        *,
        actor_id: str | None,
        action: str,
        target_id: str | None,
        metadata_safe: dict | None = None,
    ) -> SupportAuditLog:
        log = SupportAuditLog(
            actor_id=actor_id,
            action=action,
            target_id=target_id,
            metadata_safe=metadata_safe or {},
        )
        session.add(log)
        session.commit()
        session.refresh(log)
        return log

    def touch_request_status(
        self,
        session: Session,
        support_request: SupportRequest,
        *,
        status: str,
        assigned_supporter_id: str | None = None,
        assigned_specialist_id: str | None = None,
        close_reason: str | None = None,
    ) -> SupportRequest:
        support_request.status = status
        if assigned_supporter_id is not None:
            support_request.assigned_supporter_id = assigned_supporter_id
            support_request.assigned_at = datetime.now(UTC)
        if assigned_specialist_id is not None:
            support_request.assigned_specialist_id = assigned_specialist_id
        if close_reason is not None:
            support_request.close_reason = close_reason
            support_request.closed_at = datetime.now(UTC)
        session.add(support_request)
        session.commit()
        session.refresh(support_request)
        return support_request

    def mark_session_closed(
        self, session: Session, human_session: HumanChatSession, reason: str
    ) -> HumanChatSession:
        human_session.status = "closed"
        human_session.close_reason = reason
        human_session.ended_at = datetime.now(UTC)
        session.add(human_session)
        session.commit()
        session.refresh(human_session)
        return human_session
