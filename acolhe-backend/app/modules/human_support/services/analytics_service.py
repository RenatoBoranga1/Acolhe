from __future__ import annotations

from collections import Counter, defaultdict
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.modules.human_support.schemas import (
    AdminDashboardPayload,
    SupportMetricsPayload,
    SupporterDashboardPayload,
)
from app.modules.human_support.services.base import SupportServiceBase
from app.modules.human_support.services.priority_service import SupportPriorityService
from app.modules.human_support.services.realtime_service import SupportRealtimeService


class SupportAnalyticsService(SupportServiceBase):
    def __init__(
        self,
        *,
        priority_service: SupportPriorityService,
        realtime_service: SupportRealtimeService,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self.priority_service = priority_service
        self.realtime_service = realtime_service

    def build_supporter_dashboard(
        self,
        session: Session,
        *,
        supporter_user_id: str | None = None,
    ) -> SupporterDashboardPayload:
        _, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        presence = self.realtime_service.get_presence(profile.user_id)
        active_count = self.repository.count_active_sessions_for_supporter(session, profile.id)
        queue = self._personalized_queue(session, profile.id, supporter_user_id)
        active_sessions = [
            self.build_session_payload(
                session,
                item,
                presence_status="busy" if active_count > 0 else presence.status,
            )
            for item in self.repository.list_active_sessions_for_supporter(session, profile.id)
        ]
        recent_sessions = [
            self.build_session_payload(session, item, presence_status=presence.status)
            for item in self.repository.list_recent_closed_sessions_for_supporter(
                session, profile.id, limit=6
            )
        ]
        alerts = self.repository.list_moderation_alerts(
            session,
            status="open",
        )
        open_alerts = sum(1 for item in alerts if item.supporter_profile_id == profile.id)
        return SupporterDashboardPayload(
            profile=self.build_supporter_profile_payload(
                profile,
                presence_status="busy" if active_count > 0 else presence.status,
                active_session_count=active_count,
            ),
            queue=queue,
            active_sessions=active_sessions,
            recent_sessions=recent_sessions,
            presence=self.build_presence_payload(
                profile=profile,
                presence_status="busy" if active_count > 0 else presence.status,
                active_sessions=active_count,
                updated_at=presence.updated_at,
            ),
            metrics=self.build_metrics(session),
            open_moderation_alerts=open_alerts,
        )

    def build_admin_dashboard(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> AdminDashboardPayload:
        admin_user, _ = self.support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        queue = self._personalized_queue(session, None, admin_user.id)
        active_sessions = [
            self.build_session_payload(session, item)
            for item in self.repository.list_active_sessions(session)
        ]
        reports = [
            self.build_report_payload(item)
            for item in self.repository.list_reports(session, status="open")
        ]
        alerts = [
            self.build_moderation_alert_payload(item)
            for item in self.repository.list_moderation_alerts(session, status="open", limit=20)
        ]
        supporter_presence = []
        for profile in self.repository.list_supporter_profiles(session):
            presence = self.realtime_service.get_presence(profile.user_id)
            active_count = self.repository.count_active_sessions_for_supporter(
                session, profile.id
            )
            supporter_presence.append(
                self.build_presence_payload(
                    profile=profile,
                    presence_status="busy" if active_count > 0 else presence.status,
                    active_sessions=active_count,
                    updated_at=presence.updated_at,
                )
            )
        return AdminDashboardPayload(
            queue=queue,
            active_sessions=active_sessions,
            open_reports=reports,
            moderation_alerts=alerts,
            supporter_presence=supporter_presence,
            metrics=self.build_metrics(session),
        )

    def build_metrics(self, session: Session) -> SupportMetricsPayload:
        requests = self.repository.list_requests(session)
        closed_sessions = self.repository.list_closed_sessions(session)
        all_profiles = self.repository.list_supporter_profiles(session)

        assignment_delays = [
            (item.assigned_at - item.created_at).total_seconds() / 60
            for item in requests
            if item.assigned_at is not None
        ]
        session_durations = [
            (item.ended_at - item.started_at).total_seconds() / 60
            for item in closed_sessions
            if item.ended_at is not None and item.started_at is not None
        ]
        sessions_per_day_counter: Counter[str] = Counter()
        sessions_by_supporter_counter: Counter[str] = Counter()
        sessions_by_risk_counter: Counter[str] = Counter()
        transfer_count = 0
        abandonment_count = 0

        profile_by_id = {profile.id: profile.display_name for profile in all_profiles}

        for request in requests:
            sessions_per_day_counter[request.created_at.date().isoformat()] += 1
            sessions_by_risk_counter[request.risk_level] += 1
            if request.status == "cancelled":
                abandonment_count += 1
            if request.status == "escalated":
                transfer_count += 1
            if request.assigned_supporter_id:
                sessions_by_supporter_counter[profile_by_id.get(request.assigned_supporter_id, "Apoiador")] += 1

        total_requests = max(len(requests), 1)
        return SupportMetricsPayload(
            average_first_assignment_minutes=round(
                sum(assignment_delays) / len(assignment_delays), 2
            )
            if assignment_delays
            else 0,
            average_session_minutes=round(
                sum(session_durations) / len(session_durations), 2
            )
            if session_durations
            else 0,
            sessions_per_day=[
                {"day": day, "count": count}
                for day, count in sorted(sessions_per_day_counter.items())
            ],
            sessions_by_supporter=[
                {"supporter": name, "count": count}
                for name, count in sessions_by_supporter_counter.most_common()
            ],
            sessions_by_risk=dict(sessions_by_risk_counter),
            transfer_rate=round((transfer_count / total_requests) * 100, 2),
            abandonment_rate=round((abandonment_count / total_requests) * 100, 2),
            total_closed_sessions=len(closed_sessions),
        )

    def _personalized_queue(
        self,
        session: Session,
        supporter_profile_id: str | None,
        supporter_user_id: str | None,
    ):
        if supporter_profile_id is None:
            requests = self.repository.list_queue(session)
            now = datetime.now(UTC)
            return [
                self.build_queue_item_payload(
                    item,
                    waiting_minutes=max(
                        0, int((now - item.created_at).total_seconds() // 60)
                    ),
                    priority_bucket=self.priority_service.priority_bucket(item.risk_level),
                    distribution_score=item.priority_score,
                    matching_reasons=["Vista administrativa da fila atual."],
                )
                for item in requests
            ]
        # Reuse business ordering from the queue service without a circular import.
        actor, profile = self.support_actor(
            session,
            requested_user_id=supporter_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        del actor
        now = datetime.now(UTC)
        active_sessions = self.repository.count_active_sessions_for_supporter(
            session, profile.id
        )
        items = []
        for item in self.repository.list_queue(session):
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
        return [payload for _, payload in items]
