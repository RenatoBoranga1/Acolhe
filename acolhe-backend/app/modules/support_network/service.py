from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import TrustedContact, User
from app.modules.support_network.schemas import TrustedContactCreate, TrustedContactResponse
from app.repositories.auth_repository import AuthRepository
from app.repositories.support_repository import SupportRepository


class SupportNetworkService:
    def __init__(self) -> None:
        self.auth_repository = AuthRepository()
        self.repository = SupportRepository()

    def _user(self, session: Session) -> User:
        user = self.auth_repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return user

    def _serialize(self, contact: TrustedContact) -> TrustedContactResponse:
        return TrustedContactResponse(
            id=contact.id,
            name=contact.name,
            relationship=contact.relationship,
            phone=contact.phone,
            email=contact.email,
            priority=contact.priority,
            ready_message=contact.ready_message,
            updated_at=contact.updated_at,
        )

    def list_contacts(self, session: Session) -> list[TrustedContactResponse]:
        user = self._user(session)
        return [self._serialize(item) for item in self.repository.list_contacts(session, user.id)]

    def create_contact(self, session: Session, payload: TrustedContactCreate) -> TrustedContactResponse:
        user = self._user(session)
        contact = TrustedContact(user_id=user.id, **payload.model_dump())
        contact = self.repository.save_contact(session, contact)
        return self._serialize(contact)
