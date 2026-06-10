from __future__ import annotations

from app.modules.chat.intelligence.conversation_memory_service import (
    ConversationMemoryService,
)
from app.modules.chat.intelligence.risk_assessment_service import RiskAssessmentService
from app.modules.chat.intelligence.situation_classifier_service import (
    SituationClassifierService,
)
from app.modules.human_support.schemas import HumanMessageCreate, HumanMessagePayload
from app.modules.human_support.services.base import SupportServiceBase
from app.modules.human_support.services.moderation_service import SupportModerationService
from sqlalchemy.orm import Session


class SupportMessageService(SupportServiceBase):
    def __init__(
        self,
        *,
        moderation_service: SupportModerationService,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self.moderation_service = moderation_service
        self.memory_service = ConversationMemoryService()
        self.risk_service = RiskAssessmentService()
        self.situation_service = SituationClassifierService()

    def post_user_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        user_id: str | None = None,
    ) -> HumanMessagePayload:
        user = self.current_user(session, user_id)
        human_session = self.repository.get_session(session, session_id)
        if human_session is None or human_session.user_id != user.id:
            raise ValueError("Sessao nao encontrada.")
        if human_session.status != "active":
            raise ValueError("A sessao nao esta ativa para novas mensagens.")
        message = self._create_human_message(
            session,
            human_session_id=human_session.id,
            support_request_id=human_session.support_request_id,
            sender_id=user.id,
            sender_role="user",
            content=payload.content,
        )
        return self.build_message_payload(message)

    def post_supporter_message(
        self,
        session: Session,
        *,
        session_id: str,
        payload: HumanMessageCreate,
        supporter_user_id: str | None = None,
    ) -> HumanMessagePayload:
        actor, profile = self.support_actor(
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
            human_session_id=human_session.id,
            support_request_id=human_session.support_request_id,
            sender_id=actor.id,
            sender_role=sender_role,
            content=payload.content,
            supporter_profile_id=profile.id,
        )
        return self.build_message_payload(message)

    def _create_human_message(
        self,
        session: Session,
        *,
        human_session_id: str,
        support_request_id: str,
        sender_id: str,
        sender_role: str,
        content: str,
        supporter_profile_id: str | None = None,
    ):
        normalized = content.strip()
        if not normalized:
            raise ValueError("A mensagem precisa ter conteudo.")

        risk_signal_detected, risk_level = self._detect_message_risk(normalized)
        message = self.repository.add_message(
            session,
            session_id=human_session_id,
            sender_id=sender_id,
            sender_role=sender_role,
            content=normalized,
            is_flagged=False,
            risk_signal_detected=risk_signal_detected,
            message_metadata={
                "sender_role": sender_role,
                "risk_level_detected": risk_level,
            },
        )

        if supporter_profile_id is not None:
            alert = self.moderation_service.create_language_alert(
                session,
                supporter_profile_id=supporter_profile_id,
                session_id=human_session_id,
                message_id=message.id,
                content=normalized,
            )
            if alert is not None:
                message.is_flagged = True
                self.repository.save_audit_log(
                    session,
                    actor_id=sender_id,
                    action="supporter_message_flagged",
                    target_id=alert.id,
                    metadata_safe={
                        "session_id": human_session_id,
                        "severity": alert.severity,
                        "alert_type": alert.alert_type,
                    },
                )
                message.message_metadata = {
                    **(message.message_metadata or {}),
                    "moderation_alert_id": alert.id,
                }
                session.add(message)
                session.commit()
                session.refresh(message)

        if risk_signal_detected:
            support_request = self.repository.get_support_request(
                session, support_request_id
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
                "session_id": human_session_id,
                "sender_role": sender_role,
                "content_length": len(normalized),
                "flagged": message.is_flagged,
                "risk_signal_detected": risk_signal_detected,
            },
        )
        return message

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
