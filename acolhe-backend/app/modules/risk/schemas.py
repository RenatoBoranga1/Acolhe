from __future__ import annotations

from pydantic import BaseModel, Field


class RiskAssessmentRequest(BaseModel):
    message: str = Field(min_length=1, max_length=5000)


class RiskAssessmentResponse(BaseModel):
    level: str
    score: int
    reasons: list[str]
    recommended_actions: list[str]
    requires_immediate_action: bool
