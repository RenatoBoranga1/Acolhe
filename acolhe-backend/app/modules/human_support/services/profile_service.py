from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.modules.human_support.schemas import (
    SupporterGuidelinesAckResponse,
    SupporterProfilePayload,
    SupporterStatusUpdate,
)
from app.modules.human_support.services.base import SupportServiceBase
from app.modules.human_support.services.realtime_service import SupportRealtimeService


class SupporterProfileService(SupportServiceBase):
    def __init__(
        self,
        *,
        realtime_service: SupportRealtimeService,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self.realtime_service = realtime_service

    def acknowledge_guidelines(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterGuidelinesAckResponse:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        profile.training_completed = True
        profile.guidelines_accepted_at = datetime.now(UTC)
        saved = self.repository.save_supporter_profile(session, profile)
        active_count = self.repository.count_active_sessions_for_supporter(session, saved.id)
        presence = self.realtime_service.get_presence(saved.user_id)
        return SupporterGuidelinesAckResponse(
            profile=self.build_supporter_profile_payload(
                saved,
                presence_status=presence.status,
                active_session_count=active_count,
            )
        )

    def update_supporter_status(
        self,
        session: Session,
        *,
        payload: SupporterStatusUpdate,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        actor, profile = self.support_actor(
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
        presence_status = "online" if saved.is_available else "away"
        self.realtime_service.set_presence(saved.user_id, presence_status)
        active_count = self.repository.count_active_sessions_for_supporter(session, saved.id)
        return self.build_supporter_profile_payload(
            saved,
            presence_status=presence_status if active_count == 0 else "busy",
            active_session_count=active_count,
        )

    def get_supporter_profile(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        presence = self.realtime_service.get_presence(profile.user_id)
        active_count = self.repository.count_active_sessions_for_supporter(session, profile.id)
        return self.build_supporter_profile_payload(
            profile,
            presence_status="busy" if active_count > 0 else presence.status,
            active_session_count=active_count,
        )
