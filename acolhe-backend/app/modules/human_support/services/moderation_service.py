from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import SupportModerationAlert, SupportReport
from app.modules.human_support.schemas import (
    SupportModerationAlertPayload,
    SupportReportPayload,
    SupportReportRequest,
    SupporterProfilePayload,
    SupporterVerifyRequest,
)
from app.modules.human_support.services.base import SupportServiceBase


class SupportModerationService(SupportServiceBase):
    def create_language_alert(
        self,
        session: Session,
        *,
        supporter_profile_id: str,
        session_id: str | None,
        message_id: str | None,
        content: str,
    ) -> SupportModerationAlertPayload | None:
        lowered = content.lower()
        alert_rules = {
            "culpabilizacao": (
                "a culpa foi sua",
                "culpabilizacao",
                "high",
                "Possivel culpabilizacao da pessoa atendida.",
            ),
            "pressao_para_denunciar": (
                "voce precisa denunciar",
                "pressao_para_denunciar",
                "moderate",
                "Possivel pressao por uma decisao sensivel.",
            ),
            "minimizacao": (
                "isso nao foi nada",
                "minimizacao",
                "high",
                "Possivel minimizacao do relato.",
            ),
            "falsa_garantia": (
                "prometo que fica em segredo",
                "falsa_garantia",
                "moderate",
                "Promessa inadequada de sigilo absoluto.",
            ),
            "julgamento": (
                "deve ter entendido errado",
                "julgamento",
                "moderate",
                "Possivel invalidez ou julgamento do relato.",
            ),
        }
        for fragment, alert_type, severity, rationale in alert_rules.values():
            if fragment in lowered:
                alert = SupportModerationAlert(
                    supporter_profile_id=supporter_profile_id,
                    session_id=session_id,
                    message_id=message_id,
                    alert_type=alert_type,
                    severity=severity,
                    rationale=rationale,
                    status="open",
                )
                return self.build_moderation_alert_payload(
                    self.repository.save_moderation_alert(session, alert)
                )
        return None

    def report_supporter(
        self,
        session: Session,
        *,
        session_id: str,
        payload: SupportReportRequest,
        user_id: str | None = None,
    ) -> SupportReportPayload:
        user = self.current_user(session, user_id)
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
        return self.build_report_payload(saved)

    def list_reports(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[SupportReportPayload]:
        self.support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        reports = self.repository.list_reports(session)
        return [self.build_report_payload(item) for item in reports]

    def list_moderation_alerts(
        self,
        session: Session,
        *,
        admin_user_id: str | None = None,
    ) -> list[SupportModerationAlertPayload]:
        self.support_actor(
            session,
            requested_user_id=admin_user_id,
            allowed_role_types=["admin"],
        )
        alerts = self.repository.list_moderation_alerts(session)
        return [self.build_moderation_alert_payload(item) for item in alerts]

    def verify_supporter(
        self,
        session: Session,
        *,
        profile_id: str,
        payload: SupporterVerifyRequest,
        admin_user_id: str | None = None,
    ) -> SupporterProfilePayload:
        admin, _ = self.support_actor(
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
        active_count = self.repository.count_active_sessions_for_supporter(session, saved.id)
        return self.build_supporter_profile_payload(
            saved,
            active_session_count=active_count,
        )
