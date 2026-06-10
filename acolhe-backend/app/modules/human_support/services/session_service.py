from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models import HumanChatSession
from app.modules.human_support.schemas import (
    GenericSupportActionResponse,
    HumanChatSessionPayload,
    QueueItemPayload,
    SessionCloseRequest,
    SessionTransferRequest,
)
from app.modules.human_support.services.base import SupportServiceBase


class SupportSessionService(SupportServiceBase):
    def accept_request(
        self,
        session: Session,
        *,
        request_id: str,
        supporter_user_id: str | None = None,
        presence_status: str | None = None,
    ) -> HumanChatSessionPayload:
        actor, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        if not profile.is_available:
            raise ValueError("O apoiador precisa estar online para aceitar a fila.")
        if not profile.training_completed:
            raise ValueError("As diretrizes precisam ser aceitas antes do atendimento.")
        active_count = self.repository.count_active_sessions_for_supporter(
            session, profile.id
        )
        if active_count >= profile.max_active_sessions:
            raise ValueError("Limite de atendimentos ativos atingido para este apoiador.")

        support_request = self.repository.get_support_request(session, request_id)
        if support_request is None:
            raise ValueError("Solicitacao nao encontrada.")
        if support_request.status not in {"waiting", "assigned", "escalated"}:
            raise ValueError("Esta solicitacao nao esta mais disponivel na fila.")

        support_request.status = "active"
        support_request.assigned_supporter_id = profile.id
        support_request.assigned_at = datetime.now(UTC)
        saved_request = self.repository.save_support_request(session, support_request)

        current_session = self.repository.get_current_session_for_request(
            session, saved_request.id
        )
        if current_session is None or current_session.status == "closed":
            current_session = HumanChatSession(
                support_request_id=saved_request.id,
                user_id=saved_request.user_id,
                supporter_id=profile.id,
                status="active",
                started_at=datetime.now(UTC),
                copilot_snapshot=saved_request.summary_payload or {},
            )
        else:
            current_session.supporter_id = profile.id
            current_session.status = "active"
            current_session.started_at = current_session.started_at or datetime.now(UTC)
            current_session.copilot_snapshot = saved_request.summary_payload or {}
        current_session = self.repository.save_session(session, current_session)

        self.repository.save_audit_log(
            session,
            actor_id=actor.id,
            action="support_request_accepted",
            target_id=saved_request.id,
            metadata_safe={
                "supporter_profile_id": profile.id,
                "risk_level": saved_request.risk_level,
            },
        )
        return self.build_session_payload(
            session,
            current_session,
            presence_status=presence_status,
        )

    def get_session_for_user(
        self,
        session: Session,
        *,
        session_id: str,
        user_id: str | None = None,
        presence_status: str | None = None,
    ) -> HumanChatSessionPayload:
        user = self.current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao de acolhimento nao encontrada.")
        return self.build_session_payload(
            session,
            human_session,
            presence_status=presence_status,
        )

    def get_session_for_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        supporter_user_id: str | None = None,
        presence_status: str | None = None,
    ) -> HumanChatSessionPayload:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.supporter_id != profile.id:
            raise ValueError("Sessao nao encontrada para este apoiador.")
        return self.build_session_payload(
            session,
            human_session,
            presence_status=presence_status,
        )

    def list_active_sessions(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
        presence_status: str | None = None,
    ) -> list[HumanChatSessionPayload]:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        sessions = self.repository.list_active_sessions_for_supporter(session, profile.id)
        return [
            self.build_session_payload(session, item, presence_status=presence_status)
            for item in sessions
        ]

    def list_recent_sessions(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
        presence_status: str | None = None,
        limit: int = 6,
    ) -> list[HumanChatSessionPayload]:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        sessions = self.repository.list_recent_closed_sessions_for_supporter(
            session, profile.id, limit=limit
        )
        return [
            self.build_session_payload(session, item, presence_status=presence_status)
            for item in sessions
        ]

    def close_session_as_user(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionCloseRequest,
        user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        user = self.current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao nao encontrada.")
        self._close_session_and_request(
            session,
            human_session=human_session,
            close_reason=payload.reason,
            actor_id=user.id,
            action="session_closed_by_user",
        )
        return GenericSupportActionResponse(
            message="A conversa com a Rede Acolhe foi encerrada com seguranca."
        )

    def close_session_as_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionCloseRequest,
        supporter_user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        actor, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.supporter_id != profile.id:
            raise ValueError("Sessao nao encontrada para este apoiador.")
        self._close_session_and_request(
            session,
            human_session=human_session,
            close_reason=payload.reason,
            actor_id=actor.id,
            action="session_closed_by_supporter",
        )
        return GenericSupportActionResponse(
            message="Atendimento encerrado e registrado com auditoria segura."
        )

    def transfer_session(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionTransferRequest,
        supporter_user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        actor, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.supporter_id != profile.id:
            raise ValueError("Sessao nao encontrada para este apoiador.")
        support_request = self.repository.get_support_request(
            session, human_session.support_request_id
        )
        if support_request is None:
            raise ValueError("Solicitacao relacionada nao encontrada.")

        human_session.status = "closed"
        human_session.close_reason = payload.reason
        human_session.ended_at = datetime.now(UTC)
        self.repository.save_session(session, human_session)

        support_request.status = "escalated" if payload.target_specialty else "waiting"
        support_request.close_reason = payload.reason
        support_request.assigned_supporter_id = None
        support_request.assigned_specialist_id = None
        summary_payload = dict(support_request.summary_payload or {})
        if payload.target_specialty:
            summary_payload["requested_specialty"] = payload.target_specialty
        support_request.summary_payload = summary_payload
        self.repository.save_support_request(session, support_request)
        self.repository.save_audit_log(
            session,
            actor_id=actor.id,
            action="session_transferred",
            target_id=human_session.id,
            metadata_safe={
                "target_specialty": payload.target_specialty,
                "request_status": support_request.status,
            },
        )
        return GenericSupportActionResponse(
            message="A sessao foi encerrada e o pedido voltou para a fila apropriada."
        )

    def _close_session_and_request(
        self,
        session: Session,
        *,
        human_session: HumanChatSession,
        close_reason: str,
        actor_id: str,
        action: str,
    ) -> None:
        self.repository.mark_session_closed(session, human_session, close_reason)
        support_request = self.repository.get_support_request(
            session, human_session.support_request_id
        )
        if support_request is not None:
            support_request.status = "closed"
            support_request.close_reason = close_reason
            support_request.closed_at = datetime.now(UTC)
            self.repository.save_support_request(session, support_request)
        self.repository.save_audit_log(
            session,
            actor_id=actor_id,
            action=action,
            target_id=human_session.id,
            metadata_safe={"reason": close_reason},
        )
