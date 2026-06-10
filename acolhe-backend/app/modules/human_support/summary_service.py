from __future__ import annotations

from dataclasses import asdict, dataclass

from app.models import Conversation, Message
from app.modules.chat.intelligence.conversation_memory_service import (
    ConversationMemoryService,
)
from app.modules.chat.intelligence.risk_assessment_service import (
    RiskAssessmentService,
)
from app.modules.chat.intelligence.situation_classifier_service import (
    SituationClassifierService,
)
from app.modules.chat.intelligence.tone_selector_service import ToneSelectorService


@dataclass(frozen=True)
class SupportHandoffSummary:
    context_main: str
    emotional_state: str
    risk_level: str
    situation_type: str
    points_to_avoid: list[str]
    suggested_next_steps: list[str]
    safety_alerts: list[str]
    supporter_copilot_suggestions: list[str]
    supporter_reminders: list[str]
    summary_text: str
    priority_score: float

    def to_dict(self) -> dict:
        return asdict(self)


class SupportSummaryService:
    def __init__(self) -> None:
        self.memory_service = ConversationMemoryService()
        self.risk_service = RiskAssessmentService()
        self.situation_service = SituationClassifierService()
        self.tone_service = ToneSelectorService()

    def build(
        self,
        *,
        conversation: Conversation | None,
        messages: list[Message],
    ) -> SupportHandoffSummary:
        conversation_id = conversation.id if conversation is not None else "support-handoff"
        history = [{"role": item.role, "content": item.content} for item in messages]
        last_user_message = next(
            (item.content for item in reversed(messages) if item.role == "user"),
            "",
        )
        fallback_context = " ".join(item.content for item in messages[-3:]).strip()
        reference_text = last_user_message or fallback_context or "A pessoa pediu apoio humano."

        memory = self.memory_service.load(conversation_id=conversation_id, messages=messages)
        situation = self.situation_service.classify(
            message=reference_text,
            history=history,
            memory=memory,
        )
        risk = self.risk_service.assess(
            message=reference_text,
            history=history,
            memory=memory,
            situation=situation,
        )
        response_mode = self.tone_service.select(
            risk=risk,
            situation=situation,
            memory=memory,
            history=history,
        )
        updated_memory = self.memory_service.update(
            memory=memory,
            latest_message=reference_text,
            history=history,
            risk=risk,
            situation=situation,
            response_mode=response_mode.name,
        )

        points_to_avoid = [
            "Nao pressionar denuncia ou confronto imediato.",
            "Nao pedir detalhes intimos desnecessarios.",
            "Nao prometer sigilo absoluto ou solucao garantida.",
        ]
        if risk.level in {"high", "critical"}:
            points_to_avoid.append(
                "Nao prolongar a conversa antes de checar seguranca imediata."
            )

        safety_alerts = []
        if updated_memory.immediate_fear or risk.level in {"high", "critical"}:
            safety_alerts.append(
                "Priorizar local seguro, pessoa de confianca e orientacao de emergencia."
            )
        if updated_memory.support_network_status == "isolated":
            safety_alerts.append(
                "Pessoa sinaliza isolamento ou dificuldade de pedir ajuda."
            )
        if updated_memory.wants_to_report == "unsure":
            safety_alerts.append(
                "Existe ambivalencia sobre denunciar; oferecer opcoes sem pressao."
            )

        suggested_next_steps = list(risk.recommended_actions[:3])
        if updated_memory.evidence_status == "mentioned":
            suggested_next_steps.append("Ajudar a organizar fatos e evidencias sem forcar detalhes.")
        if updated_memory.support_network_status in {"seeking", "mentioned"}:
            suggested_next_steps.append("Explorar quem pode compor a rede de apoio agora.")

        supporter_copilot_suggestions = self._copilot_suggestions(
            risk_level=risk.level,
            situation_type=situation.type,
            emotional_state=updated_memory.user_emotional_state,
        )
        supporter_reminders = [
            "Acolher sem julgar.",
            "Oferecer opcoes, nao ordens.",
            "Encaminhar ajuda real em risco alto ou critico.",
        ]
        if risk.level in {"high", "critical"}:
            supporter_reminders.append(
                "Usar frases curtas e objetivas antes de explorar outros temas."
            )

        summary_text = (
            f"Pessoa relata {self._situation_phrase(situation.type)}, com estado emocional "
            f"{updated_memory.user_emotional_state} e risco {risk.level}. "
            f"Recomenda-se acolher com calma, evitar julgamentos e priorizar "
            f"{'seguranca imediata' if risk.level in {'high', 'critical'} else 'organizacao segura dos proximos passos'}."
        )

        priority_score = self._priority_score(
            risk_level=risk.level,
            situation_type=situation.type,
            immediate_fear=updated_memory.immediate_fear,
            support_network_status=updated_memory.support_network_status,
        )

        return SupportHandoffSummary(
            context_main=updated_memory.last_summary or summary_text,
            emotional_state=updated_memory.user_emotional_state,
            risk_level=risk.level,
            situation_type=situation.type,
            points_to_avoid=points_to_avoid,
            suggested_next_steps=self._deduplicate(suggested_next_steps),
            safety_alerts=self._deduplicate(safety_alerts),
            supporter_copilot_suggestions=self._deduplicate(
                supporter_copilot_suggestions
            ),
            supporter_reminders=self._deduplicate(supporter_reminders),
            summary_text=summary_text,
            priority_score=priority_score,
        )

    def _priority_score(
        self,
        *,
        risk_level: str,
        situation_type: str,
        immediate_fear: bool,
        support_network_status: str,
    ) -> float:
        base = {
            "low": 0.2,
            "moderate": 0.5,
            "high": 0.82,
            "critical": 0.98,
        }.get(risk_level, 0.4)
        if situation_type in {"fear_of_reencounter", "stalking", "immediate_risk"}:
            base += 0.08
        if immediate_fear:
            base += 0.05
        if support_network_status == "isolated":
            base += 0.04
        return round(min(base, 1.0), 2)

    def _copilot_suggestions(
        self,
        *,
        risk_level: str,
        situation_type: str,
        emotional_state: str,
    ) -> list[str]:
        suggestions = [
            "Comece validando o desconforto sem repetir frases prontas demais.",
            "Use perguntas curtas e nao invasivas para entender o que a pessoa precisa agora.",
        ]
        if situation_type in {"incident_record", "workplace_harassment"}:
            suggestions.append(
                "Ofereca ajuda para organizar fatos por data, local e pessoas presentes."
            )
        if situation_type == "reporting_ambivalence":
            suggestions.append(
                "Ajude a comparar opcoes sem pressionar denuncia ou decisao imediata."
            )
        if risk_level in {"high", "critical"}:
            suggestions.append(
                "Priorize frases diretas sobre seguranca antes de aprofundar o relato."
            )
        if emotional_state in {"fear", "crisis"}:
            suggestions.append(
                "Reduza o ritmo, use linguagem simples e cheque se a pessoa consegue acionar apoio."
            )
        return suggestions

    def _situation_phrase(self, situation_type: str) -> str:
        mapping = {
            "harassment_uncertainty": "duvida se a situacao configura assedio",
            "fear_of_reencounter": "medo de reencontro com a pessoa envolvida",
            "workplace_harassment": "situacao de assedio no ambiente de trabalho",
            "incident_record": "necessidade de registrar fatos com clareza",
            "reporting_ambivalence": "ambivalencia sobre denunciar ou agir",
            "emotional_crisis": "crise emocional intensa",
            "support_request": "necessidade de apoio humano e rede de confianca",
            "stalking": "perseguicao ou vigilancia recorrente",
        }
        return mapping.get(situation_type, "uma situacao dificil que pede acolhimento")

    def _deduplicate(self, items: list[str]) -> list[str]:
        deduped: list[str] = []
        for item in items:
            normalized = item.strip()
            if normalized and normalized not in deduped:
                deduped.append(normalized)
        return deduped
