from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.security import hash_pin, verify_pin
from app.models import User
from app.repositories.auth_repository import AuthRepository
from app.schemas.common import UserSnapshot


class AuthService:
    def __init__(self) -> None:
        self.repository = AuthRepository()

    def _snapshot(self, user: User) -> UserSnapshot:
        return UserSnapshot(
            id=user.id,
            display_name=user.display_name,
            biometrics_enabled=user.biometrics_enabled,
            discreet_mode=user.discreet_mode,
            auto_lock_minutes=user.auto_lock_minutes,
        )

    def get_status(self, session: Session) -> UserSnapshot:
        user = self.repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return self._snapshot(user)

    def setup_pin(self, session: Session, *, pin: str, display_name: str | None) -> UserSnapshot:
        user = self.repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        user.hashed_pin = hash_pin(pin)
        if display_name:
            user.display_name = display_name
        self.repository.save_user(session, user)
        return self._snapshot(user)

    def verify(self, session: Session, *, pin: str) -> tuple[bool, UserSnapshot | None]:
        user = self.repository.get_primary_user(session)
        if user is None:
            return False, None
        valid = verify_pin(pin, user.hashed_pin)
        return valid, self._snapshot(user) if valid else None

    def update_preferences(
        self,
        session: Session,
        *,
        biometrics_enabled: bool,
        discreet_mode: bool,
        auto_lock_minutes: int,
    ) -> UserSnapshot:
        user = self.repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        user.biometrics_enabled = biometrics_enabled
        user.discreet_mode = discreet_mode
        user.auto_lock_minutes = auto_lock_minutes
        self.repository.save_user(session, user)
        setting = self.repository.get_or_create_settings(session, user.id)
        setting.discreet_mode = discreet_mode
        session.add(setting)
        session.commit()
        return self._snapshot(user)
