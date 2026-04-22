from __future__ import annotations

from typing import Sequence

from app.modules.chat.intelligence.models import (
    ConversationMemory,
    ResponseMode,
    RiskAssessmentResult,
    SituationClassification,
)


class ToneSelectorService:
    def select(
        self,
        *,
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        memory: ConversationMemory,
        history: Sequence[dict[str, str]],
    ) -> ResponseMode:
        if risk.level in {"high", "critical"} or situation.type == "immediate_risk":
            return ResponseMode("safety_first", "risco elevado exige resposta curta e focada em protecao")

        if situation.type in {"fear_of_reencounter", "stalking"} and risk.score >= 0.38:
            return ResponseMode("safety_first", "medo de reencontro ou perseguicao pede foco pratico em seguranca")

        if situation.type == "emotional_crisis" or memory.user_emotional_state == "crisis":
            return ResponseMode("grounding_mode", "sinais de crise emocional pedem frases simples e estabilizacao")

        if situation.type in {"reporting_ambivalence", "support_request"} or memory.wants_to_report in {"yes", "unsure"}:
            return ResponseMode("decision_support", "a pessoa esta avaliando uma acao e precisa de opcoes sem pressao")

        if situation.type in {
            "harassment_uncertainty",
            "incident_record",
            "workplace_harassment",
            "academic_harassment",
            "coercion_manipulation",
        }:
            return ResponseMode("structured_guidance", "a situacao pede analise cuidadosa e organizacao dos fatos")

        return ResponseMode("calm_support", "estado emocional pede acolhimento calmo e continuidade")
