from __future__ import annotations

from dataclasses import asdict, dataclass, field

from app.modules.risk.schemas import RiskAssessmentResponse


RISK_ORDER = {"low": 0, "moderate": 1, "high": 2, "critical": 3}


@dataclass
class ConversationMemory:
    conversation_id: str
    user_emotional_state: str = "uncertain"
    current_risk_level: str = "low"
    current_situation_type: str = "initial_disclosure"
    aggressor_relation: str = "unknown"
    repeated_behavior: str = "unknown"
    immediate_fear: bool = False
    support_network_status: str = "not_mentioned"
    wants_to_report: str = "not_mentioned"
    evidence_status: str = "not_mentioned"
    conversation_goal: str = "understand_and_support"
    last_summary: str = ""
    response_mode: str = "calm_support"
    known_facts: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, payload: dict, *, conversation_id: str) -> "ConversationMemory":
        data = dict(payload or {})
        data["conversation_id"] = conversation_id
        known_facts = data.get("known_facts")
        if not isinstance(known_facts, list):
            data["known_facts"] = []
        allowed = set(cls.__dataclass_fields__.keys())
        return cls(**{key: value for key, value in data.items() if key in allowed})

    def risk_rank(self) -> int:
        return RISK_ORDER.get(self.current_risk_level, 0)


@dataclass(frozen=True)
class RiskAssessmentResult:
    level: str
    score: float
    triggers: list[str]
    rationale: str
    recommended_mode: str
    recommended_actions: list[str]
    requires_immediate_action: bool

    def to_response(self) -> RiskAssessmentResponse:
        return RiskAssessmentResponse(
            level=self.level,
            score=max(0, min(10, round(self.score * 10))),
            reasons=self.triggers or [self.rationale],
            recommended_actions=self.recommended_actions,
            requires_immediate_action=self.requires_immediate_action,
        )

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class SituationClassification:
    type: str
    confidence: float
    signals: list[str]

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class ResponseMode:
    name: str
    rationale: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class PromptBundle:
    system_prompts: list[str]
    response_guidance: str


@dataclass(frozen=True)
class ResponseValidationResult:
    text: str
    issues: list[str]
    repaired: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class ChatOrchestrationResult:
    assistant_text: str
    risk: RiskAssessmentResult
    situation: SituationClassification
    memory: ConversationMemory
    response_mode: ResponseMode
    validation: ResponseValidationResult
    ctas: list[str]
