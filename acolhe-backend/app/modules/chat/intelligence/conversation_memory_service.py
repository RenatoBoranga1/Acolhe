from __future__ import annotations

import re
import unicodedata
from typing import Sequence

from app.models import Message
from app.modules.chat.intelligence.models import (
    ConversationMemory,
    RiskAssessmentResult,
    SituationClassification,
)


class ConversationMemoryService:
    MEMORY_KEY = "conversation_memory"

    EMOTIONAL_PATTERNS = {
        "fear": ("medo", "assustada", "apavorada", "receio", "pavor"),
        "shame": ("vergonha", "envergonhada", "humilhada"),
        "guilt": ("culpa", "culpada", "eu provoquei", "talvez eu tenha"),
        "confusion": ("confusa", "duvida", "nao sei", "exagerando"),
        "crisis": ("panico", "desesperada", "nao aguento", "sem controle", "crise"),
        "anger": ("raiva", "revoltada", "indignada"),
    }
    RELATION_PATTERNS = {
        "boss": ("chefe", "supervisor", "gerente", "lider"),
        "coworker": ("colega de trabalho", "colega", "trabalho"),
        "teacher": ("professor", "orientador", "faculdade", "escola", "curso"),
        "partner": ("marido", "namorado", "companheiro", "parceiro"),
        "ex_partner": ("ex", "ex namorado", "ex marido", "ex parceir"),
        "stranger": ("desconhecido", "estranho"),
    }

    def load(self, *, conversation_id: str, messages: Sequence[Message]) -> ConversationMemory:
        for message in reversed(messages):
            metadata = message.message_metadata or {}
            snapshot = metadata.get(self.MEMORY_KEY)
            if isinstance(snapshot, dict):
                return ConversationMemory.from_dict(snapshot, conversation_id=conversation_id)
        return ConversationMemory(conversation_id=conversation_id)

    def update(
        self,
        *,
        memory: ConversationMemory,
        latest_message: str,
        history: Sequence[dict[str, str]],
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        response_mode: str,
    ) -> ConversationMemory:
        normalized = self._normalize(latest_message)
        known_facts = list(memory.known_facts)

        emotional_state = self._detect_emotional_state(normalized) or memory.user_emotional_state
        aggressor_relation = self._detect_relation(normalized) or memory.aggressor_relation
        repeated_behavior = self._detect_repetition(normalized) or memory.repeated_behavior
        support_status = self._detect_support_status(normalized) or memory.support_network_status
        wants_to_report = self._detect_reporting(normalized) or memory.wants_to_report
        evidence_status = self._detect_evidence(normalized) or memory.evidence_status
        immediate_fear = (
            memory.immediate_fear
            or risk.level in {"high", "critical"}
            or any(term in normalized for term in ("medo de encontrar", "vai me encontrar", "hoje", "agora"))
        )

        for fact in self._extract_facts(
            emotional_state=emotional_state,
            aggressor_relation=aggressor_relation,
            repeated_behavior=repeated_behavior,
            support_status=support_status,
            wants_to_report=wants_to_report,
            evidence_status=evidence_status,
            immediate_fear=immediate_fear,
            situation_type=situation.type,
        ):
            if fact not in known_facts:
                known_facts.append(fact)

        updated = ConversationMemory(
            conversation_id=memory.conversation_id,
            user_emotional_state=emotional_state,
            current_risk_level=risk.level,
            current_situation_type=situation.type,
            aggressor_relation=aggressor_relation,
            repeated_behavior=repeated_behavior,
            immediate_fear=immediate_fear,
            support_network_status=support_status,
            wants_to_report=wants_to_report,
            evidence_status=evidence_status,
            conversation_goal=self._goal_for_situation(situation.type),
            last_summary=self._summarize(
                latest_message=latest_message,
                history=history,
                risk=risk,
                situation=situation,
                emotional_state=emotional_state,
            ),
            response_mode=response_mode,
            known_facts=known_facts[-12:],
        )
        return updated

    def to_prompt_context(self, memory: ConversationMemory) -> str:
        facts = "; ".join(memory.known_facts[-8:]) if memory.known_facts else "sem fatos estruturados anteriores"
        return (
            "Resumo estruturado da conversa: "
            f"estado_emocional={memory.user_emotional_state}; "
            f"risco_atual={memory.current_risk_level}; "
            f"tipo_situacao={memory.current_situation_type}; "
            f"relacao_com_agressor={memory.aggressor_relation}; "
            f"recorrencia={memory.repeated_behavior}; "
            f"medo_imediato={memory.immediate_fear}; "
            f"rede_apoio={memory.support_network_status}; "
            f"desejo_denunciar={memory.wants_to_report}; "
            f"evidencias={memory.evidence_status}; "
            f"objetivo={memory.conversation_goal}; "
            f"resumo_progressivo={memory.last_summary or 'ainda sem resumo'}; "
            f"fatos={facts}."
        )

    def _detect_emotional_state(self, normalized: str) -> str | None:
        for state, patterns in self.EMOTIONAL_PATTERNS.items():
            if any(pattern in normalized for pattern in patterns):
                return state
        return None

    def _detect_relation(self, normalized: str) -> str | None:
        for relation, patterns in self.RELATION_PATTERNS.items():
            if any(pattern in normalized for pattern in patterns):
                return relation
        return None

    def _detect_repetition(self, normalized: str) -> str | None:
        if any(term in normalized for term in ("toda semana", "sempre", "varias vezes", "todo dia", "recorrente")):
            return "yes"
        if any(term in normalized for term in ("primeira vez", "uma vez", "foi so uma vez")):
            return "no"
        return None

    def _detect_support_status(self, normalized: str) -> str | None:
        if any(term in normalized for term in ("estou sozinha", "nao tenho ninguem", "sem apoio")):
            return "isolated"
        if any(term in normalized for term in ("amiga", "mae", "irma", "pessoa de confianca", "rede de apoio")):
            return "mentioned"
        if any(term in normalized for term in ("quero falar com alguem", "contar para alguem", "pedir apoio")):
            return "seeking"
        return None

    def _detect_reporting(self, normalized: str) -> str | None:
        if any(term in normalized for term in ("quero denunciar", "vou denunciar")):
            return "yes"
        if any(term in normalized for term in ("nao quero denunciar", "nao vou denunciar")):
            return "no"
        if any(term in normalized for term in ("denunciar", "delegacia", "boletim", "nao consigo decidir")):
            return "unsure"
        return None

    def _detect_evidence(self, normalized: str) -> str | None:
        if any(term in normalized for term in ("print", "prints", "mensagem", "audio", "prova", "evidencia", "video")):
            return "mentioned"
        if any(term in normalized for term in ("sem provas", "nao tenho prova", "apaguei")):
            return "not_available"
        return None

    def _extract_facts(
        self,
        *,
        emotional_state: str,
        aggressor_relation: str,
        repeated_behavior: str,
        support_status: str,
        wants_to_report: str,
        evidence_status: str,
        immediate_fear: bool,
        situation_type: str,
    ) -> list[str]:
        facts = [f"tipo atual: {situation_type}", f"estado emocional: {emotional_state}"]
        if aggressor_relation != "unknown":
            facts.append(f"relacao mencionada: {aggressor_relation}")
        if repeated_behavior != "unknown":
            facts.append(f"recorrencia: {repeated_behavior}")
        if support_status != "not_mentioned":
            facts.append(f"rede de apoio: {support_status}")
        if wants_to_report != "not_mentioned":
            facts.append(f"denuncia: {wants_to_report}")
        if evidence_status != "not_mentioned":
            facts.append(f"evidencias: {evidence_status}")
        if immediate_fear:
            facts.append("medo imediato mencionado")
        return facts

    def _goal_for_situation(self, situation_type: str) -> str:
        mapping = {
            "harassment_uncertainty": "understand_without_pressure",
            "initial_disclosure": "tell_story_safely",
            "fear_of_reencounter": "immediate_safety_planning",
            "workplace_harassment": "workplace_safety_and_record",
            "academic_harassment": "academic_safety_and_record",
            "partner_harassment": "relationship_safety",
            "stalking": "safety_and_support",
            "coercion_manipulation": "safety_and_boundaries",
            "reporting_ambivalence": "decision_support",
            "incident_record": "structured_record",
            "support_request": "contact_support",
            "emotional_crisis": "stabilization",
            "immediate_risk": "urgent_safety",
        }
        return mapping.get(situation_type, "understand_and_support")

    def _summarize(
        self,
        *,
        latest_message: str,
        history: Sequence[dict[str, str]],
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        emotional_state: str,
    ) -> str:
        user_turns = [item["content"] for item in history if item.get("role") == "user"]
        recent = user_turns[-3:] if user_turns else [latest_message]
        compact = " | ".join(self._compact(item) for item in recent)
        return (
            f"Situacao atual classificada como {situation.type}, risco {risk.level}, "
            f"estado emocional {emotional_state}. Ultimos pontos: {compact}."
        )

    def _compact(self, text: str, limit: int = 140) -> str:
        compact = re.sub(r"\s+", " ", text).strip()
        if len(compact) <= limit:
            return compact
        return f"{compact[: limit - 3].rstrip()}..."

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()
