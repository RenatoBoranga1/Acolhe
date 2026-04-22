from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.safety_plan.schemas import SafetyPlanResponse, SafetyPlanUpsertRequest
from app.modules.safety_plan.service import SafetyPlanService

router = APIRouter()
service = SafetyPlanService()


@router.get("", response_model=SafetyPlanResponse)
def get_safety_plan(session: Session = Depends(get_db)) -> SafetyPlanResponse:
    return service.get(session)


@router.post("", response_model=SafetyPlanResponse)
def upsert_safety_plan(
    payload: SafetyPlanUpsertRequest,
    session: Session = Depends(get_db),
) -> SafetyPlanResponse:
    try:
        return service.upsert(session, payload)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
