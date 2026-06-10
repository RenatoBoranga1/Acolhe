from __future__ import annotations

from sqlalchemy.orm import Session

from app.modules.human_support.schemas import (
    AdminDashboardPayload,
    GenericSupportActionResponse,
    HumanChatSessionPayload,
    HumanMessageCreate,
    HumanMessagePayload,
    QueueItemPayload,
    SessionCloseRequest,
    SessionTransferRequest,
    SupportModerationAlertPayload,
    SupportReportPayload,
    SupportReportRequest,
    SupportRequestCreate,
    SupportRequestPayload,
    SupportRequestStatusPayload,
    SupporterGuidelinesAckResponse,
    SupporterProfilePayload,
    SupporterStatusUpdate,
    SupporterVerifyRequest,
    SupporterDashboardPayload,
)
from app.modules.human_support.services import (
    SupportAnalyticsService,
    SupportMessageService,
    SupportModerationService,
    SupportPriorityService,
    SupportQueueService,
    SupportRealtimeService,
    SupportSessionService,
    SupporterProfileService,
)
from app.modules.human_support.services.base import SupportServiceContainer


class HumanSupportService:
    def __init__(self) -> None:
        container = SupportServiceContainer()
        self.realtime_service = SupportRealtimeService()
        self.priority_service = SupportPriorityService()
        self.queue_service = SupportQueueService(
            container=container,
            priority_service=self.priority_service,
        )
        self.profile_service = SupporterProfileService(
            container=container,
            realtime_service=self.realtime_service,
        )
        self.moderation_service = SupportModerationService(container=container)
        self.message_service = SupportMessageService(
            container=container,
            moderation_service=self.moderation_service,
        )
        self.session_service = SupportSessionService(container=container)
        self.analytics_service = SupportAnalyticsService(
            container=container,
            priority_service=self.priority_service,
            realtime_service=self.realtime_service,
        )

    def request_support(
        self,
        session: Session,
        *,
        payload: SupportRequestCreate,
        user_id: str | None = None,
    ) -> SupportRequestPayload:
        return self.queue_service.request_support(
            session,
            payload=payload,
            user_id=user_id,
        )

    def get_current_request(
        self, session: Session, *, user_id: str | None = None
    ) -> SupportRequestStatusPayload:
        return self.queue_service.get_current_request(session, user_id=user_id)

    def cancel_request(
        self,
        session: Session,
        *,
        request_id: str,
        user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        return self.queue_service.cancel_request(
            session,
            request_id=request_id,
            user_id=user_id,
        )

    def list_queue(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> list[QueueItemPayload]:
        return self.queue_service.list_queue(
            session,
            supporter_user_id=supporter_user_id,
        )

    def get_admin_queue(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[QueueItemPayload]:
        return self.queue_service.get_admin_queue(
            session,
            admin_user_id=admin_user_id,
        )

    def acknowledge_guidelines(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterGuidelinesAckResponse:
        return self.profile_service.acknowledge_guidelines(
            session,
            supporter_user_id=supporter_user_id,
        )

    def update_supporter_status(
        self,
        session: Session,
        *,
        payload: SupporterStatusUpdate,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        return self.profile_service.update_supporter_status(
            session,
            payload=payload,
            supporter_user_id=supporter_user_id,
        )

    def get_supporter_profile(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        return self.profile_service.get_supporter_profile(
            session,
            supporter_user_id=supporter_user_id,
        )

    def accept_request(
        self,
        session: Session,
        *,
        request_id: str,
        supporter_user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        presence = self.realtime_service.get_presence(
            self.profile_service.support_actor(
                session,
                requested_user_id=supporter_user_id,
                allowed_role_types=["supporter", "specialist", "admin"],
            )[1].user_id
        )
        return self.session_service.accept_request(
            session,
            request_id=request_id,
            supporter_user_id=supporter_user_id,
            presence_status=presence.status,
        )

    def get_session_for_user(
        self,
        session: Session,
        *,
        session_id: str,
        user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        human_session = self.session_service.get_session_for_user(
            session,
            session_id=session_id,
            user_id=user_id,
        )
        if human_session.supporter_profile is None:
            return human_session
        presence = self.realtime_service.get_presence(human_session.supporter_profile.user_id)
        return self.session_service.get_session_for_user(
            session,
            session_id=session_id,
            user_id=user_id,
            presence_status=presence.status,
        )

    def get_session_for_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        supporter_user_id: str | None = None,
    ) -> HumanChatSessionPayload:
        actor, profile = self.profile_service.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        del actor
        presence = self.realtime_service.get_presence(profile.user_id)
        return self.session_service.get_session_for_supporter(
            session,
            session_id=session_id,
            supporter_user_id=supporter_user_id,
            presence_status=presence.status,
        )

    def list_active_sessions(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> list[HumanChatSessionPayload]:
        actor, profile = self.profile_service.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        del actor
        presence = self.realtime_service.get_presence(profile.user_id)
        return self.session_service.list_active_sessions(
            session,
            supporter_user_id=supporter_user_id,
            presence_status=presence.status,
        )

    def post_user_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        user_id: str | None = None,
    ) -> HumanMessagePayload:
        return self.message_service.post_user_message(
            session,
            session_id=session_id,
            payload=payload,
            user_id=user_id,
        )

    def post_supporter_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        supporter_user_id: str | None = None,
    ) -> HumanMessagePayload:
        return self.message_service.post_supporter_message(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=supporter_user_id,
        )

    def close_session_as_user(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionCloseRequest,
        user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        return self.session_service.close_session_as_user(
            session,
            session_id=session_id,
            payload=payload,
            user_id=user_id,
        )

    def close_session_as_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionCloseRequest,
        supporter_user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        return self.session_service.close_session_as_supporter(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=supporter_user_id,
        )

    def transfer_session(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SessionTransferRequest,
        supporter_user_id: str | None = None,
    ) -> GenericSupportActionResponse:
        return self.session_service.transfer_session(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=supporter_user_id,
        )

    def report_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SupportReportRequest,
        user_id: str | None = None,
    ) -> SupportReportPayload:
        return self.moderation_service.report_supporter(
            session,
            session_id=session_id,
            payload=payload,
            user_id=user_id,
        )

    def list_reports(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[SupportReportPayload]:
        return self.moderation_service.list_reports(
            session,
            admin_user_id=admin_user_id,
        )

    def list_moderation_alerts(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[SupportModerationAlertPayload]:
        return self.moderation_service.list_moderation_alerts(
            session,
            admin_user_id=admin_user_id,
        )

    def verify_supporter(
        self,
        session: Session,
        *,
        profile_id: str,
        payload: SupporterVerifyRequest,
        admin_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        return self.moderation_service.verify_supporter(
            session,
            profile_id=profile_id,
            payload=payload,
            admin_user_id=admin_user_id,
        )

    def get_supporter_dashboard(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterDashboardPayload:
        return self.analytics_service.build_supporter_dashboard(
            session,
            supporter_user_id=supporter_user_id,
        )

    def get_admin_dashboard(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> AdminDashboardPayload:
        return self.analytics_service.build_admin_dashboard(
            session,
            admin_user_id=admin_user_id,
        )
