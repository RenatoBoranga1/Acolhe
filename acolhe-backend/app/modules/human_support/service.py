from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models import (
    Conversation,
    HumanChatSession,
    HumanMessage,
    SupportReport,
    SupportRequest,
    SupporterProfile,
    User,
)
from app.modules.chat.intelligence.conversation_memory_service import (
    ConversationMemoryService,
)
from app.modules.chat.intelligence.risk_assessment_service import RiskAssessmentService
from app.modules.chat.intelligence.situation_classifier_service import (
    SituationClassifierService,
)
from app.modules.human_support.schemas import (
    GenericSupportActionResponse,
    HumanChatSessionPayload,
    HumanMessageCreate,
    HumanMessagePayload,
    QueueItemPayload,
    SessionCloseRequest,
    SessionTransferRequest,
    SupportReportPayload,
    SupportReportRequest,
    SupportRequestCreate,
    SupportRequestPayload,
    SupportRequestStatusPayload,
    SupportSummaryPayload,
    SupporterGuidelinesAckResponse,
    SupporterProfilePayload,
    SupporterStatusUpdate,
    SupporterVerifyRequest,
)
from app.modules.human_support.summary_service import (
    SupportHandoffSummary,
    SupportSummaryService,
)
from app.repositories.auth_repository import AuthRepository
from app.repositories.chat_repository import ChatRepository
from app.repositories.human_support_repository import HumanSupportRepository


class HumanSupportService:
    def __init__(self) -> None:
        self.auth_repository = AuthRepository()
        self.chat_repository = ChatRepository()
        self.repository = HumanSupportRepository()
        self.summary_service = SupportSummaryService()
        self.memory_service = ConversationMemoryService()
        self.risk_service = RiskAssessmentService()
        self.situation_service = SituationClassifierService()

    def _current_user(
        self, session: Session, requested_user_id: str | None = None
    ) -> User:
        user = (
            self.auth_repository.get_user_by_id(session, requested_user_id)
            if requested_user_id
            else self.auth_repository.get_primary_user(session)
        )
        if user is None:
            raise ValueError("Pessoa usuaria nao encontrada.")
        return user

    def _support_actor(
        self,
        session: Session,
        *,
        requested_user_id: str | None,
        allowed_role_types: list[str],
    ) -> tuple[User, SupporterProfile]:
        if requested_user_id:
            user = self._current_user(session, requested_user_id)
            profile = self.repository.get_supporter_profile_by_user_id(session, user.id)
            if profile is None:
                profile = SupporterProfile(
                    user_id=user.id,
                    display_name=user.display_name,
                    role_type=allowed_role_types[0],
                    specialties=[],
                    verification_status="unverified",
                    is_available=False,
                    max_active_sessions=2,
                    training_completed=False,
                )
                profile = self.repository.save_supporter_profile(session, profile)
        else:
            profile = next(
                iter(
                    self.repository.list_supporter_profiles(
                        session,
                        role_types=allowed_role_types,
                    )
                ),
                None,
            )
            if profile is None:
                raise ValueError("Nenhum perfil de apoio disponivel para este papel.")
            user = self._current_user(session, profile.user_id)

        if profile.role_type not in allowed_role_types:
            raise ValueError("Perfil sem permissao para esta acao.")
        if profile.verification_status == "suspended":
            raise ValueError("Perfil temporariamente suspenso.")
        return user, profile

    def _latest_conversation_for_user(
        self, session: Session, user_id: str
    ) -> Conversation | None:
        conversations = self.chat_repository.list_conversations(session, user_id)
        return conversations[0] if conversations else None

    def _conversation_or_default(
        self,
        session: Session,
        *,
        user_id: str,
        conversation_id: str | None,
    ) -> Conversation | None:
        if conversation_id:
            conversation = self.chat_repository.get_conversation(
                session,
                conversation_id,
                user_id=user_id,
            )
            if conversation is None:
                raise ValueError("Conversa nao encontrada para a pessoa usuaria.")
            return conversation
        return self._latest_conversation_for_user(session, user_id)

    def _summary_payload(self, summary: SupportHandoffSummary) -> SupportSummaryPayload:
        return SupportSummaryPayload(**summary.to_dict())

    def _supporter_profile_payload(
        self, profile: SupporterProfile
    ) -> SupporterProfilePayload:
        return SupporterProfilePayload(
            id=profile.id,
            user_id=profile.user_id,
            display_name=profile.display_name,
            role_type=profile.role_type,
            specialties=list(profile.specialties or []),
            verification_status=profile.verification_status,
            is_available=profile.is_available,
            max_active_sessions=profile.max_active_sessions,
            training_completed=profile.training_completed,
            guidelines_accepted_at=profile.guidelines_accepted_at,
        )

    def _message_payload(self, message: HumanMessage) -> HumanMessagePayload:
        return HumanMessagePayload(
            id=message.id,
            session_id=message.session_id,
            sender_id=message.sender_id,
            sender_role=message.sender_role,
            content=message.content,
            created_at=message.created_at,
            is_flagged=message.is_flagged,
            risk_signal_detected=message.risk_signal_detected,
        )

    def _queue_status_label(self, request: SupportRequest) -> str:
        return {
            "waiting": "aguardando apoiador",
            "assigned": "procurando alguem disponivel",
            "active": "apoiador conectado",
            "closed": "atendimento encerrado",
            "cancelled": "solicitacao cancelada",
            "escalated": "encaminhado para especialista ou moderacao",
        }.get(request.status, request.status)

    def _request_payload(
        self,
        request: SupportRequest,
        *,
        session_id: str | None = None,
    ) -> SupportRequestPayload:
        summary = dict(request.summary_payload or {})
        if not summary and request.summary_text:
            summary = {
                "context_main": request.summary_text,
                "emotional_state": "uncertain",
                "risk_level": request.risk_level,
                "situation_type": request.situation_type,
                "points_to_avoid": [],
                "suggested_next_steps": [],
                "safety_alerts": [],
                "supporter_copilot_suggestions": [],
                "supporter_reminders": [],
                "summary_text": request.summary_text,
                "priority_score": request.priority_score,
            }
        return SupportRequestPayload(
            id=request.id,
            user_id=request.user_id,
            conversation_id=request.conversation_id,
            status=request.status,
            risk_level=request.risk_level,
            situation_type=request.situation_type,
            priority_score=request.priority_score,
            requester_alias=request.requester_alias,
            assigned_supporter_id=request.assigned_supporter_id,
            assigned_specialist_id=request.assigned_specialist_id,
            created_at=request.created_at,
            assigned_at=request.assigned_at,
            closed_at=request.closed_at,
            close_reason=request.close_reason,
            safe_summary=SupportSummaryPayload(**summary),
            session_id=session_id,
            queue_status_label=self._queue_status_label(request),
        )

    def _session_payload(self, session: Session, human_session: HumanChatSession) -> HumanChatSessionPayload:
        support_request = self.repository.get_support_request(
            session, human_session.support_request_id
        )
        if support_request is None:
            raise ValueError("Solicitacao de apoio nao encontrada.")
        supporter_profile = self.repository.get_supporter_profile(
            session, human_session.supporter_id
        )
        messages = self.repository.list_messages(session, human_session.id)
        summary_payload = self._request_payload(
            support_request,
            session_id=human_session.id,
        ).safe_summary
        copilot_suggestions = list(
            summary_payload.supporter_copilot_suggestions or []
        )
        supporter_reminders = list(summary_payload.supporter_reminders or [])
        return HumanChatSessionPayload(
            id=human_session.id,
            support_request_id=human_session.support_request_id,
            user_id=human_session.user_id,
            supporter_id=human_session.supporter_id,
            status=human_session.status,
            started_at=human_session.started_at,
            ended_at=human_session.ended_at,
            close_reason=human_session.close_reason,
            supporter_profile=(
                self._supporter_profile_payload(supporter_profile)
                if supporter_profile is not None
                else None
            ),
            safe_summary=summary_payload,
            messages=[self._message_payload(item) for item in messages],
            copilot_suggestions=copilot_suggestions,
            supporter_reminders=supporter_reminders,
        )

    def request_support(
        self,
        session: Session,
        *,
        payload: SupportRequestCreate,
        user_id: str | None = None,
    ) -> SupportRequestPayload:
        user = self._current_user(session, user_id)
        if not payload.consent_to_human_handoff:
            raise ValueError("O consentimento para encaminhamento humano e obrigatorio.")

        existing = self.repository.get_current_request_for_user(session, user.id)
        if existing is not None:
            current_session = self.repository.get_current_session_for_request(
                session, existing.id
            )
            return self._request_payload(
                existing,
                session_id=current_session.id if current_session else None,
            )

        conversation = self._conversation_or_default(
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
        return self._request_payload(saved)

    def get_current_request(
        self, session: Session, *, user_id: str | None = None
    ) -> SupportRequestStatusPayload:
        user = self._current_user(session, user_id)
        current = self.repository.get_current_request_for_user(session, user.id)
        if current is None:
            return SupportRequestStatusPayload()
        current_session = self.repository.get_current_session_for_request(
            session, current.id
        )
        return SupportRequestStatusPayload(
            request=self._request_payload(
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
        user = self._current_user(session, user_id)
        support_request = self.repository.get_support_request(session, request_id)
        if support_request is None or support_request.user_id != user.id:
            raise ValueError("Solicitacao nao encontrada.")
        if support_request.status not in {"waiting", "assigned"}:
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
    ) -> list[QueueItemPayload]:
        self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        queue = self.repository.list_queue(session)
        now = datetime.now(UTC)
        return [
            QueueItemPayload(
                request=self._request_payload(item),
                waiting_minutes=max(
                    0, int((now - item.created_at).total_seconds() // 60)
                ),
                priority_bucket=(
                    "critico"
                    if item.risk_level == "critical"
                    else "alto"
                    if item.risk_level == "high"
                    else "moderado"
                    if item.risk_level == "moderate"
                    else "baixo"
                ),
            )
            for item in queue
        ]

    def acknowledge_guidelines(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterGuidelinesAckResponse:
        _, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        profile.training_completed = True
        profile.guidelines_accepted_at = datetime.now(UTC)
        saved = self.repository.save_supporter_profile(session, profile)
        return SupporterGuidelinesAckResponse(
            profile=self._supporter_profile_payload(saved)
        )

    def update_supporter_status(
        self,
        session: Session,
        *,
        payload: SupporterStatusUpdate,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        actor, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        if payload.is_available and not profile.training_completed:
            raise ValueError(
                "Aceite as diretrizes antes de ficar disponivel para acolhimento."
            )
        profile.is_available = payload.is_available
        profile.max_active_sessions = payload.max_active_sessions
        saved = self.repository.save_supporter_profile(session, profile)
        self.repository.save_audit_log(
            session,
            actor_id=actor.id,
            action="supporter_status_updated",
            target_id=saved.id,
            metadata_safe={
                "is_available": saved.is_available,
                "max_active_sessions": saved.max_active_sessions,
            },
        )
        return self._supporter_profile_payload(saved)

    def get_supporter_profile(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        _, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        return self._supporter_profile_payload(profile)

    def accept_request(
        self,
        session: Session,
        *,
        request_id: str,
        supporter_user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        actor, profile = self._support_actor(
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
        if support_request.status not in {"waiting", "assigned"}:
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
            current_session = self.repository.save_session(session, current_session)
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
        return self._session_payload(session, current_session)

    def get_session_for_user(
        self,
        session: Session,
        *,
        session_id: str,
        user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        user = self._current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao de acolhimento nao encontrada.")
        return self._session_payload(session, human_session)

    def get_session_for_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        supporter_user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        _, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.supporter_id != profile.id:
            raise ValueError("Sessao nao encontrada para este apoiador.")
        return self._session_payload(session, human_session)

    def list_active_sessions(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> list[HumanChatSessionPayload]:
        _, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        sessions = self.repository.list_active_sessions_for_supporter(session, profile.id)
        return [self._session_payload(session, item) for item in sessions]

    def get_admin_queue(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[QueueItemPayload]:
        self._support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        return self.list_queue(session, supporter_user_id=admin_user_id)

    def post_user_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        user_id: str | None = None,
    ) -> HumanMessagePayload:
        user = self._current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao nao encontrada.")
        if human_session.status != "active":
            raise ValueError("A sessao nao esta ativa para novas mensagens.")
        message = self._create_human_message(
            session,
            human_session=human_session,
            sender_id=user.id,
            sender_role="user",
            content=payload.content,
        )
        return self._message_payload(message)

    def post_supporter_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        supporter_user_id: str | None = None,
    ) -> HumanMessagePayload:
        actor, profile = self._support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.supporter_id != profile.id:
            raise ValueError("Sessao nao encontrada para este apoiador.")
        if human_session.status != "active":
            raise ValueError("A sessao nao esta ativa para novas mensagens.")
        sender_role = (
            "specialist"
            if profile.role_type == "specialist"
            and profile.verification_status == "verified"
            else profile.role_type
        )
        message = self._create_human_message(
            session,
            human_session=human_session,
            sender_id=actor.id,
            sender_role=sender_role,
            content=payload.content,
            check_supporter_language=True,
        )
        return self._message_payload(message)

    def close_session_as_user(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionCloseRequest,
        user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        user = self._current_user(session, user_id)
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
        actor, profile = self._support_actor(
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
        actor, profile = self._support_actor(
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

        support_request.status = (
            "escalated" if payload.target_specialty else "waiting"
        )
        support_request.close_reason = payload.reason
        support_request.assigned_supporter_id = None
        support_request.assigned_specialist_id = None
        if payload.target_specialty:
            summary_payload = dict(support_request.summary_payload or {})
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

    def report_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SupportReportRequest,
        user_id: str | None = None,
    ) -> SupportReportPayload:
        user = self._current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao nao encontrada.")
        supporter_profile = self.repository.get_supporter_profile(
            session, human_session.supporter_id
        )
        if supporter_profile is None:
            raise ValueError("Perfil do apoiador nao encontrado.")
        report = SupportReport(
            reporter_id=user.id,
            reported_user_id=supporter_profile.user_id,
            session_id=human_session.id,
            reason=payload.reason,
            description=(payload.description or "").strip() or None,
            status="open",
        )
        saved = self.repository.save_report(session, report)
        self.repository.save_audit_log(
            session,
            actor_id=user.id,
            action="supporter_report_created",
            target_id=saved.id,
            metadata_safe={
                "reason": saved.reason,
                "session_id": saved.session_id,
            },
        )
        return SupportReportPayload(
            id=saved.id,
            reporter_id=saved.reporter_id,
            reported_user_id=saved.reported_user_id,
            session_id=saved.session_id,
            reason=saved.reason,
            description=saved.description,
            status=saved.status,
            created_at=saved.created_at,
        )

    def list_reports(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[SupportReportPayload]:
        self._support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        reports = self.repository.list_reports(session)
        return [
            SupportReportPayload(
                id=item.id,
                reporter_id=item.reporter_id,
                reported_user_id=item.reported_user_id,
                session_id=item.session_id,
                reason=item.reason,
                description=item.description,
                status=item.status,
                created_at=item.created_at,
            )
            for item in reports
        ]

    def verify_supporter(
        self,
        session: Session,
        *,
        profile_id: str,
        payload: SupporterVerifyRequest,
        admin_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        admin, _ = self._support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        profile = self.repository.get_supporter_profile(session, profile_id)
        if profile is None:
            raise ValueError("Perfil de apoio nao encontrado.")
        profile.role_type = payload.role_type
        profile.specialties = payload.specialties
        profile.verification_status = payload.verification_status
        saved = self.repository.save_supporter_profile(session, profile)
        self.repository.save_audit_log(
            session,
            actor_id=admin.id,
            action="supporter_verification_updated",
            target_id=saved.id,
            metadata_safe={
                "role_type": saved.role_type,
                "verification_status": saved.verification_status,
                "specialties_count": len(saved.specialties or []),
            },
        )
        return self._supporter_profile_payload(saved)

    def _create_human_message(
        self,
        session: Session,
        *,
        human_session: HumanChatSession,
        sender_id: str,
        sender_role: str,
        content: str,
        check_supporter_language: bool = False,
    ) -> HumanMessage:
        normalized = content.strip()
        if not normalized:
            raise ValueError("A mensagem precisa ter conteudo.")

        risk_signal_detected, risk_level = self._detect_message_risk(normalized)
        is_flagged = (
            self._detect_supporter_conduct_issue(normalized)
            if check_supporter_language
            else False
        )
        message = self.repository.add_message(
            session,
            session_id=human_session.id,
            sender_id=sender_id,
            sender_role=sender_role,
            content=normalized,
            is_flagged=is_flagged,
            risk_signal_detected=risk_signal_detected,
            message_metadata={
                "sender_role": sender_role,
                "risk_level_detected": risk_level,
            },
        )
        if risk_signal_detected:
            support_request = self.repository.get_support_request(
                session, human_session.support_request_id
            )
            if support_request is not None and risk_level in {"high", "critical"}:
                support_request.risk_level = risk_level
                support_request.priority_score = max(
                    support_request.priority_score,
                    0.82 if risk_level == "high" else 0.98,
                )
                summary_payload = dict(support_request.summary_payload or {})
                summary_payload["risk_level"] = risk_level
                summary_payload["priority_score"] = support_request.priority_score
                alerts = list(summary_payload.get("safety_alerts") or [])
                alerts.append(
                    "A conversa humana recebeu um novo sinal de risco e precisa priorizar seguranca imediata."
                )
                summary_payload["safety_alerts"] = list(dict.fromkeys(alerts))
                support_request.summary_payload = summary_payload
                self.repository.save_support_request(session, support_request)
        self.repository.save_audit_log(
            session,
            actor_id=sender_id,
            action="human_message_created",
            target_id=message.id,
            metadata_safe={
                "session_id": human_session.id,
                "sender_role": sender_role,
                "content_length": len(normalized),
                "flagged": is_flagged,
                "risk_signal_detected": risk_signal_detected,
            },
        )
        return message

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

    def _detect_message_risk(self, text: str) -> tuple[bool, str]:
        memory = self.memory_service.load(conversation_id="human-session", messages=[])
        history = [{"role": "user", "content": text}]
        situation = self.situation_service.classify(
            message=text,
            history=history,
            memory=memory,
        )
        risk = self.risk_service.assess(
            message=text,
            history=history,
            memory=memory,
            situation=situation,
        )
        return risk.level in {"high", "critical"}, risk.level

    def _detect_supporter_conduct_issue(self, text: str) -> bool:
        lowered = text.lower()
        disallowed_patterns = (
            "voce precisa denunciar",
            "a culpa foi sua",
            "isso nao foi nada",
            "deve ter entendido errado",
            "prometo que fica em segredo",
        )
        return any(pattern in lowered for pattern in disallowed_patterns)
