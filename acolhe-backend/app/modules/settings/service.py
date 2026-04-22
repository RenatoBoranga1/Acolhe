from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import IncidentRecord, SafetyPlan, TrustedContact, User
from app.modules.settings.schemas import ExportBundleResponse, SettingsResponse, SettingsUpdateRequest
from app.repositories.auth_repository import AuthRepository
from app.repositories.chat_repository import ChatRepository
from app.repositories.settings_repository import SettingsRepository


class SettingsService:
    def __init__(self) -> None:
        self.auth_repository = AuthRepository()
        self.settings_repository = SettingsRepository()
        self.chat_repository = ChatRepository()

    def _user(self, session: Session) -> User:
        user = self.auth_repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return user

    def _serialize(self, setting) -> SettingsResponse:
        return SettingsResponse(
            id=setting.id,
            quick_exit_enabled=setting.quick_exit_enabled,
            notifications_hidden=setting.notifications_hidden,
            discreet_mode=setting.discreet_mode,
            discreet_app_name=setting.discreet_app_name,
            notification_title=setting.notification_title,
            export_format=setting.export_format,
        )

    def get(self, session: Session) -> SettingsResponse:
        user = self._user(session)
        setting = self.settings_repository.get_or_create(session, user.id)
        return self._serialize(setting)

    def update(self, session: Session, payload: SettingsUpdateRequest) -> SettingsResponse:
        user = self._user(session)
        setting = self.settings_repository.get_or_create(session, user.id)
        for key, value in payload.model_dump().items():
            setattr(setting, key, value)
        return self._serialize(self.settings_repository.save(session, setting))

    def export_bundle(self, session: Session) -> ExportBundleResponse:
        user = self._user(session)
        setting = self.settings_repository.get_or_create(session, user.id)
        conversations = []
        for conversation in self.chat_repository.list_conversations(session, user.id):
            messages = self.chat_repository.list_messages(session, conversation.id)
            conversations.append(
                {
                    "id": conversation.id,
                    "title": conversation.title,
                    "last_risk_level": conversation.last_risk_level,
                    "messages": [
                        {
                            "role": message.role,
                            "content": message.content,
                            "risk_level": message.risk_level,
                            "created_at": message.created_at.isoformat(),
                        }
                        for message in messages
                    ],
                }
            )
        incident_records = [
            {
                "id": item.id,
                "description": item.description,
                "location": item.location,
                "chronological_summary": item.chronological_summary,
            }
            for item in session.query(IncidentRecord).filter(IncidentRecord.user_id == user.id)
        ]
        trusted_contacts = [
            {
                "id": item.id,
                "name": item.name,
                "relationship": item.relationship,
                "phone": item.phone,
                "email": item.email,
            }
            for item in session.query(TrustedContact).filter(TrustedContact.user_id == user.id)
        ]
        plan = session.query(SafetyPlan).filter(SafetyPlan.user_id == user.id).one_or_none()
        return ExportBundleResponse(
            profile={
                "id": user.id,
                "display_name": user.display_name,
                "biometrics_enabled": user.biometrics_enabled,
                "discreet_mode": user.discreet_mode,
            },
            settings=self._serialize(setting).model_dump(),
            conversations=conversations,
            incident_records=incident_records,
            trusted_contacts=trusted_contacts,
            safety_plan={
                "safe_locations": plan.safe_locations,
                "warning_signs": plan.warning_signs,
                "immediate_steps": plan.immediate_steps,
                "priority_contacts": plan.priority_contacts,
                "personal_notes": plan.personal_notes,
                "emergency_checklist": plan.emergency_checklist,
            }
            if plan
            else None,
        )

    def purge(self, session: Session) -> dict[str, str]:
        user = self._user(session)
        self.settings_repository.purge_user_data(session, user.id)
        return {"status": "ok", "message": "Dados sensiveis removidos com sucesso."}
