from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AppSetting, User


class AuthRepository:
    def get_primary_user(self, session: Session) -> User | None:
        return session.scalar(select(User).order_by(User.created_at.asc()).limit(1))

    def save_user(self, session: Session, user: User) -> User:
        session.add(user)
        session.commit()
        session.refresh(user)
        return user

    def get_or_create_settings(self, session: Session, user_id: str) -> AppSetting:
        setting = session.scalar(select(AppSetting).where(AppSetting.user_id == user_id))
        if setting is None:
            setting = AppSetting(user_id=user_id)
            session.add(setting)
            session.commit()
            session.refresh(setting)
        return setting
