from __future__ import annotations

import re
import unicodedata
from typing import Sequence

from app.modules.chat.intelligence.models import (
    ConversationMemory,
    ResponseMode,
    ResponseValidationResult,
    RiskAssessmentResult,
    SituationClassification,
)


class ResponseValidatorService:
    FORBIDDEN_AUTHORITY = (
        "como psicologa",
        "como advogada",
        "como policial",
        "diagnostico",
        "voce deve denunciar",
        "legalmente isso e",
        "garanto que",
    )
    MINIMIZING = ("nao foi nada", "voce esta exagerando", "esquece isso", "isso e normal")
    SAFETY_TERMS = ("seguranca", "seguro", "emergencia", "pessoa de confianca", "ajuda")
    GENERIC_MARKERS = (
        "sinto muito",
        "estou aqui",
        "posso te ajudar",
        "sem julgamentos",
        "no seu ritmo",
        "com calma",
        "se quiser",
        "proximos passos",
    )
    OPENING_FAMILIES = {
        "validation": (
            "faz sentido",
            "entendo",
            "imagino",
            "isso parece",
            "isso deve",
            "da para entender",
        ),
        "support_offer": ("posso te ajudar", "estou aqui", "a gente pode", "podemos"),
        "safety": ("sua seguranca", "quero priorizar", "antes de qualquer coisa"),
        "record": ("organizar", "registrar", "colocar em ordem"),
    }

    def validate(
        self,
        *,
        candidate: str,
        fallback: str,
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        response_mode: ResponseMode,
        memory: ConversationMemory,
        recent_assistant_messages: Sequence[str],
    ) -> ResponseValidationResult:
        text = self._compact(candidate)
        issues: list[str] = []

        if not text:
            return ResponseValidationResult(text=fallback, issues=["empty_response"], repaired=True)

        normalized = self._normalize(text)
        if any(term in normalized for term in self.FORBIDDEN_AUTHORITY):
            issues.append("false_authority")
        if any(term in normalized for term in self.MINIMIZING):
            issues.append("minimizing")
        if self._is_repetitive(normalized, recent_assistant_messages):
            issues.append("repetitive")
        if self._has_structural_repetition(text, recent_assistant_messages):
            issues.append("structural_repetition")
        if self._is_too_generic(normalized, situation, memory):
            issues.append("too_generic")
        if self._lacks_situation_specificity(normalized, situation, memory):
            issues.append("insufficient_specificity")

        max_sentences = 2 if risk.level in {"high", "critical"} or response_mode.name == "safety_first" else 4
        limited = self._limit_sentences(text, max_sentences=max_sentences)
        if limited != text:
            issues.append("too_long")
            text = limited

        if risk.level in {"high", "critical"}:
            if not any(term in normalized for term in self.SAFETY_TERMS):
                issues.append("missing_safety_focus")
            if len(text) > 360:
                issues.append("too_long_for_risk")

        if issues:
            return ResponseValidationResult(text=fallback, issues=issues, repaired=True)

        return ResponseValidationResult(text=text, issues=[])

    def _is_repetitive(self, normalized: str, recent_messages: Sequence[str]) -> bool:
        for message in recent_messages[-3:]:
            other = self._normalize(message)
            if normalized == other or normalized in other or other in normalized:
                return True
            if self._token_overlap(normalized, other) >= 0.75:
                return True
        return False

    def _has_structural_repetition(self, text: str, recent_messages: Sequence[str]) -> bool:
        signature = self._structure_signature(text)
        opening_family = self._opening_family(text)
        if not signature:
            return False
        for message in recent_messages[-4:]:
            other_signature = self._structure_signature(message)
            if signature == other_signature and len(signature) >= 2:
                return True
            if opening_family and opening_family == self._opening_family(message):
                current_intents = self._sentence_intents(text)
                other_intents = self._sentence_intents(message)
                if current_intents and current_intents[:2] == other_intents[:2]:
                    return True
        return False

    def _is_too_generic(
        self,
        normalized: str,
        situation: SituationClassification,
        memory: ConversationMemory,
    ) -> bool:
        generic_count = sum(1 for marker in self.GENERIC_MARKERS if marker in normalized)
        if generic_count < 2 and "sinto muito que voce esteja passando por isso" not in normalized:
            return False
        expected_terms = self._specificity_terms(situation, memory)
        return not any(term in normalized for term in expected_terms)

    def _lacks_situation_specificity(
        self,
        normalized: str,
        situation: SituationClassification,
        memory: ConversationMemory,
    ) -> bool:
        if situation.type in {"initial_disclosure", "support_request"}:
            return False
        expected_terms = self._specificity_terms(situation, memory)
        anchor_count = sum(1 for term in expected_terms if term and term in normalized)
        required = 1 if situation.type in {"emotional_crisis", "fear_of_reencounter"} else 2
        if anchor_count >= required:
            return False
        if memory.known_facts:
            facts = [self._normalize(item) for item in memory.known_facts[-4:]]
            if any(self._token_overlap(normalized, fact) >= 0.25 for fact in facts):
                return False
        return True

    def _limit_sentences(self, text: str, *, max_sentences: int) -> str:
        sentences = [item.strip() for item in re.split(r"(?<=[.!?])\s+", text) if item.strip()]
        if len(sentences) <= max_sentences:
            return text
        return " ".join(sentences[:max_sentences])

    def _specificity_terms(
        self,
        situation: SituationClassification,
        memory: ConversationMemory,
    ) -> tuple[str, ...]:
        terms = {
            "fear_of_reencounter": (
                "seguranca",
                "seguro",
                "encontrar",
                "hoje",
                "apoio",
                "local",
                "companhia",
            ),
            "incident_record": (
                "registro",
                "data",
                "hora",
                "local",
                "fatos",
                "resumo",
                "prints",
                "testemunhas",
            ),
            "reporting_ambivalence": (
                "opcoes",
                "decidir",
                "denunciar",
                "pressao",
                "preparar",
                "orientacao",
            ),
            "harassment_uncertainty": (
                "duvida",
                "fatos",
                "padrao",
                "contexto",
                "repeticao",
                "comentarios",
                "limite",
            ),
            "workplace_harassment": (
                "trabalho",
                "chefe",
                "hierarquia",
                "ambiente",
                "registro",
                "rotina",
                "retaliacao",
            ),
            "emotional_crisis": (
                "respirar",
                "pausa",
                "agora",
                "apoio",
                "sentar",
                "agua",
            ),
        }.get(situation.type, ("fatos", "seguranca", "apoio", memory.user_emotional_state))
        dynamic_terms = [
            memory.user_emotional_state,
            memory.aggressor_relation,
            memory.repeated_behavior,
            memory.evidence_status,
        ]
        return tuple(term for term in (*terms, *dynamic_terms) if term and term != "unknown")

    def _structure_signature(self, text: str) -> tuple[str, ...]:
        intents = self._sentence_intents(text)
        if len(intents) <= 4:
            return tuple(intents)
        return tuple(intents[:4])

    def _sentence_intents(self, text: str) -> list[str]:
        sentences = [item.strip() for item in re.split(r"(?<=[.!?])\s+", text) if item.strip()]
        return [self._sentence_intent(sentence) for sentence in sentences[:4]]

    def _sentence_intent(self, sentence: str) -> str:
        normalized = self._normalize(sentence)
        if normalized.endswith("?"):
            return "question"
        if any(term in normalized for term in ("seguranca", "emergencia", "local seguro", "risco")):
            return "safety"
        if any(term in normalized for term in ("faz sentido", "entendo", "imagino", "parece")):
            return "validation"
        if any(term in normalized for term in ("pode", "opcao", "caminho", "sem pressao")):
            return "options"
        if any(term in normalized for term in ("registr", "data", "local", "testemunha", "prints")):
            return "record"
        if any(term in normalized for term in ("posso", "podemos", "a gente pode", "te ajudar")):
            return "offer"
        return "context"

    def _opening_family(self, text: str) -> str:
        first_sentence = self._normalize(self._limit_sentences(text, max_sentences=1))
        for family, markers in self.OPENING_FAMILIES.items():
            if any(first_sentence.startswith(marker) for marker in markers):
                return family
        return ""

    def _compact(self, text: str) -> str:
        compact = text.replace("\r\n", "\n").replace("\r", "\n")
        compact = re.sub(r"[ \t]+", " ", compact)
        compact = re.sub(r"\n{3,}", "\n\n", compact)
        return compact.strip()

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()

    def _token_overlap(self, left: str, right: str) -> float:
        left_tokens = {item for item in left.split() if len(item) > 3}
        right_tokens = {item for item in right.split() if len(item) > 3}
        if not left_tokens or not right_tokens:
            return 0.0
        return len(left_tokens & right_tokens) / min(len(left_tokens), len(right_tokens))
