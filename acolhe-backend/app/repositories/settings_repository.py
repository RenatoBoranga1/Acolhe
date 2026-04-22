from __future__ import annotations

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models import (
    AppSetting,
    Conversation,
    IncidentRecord,
    Message,
    RiskAssessment,
    SafetyPlan,
    TrustedContact,
)


class SettingsRepository:
    def get_or_create(self, session: Session, user_id: str) -> AppSetting:
        setting = session.query(AppSetting).filter(AppSetting.user_id == user_id).one_or_none()
        if setting is None:
            setting = AppSetting(user_id=user_id)
            session.add(setting)
            session.commit()
            session.refresh(setting)
        return setting

    def save(self, session: Session, setting: AppSetting) -> AppSetting:
        session.add(setting)
        session.commit()
        session.refresh(setting)
        return setting

    def purge_user_data(self, session: Session, user_id: str) -> None:
        conversation_ids = [row[0] for row in session.query(Conversation.id).filter(Conversation.user_id == user_id)]
        if conversation_ids:
            session.execute(delete(Message).where(Message.conversation_id.in_(conversation_ids)))
            session.execute(delete(RiskAssessment).where(RiskAssessment.conversation_id.in_(conversation_ids)))
            session.execute(delete(Conversation).where(Conversation.id.in_(conversation_ids)))
        session.execute(delete(IncidentRecord).where(IncidentRecord.user_id == user_id))
        session.execute(delete(SafetyPlan).where(SafetyPlan.user_id == user_id))
        session.execute(delete(TrustedContact).where(TrustedContact.user_id == user_id))
        session.commit()
