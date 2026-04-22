from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import SafetyPlan, User
from app.modules.safety_plan.schemas import SafetyPlanResponse, SafetyPlanUpsertRequest
from app.repositories.auth_repository import AuthRepository
from app.repositories.support_repository import SupportRepository


class SafetyPlanService:
    def __init__(self) -> None:
        self.auth_repository = AuthRepository()
        self.repository = SupportRepository()

    def _user(self, session: Session) -> User:
        user = self.auth_repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return user

    def _serialize(self, plan: SafetyPlan) -> SafetyPlanResponse:
        return SafetyPlanResponse(
            id=plan.id,
            safe_locations=plan.safe_locations,
            warning_signs=plan.warning_signs,
            immediate_steps=plan.immediate_steps,
            priority_contacts=plan.priority_contacts,
            personal_notes=plan.personal_notes,
            emergency_checklist=plan.emergency_checklist,
            updated_at=plan.updated_at,
        )

    def get(self, session: Session) -> SafetyPlanResponse:
        user = self._user(session)
        plan = self.repository.get_safety_plan(session, user.id)
        if plan is None:
            plan = SafetyPlan(user_id=user.id)
            plan = self.repository.save_safety_plan(session, plan)
        return self._serialize(plan)

    def upsert(self, session: Session, payload: SafetyPlanUpsertRequest) -> SafetyPlanResponse:
        user = self._user(session)
        plan = self.repository.get_safety_plan(session, user.id)
        if plan is None:
            plan = SafetyPlan(user_id=user.id, **payload.model_dump())
        else:
            for key, value in payload.model_dump().items():
                setattr(plan, key, value)
        plan = self.repository.save_safety_plan(session, plan)
        return self._serialize(plan)
