from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models import (
    Conversation,
    HumanChatSession,
    HumanMessage,
    SupportModerationAlert,
    SupportReport,
    SupportRequest,
    SupporterProfile,
    User,
)
from app.modules.human_support.schemas import (
    HumanChatSessionPayload,
    HumanMessagePayload,
    QueueItemPayload,
    SupportMetricsPayload,
    SupportModerationAlertPayload,
    SupportPresencePayload,
    SupportReportPayload,
    SupportRequestPayload,
    SupportSummaryPayload,
    SupporterProfilePayload,
)
from app.modules.human_support.summary_service import SupportHandoffSummary, SupportSummaryService
from app.repositories.auth_repository import AuthRepository
from app.repositories.chat_repository import ChatRepository
from app.repositories.human_support_repository import HumanSupportRepository


@dataclass(slots=True)
class SupportServiceContainer:
    auth_repository: AuthRepository = field(default_factory=AuthRepository)
    chat_repository: ChatRepository = field(default_factory=ChatRepository)
    repository: HumanSupportRepository = field(default_factory=HumanSupportRepository)
    summary_service: SupportSummaryService = field(default_factory=SupportSummaryService)


class SupportServiceBase:
    def __init__(self, container: SupportServiceContainer | None = None) -> None:
        self.container = container or SupportServiceContainer()
        self.auth_repository = self.container.auth_repository
        self.chat_repository = self.container.chat_repository
        self.repository = self.container.repository
        self.summary_service = self.container.summary_service

    def current_user(
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

    def support_actor(
        self,
        session: Session,
        *,
        requested_user_id: str | None,
        allowed_role_types: list[str],
    ) -> tuple[User, SupporterProfile]:
        if requested_user_id:
            user = self.current_user(session, requested_user_id)
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
            user = self.current_user(session, profile.user_id)

        if profile.role_type not in allowed_role_types:
            raise ValueError("Perfil sem permissao para esta acao.")
        if profile.verification_status == "suspended":
            raise ValueError("Perfil temporariamente suspenso.")
        return user, profile

    def latest_conversation_for_user(
        self, session: Session, user_id: str
    ) -> Conversation | None:
        conversations = self.chat_repository.list_conversations(session, user_id)
        return conversations[0] if conversations else None

    def conversation_or_default(
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
        return self.latest_conversation_for_user(session, user_id)

    def summary_payload(self, summary: SupportHandoffSummary) -> SupportSummaryPayload:
        return SupportSummaryPayload(**summary.to_dict())

    def queue_status_label(self, request: SupportRequest) -> str:
        return {
            "waiting": "aguardando apoiador",
            "assigned": "procurando alguem disponivel",
            "active": "apoiador conectado",
            "closed": "atendimento encerrado",
            "cancelled": "solicitacao cancelada",
            "escalated": "encaminhado para especialista ou moderacao",
        }.get(request.status, request.status)

    def build_presence_payload(
        self,
        *,
        profile: SupporterProfile,
        presence_status: str,
        active_sessions: int,
        updated_at: datetime | None = None,
    ) -> SupportPresencePayload:
        return SupportPresencePayload(
            user_id=profile.user_id,
            profile_id=profile.id,
            display_name=profile.display_name,
            role_type=profile.role_type,
            presence_status=presence_status,
            is_available=profile.is_available,
            active_sessions=active_sessions,
            updated_at=updated_at or datetime.now(UTC),
        )

    def build_supporter_profile_payload(
        self,
        profile: SupporterProfile,
        *,
        presence_status: str | None = None,
        active_session_count: int = 0,
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
            presence_status=presence_status,
            active_session_count=active_session_count,
        )

    def build_message_payload(self, message: HumanMessage) -> HumanMessagePayload:
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

    def build_request_payload(
        self,
        request: SupportRequest,
        *,
        session_id: str | None = None,
        distribution_score: float | None = None,
        recommended_specialty: str | None = None,
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
            queue_status_label=self.queue_status_label(request),
            distribution_score=distribution_score,
            recommended_specialty=recommended_specialty,
        )

    def build_session_payload(
        self,
        session: Session,
        human_session: HumanChatSession,
        *,
        presence_status: str | None = None,
    ) -> HumanChatSessionPayload:
        support_request = self.repository.get_support_request(
            session, human_session.support_request_id
        )
        if support_request is None:
            raise ValueError("Solicitacao de apoio nao encontrada.")
        supporter_profile = self.repository.get_supporter_profile(
            session, human_session.supporter_id
        )
        messages = self.repository.list_messages(session, human_session.id)
        summary_payload = self.build_request_payload(
            support_request,
            session_id=human_session.id,
        ).safe_summary
        copilot_suggestions = list(summary_payload.supporter_copilot_suggestions or [])
        supporter_reminders = list(summary_payload.supporter_reminders or [])
        active_count = (
            self.repository.count_active_sessions_for_supporter(session, supporter_profile.id)
            if supporter_profile is not None
            else 0
        )
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
                self.build_supporter_profile_payload(
                    supporter_profile,
                    presence_status=presence_status,
                    active_session_count=active_count,
                )
                if supporter_profile is not None
                else None
            ),
            safe_summary=summary_payload,
            messages=[self.build_message_payload(item) for item in messages],
            copilot_suggestions=copilot_suggestions,
            supporter_reminders=supporter_reminders,
        )

    def build_queue_item_payload(
        self,
        request: SupportRequest,
        *,
        waiting_minutes: int,
        priority_bucket: str,
        distribution_score: float,
        matching_reasons: list[str],
    ) -> QueueItemPayload:
        return QueueItemPayload(
            request=self.build_request_payload(
                request,
                distribution_score=distribution_score,
                recommended_specialty=self._requested_specialty(request),
            ),
            waiting_minutes=max(0, waiting_minutes),
            priority_bucket=priority_bucket,
            distribution_score=distribution_score,
            matching_reasons=matching_reasons,
        )

    def build_report_payload(self, report: SupportReport) -> SupportReportPayload:
        return SupportReportPayload(
            id=report.id,
            reporter_id=report.reporter_id,
            reported_user_id=report.reported_user_id,
            session_id=report.session_id,
            reason=report.reason,
            description=report.description,
            status=report.status,
            created_at=report.created_at,
        )

    def build_moderation_alert_payload(
        self, alert: SupportModerationAlert
    ) -> SupportModerationAlertPayload:
        return SupportModerationAlertPayload(
            id=alert.id,
            supporter_profile_id=alert.supporter_profile_id,
            session_id=alert.session_id,
            message_id=alert.message_id,
            alert_type=alert.alert_type,
            severity=alert.severity,
            rationale=alert.rationale,
            status=alert.status,
            created_at=alert.created_at,
        )

    def empty_metrics_payload(self) -> SupportMetricsPayload:
        return SupportMetricsPayload(
            average_first_assignment_minutes=0,
            average_session_minutes=0,
            sessions_per_day=[],
            sessions_by_supporter=[],
            sessions_by_risk={},
            transfer_rate=0,
            abandonment_rate=0,
            total_closed_sessions=0,
        )

    @staticmethod
    def _requested_specialty(request: SupportRequest) -> str | None:
        summary_payload = dict(request.summary_payload or {})
        specialty = summary_payload.get("requested_specialty")
        return specialty if isinstance(specialty, str) and specialty.strip() else None
