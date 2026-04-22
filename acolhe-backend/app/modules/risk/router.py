from __future__ import annotations

from fastapi import APIRouter

from app.modules.risk.schemas import RiskAssessmentRequest, RiskAssessmentResponse
from app.modules.risk.service import RiskService

router = APIRouter()
service = RiskService()


@router.post("/risk-assessment", response_model=RiskAssessmentResponse)
def assess_risk(payload: RiskAssessmentRequest) -> RiskAssessmentResponse:
    return service.assess(payload.message)
