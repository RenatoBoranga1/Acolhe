from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import SafetyPlan, TrustedContact


class SupportRepository:
    def get_safety_plan(self, session: Session, user_id: str) -> SafetyPlan | None:
        stmt = select(SafetyPlan).where(SafetyPlan.user_id == user_id)
        return session.scalar(stmt)

    def save_safety_plan(self, session: Session, plan: SafetyPlan) -> SafetyPlan:
        session.add(plan)
        session.commit()
        session.refresh(plan)
        return plan

    def list_contacts(self, session: Session, user_id: str) -> list[TrustedContact]:
        stmt = (
            select(TrustedContact)
            .where(TrustedContact.user_id == user_id)
            .order_by(TrustedContact.priority.asc(), TrustedContact.name.asc())
        )
        return list(session.scalars(stmt))

    def save_contact(self, session: Session, contact: TrustedContact) -> TrustedContact:
        session.add(contact)
        session.commit()
        session.refresh(contact)
        return contact
