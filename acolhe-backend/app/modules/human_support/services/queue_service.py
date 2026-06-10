from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models import SupportRequest
from app.modules.human_support.schemas import (
    GenericSupportActionResponse,
    QueueItemPayload,
    SupportRequestCreate,
    SupportRequestPayload,
    SupportRequestStatusPayload,
)
from app.modules.human_support.services.base import SupportServiceBase
from app.modules.human_support.services.priority_service import SupportPriorityService


class SupportQueueService(SupportServiceBase):
    def __init__(self, *, priority_service: SupportPriorityService, **kwargs) -> None:
        super().__init__(**kwargs)
        self.priority_service = priority_service

    def request_support(
        self,
        session: Session,
        *,
        payload: SupportRequestCreate,
        user_id: str | None = None,
    ) -> SupportRequestPayload:
        user = self.current_user(session, user_id)
        if not payload.consent_to_human_handoff:
            raise ValueError("O consentimento para encaminhamento humano e obrigatorio.")

        existing = self.repository.get_current_request_for_user(session, user.id)
        if existing is not None:
            current_session = self.repository.get_current_session_for_request(
                session, existing.id
            )
            return self.build_request_payload(
                existing,
                session_id=current_session.id if current_session else None,
            )

        conversation = self.conversation_or_default(
            session,
            user_id=user.id,
            conversation_id=payload.conversation_id,
        )
        messages = (
            self.chat_repository.list_messages(session, conversation.id, limit=50)
            if conversation is not None
            else []
        )
        summary = self.summary_service.build(
            conversation=conversation,
            messages=messages,
        )
        support_request = SupportRequest(
            user_id=user.id,
            conversation_id=conversation.id if conversation is not None else None,
            status="waiting",
            risk_level=summary.risk_level,
            situation_type=summary.situation_type,
            priority_score=summary.priority_score,
            summary_text=summary.summary_text,
            summary_payload=summary.to_dict(),
            requester_alias=payload.requester_alias.strip(),
            consent_to_human_handoff=True,
        )
        saved = self.repository.save_support_request(session, support_request)
        self.repository.save_audit_log(
            session,
            actor_id=user.id,
            action="support_request_created",
            target_id=saved.id,
            metadata_safe={
                "risk_level": saved.risk_level,
                "situation_type": saved.situation_type,
                "priority_score": saved.priority_score,
            },
        )
        return self.build_request_payload(saved)

    def get_current_request(
        self, session: Session, *, user_id: str | None = None
    ) -> SupportRequestStatusPayload:
        user = self.current_user(session, user_id)
        current = self.repository.get_current_request_for_user(session, user.id)
        if current is None:
            return SupportRequestStatusPayload()
        current_session = self.repository.get_current_session_for_request(
            session, current.id
        )
        return SupportRequestStatusPayload(
            request=self.build_request_payload(
                current,
                session_id=current_session.id if current_session else None,
            ),
            active_session_id=current_session.id if current_session else None,
        )

    def cancel_request(
        self,
        session: Session,
        *,
        request_id: str,
        user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        user = self.current_user(session, user_id)
        support_request = self.repository.get_support_request(session, request_id)
        if support_request is None or support_request.user_id != user.id:
            raise ValueError("Solicitacao nao encontrada.")
        if support_request.status not in {"waiting", "assigned", "escalated"}:
            raise ValueError("A solicitacao nao pode mais ser cancelada.")
        support_request.status = "cancelled"
        support_request.close_reason = "cancelled_by_user"
        support_request.closed_at = datetime.now(UTC)
        self.repository.save_support_request(session, support_request)
        self.repository.save_audit_log(
            session,
            actor_id=user.id,
            action="support_request_cancelled",
            target_id=support_request.id,
            metadata_safe={"status": support_request.status},
        )
        return GenericSupportActionResponse(
            message="A solicitacao foi retirada da fila com seguranca."
        )

    def list_queue(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
        allowed_role_types: list[str] | None = None,
    ) -> list[QueueItemPayload]:
        allowed = allowed_role_types or ["supporter", "specialist", "admin"]
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=allowed,
        )
        queue = self.repository.list_queue(session)
        now = datetime.now(UTC)
        items: list[tuple[float, QueueItemPayload]] = []
        active_sessions = self.repository.count_active_sessions_for_supporter(
            session, profile.id
        )
        for item in queue:
            waiting_minutes = max(0, int((now - item.created_at).total_seconds() // 60))
            distribution_score, reasons = self.priority_service.distribution_score(
                item,
                supporter_profile=profile,
                waiting_minutes=waiting_minutes,
                active_sessions=active_sessions,
            )
            items.append(
                (
                    distribution_score,
                    self.build_queue_item_payload(
                        item,
                        waiting_minutes=waiting_minutes,
                        priority_bucket=self.priority_service.priority_bucket(
                            item.risk_level
                        ),
                        distribution_score=distribution_score,
                        matching_reasons=reasons,
                    ),
                )
            )
        items.sort(key=lambda pair: pair[0], reverse=True)
        return [item for _, item in items]

    def get_admin_queue(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[QueueItemPayload]:
        self.support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        return self.list_queue(
            session,
            supporter_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
