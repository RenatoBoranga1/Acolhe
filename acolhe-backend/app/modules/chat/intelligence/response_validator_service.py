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
        if self._is_too_generic(normalized, situation, memory):
            issues.append("too_generic")

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

    def _is_too_generic(
        self,
        normalized: str,
        situation: SituationClassification,
        memory: ConversationMemory,
    ) -> bool:
        generic_markers = (
            "sinto muito que voce esteja passando por isso",
            "estou aqui para ajudar",
            "sem julgamentos",
        )
        if not any(marker in normalized for marker in generic_markers):
            return False
        expected_terms = {
            "fear_of_reencounter": ("seguranca", "encontrar", "hoje", "apoio"),
            "incident_record": ("registro", "data", "local", "fatos", "resumo"),
            "reporting_ambivalence": ("opcoes", "decidir", "denunciar", "pressao"),
            "harassment_uncertainty": ("duvida", "fatos", "padrao", "contexto"),
            "workplace_harassment": ("trabalho", "ambiente", "registro", "rotina"),
            "emotional_crisis": ("respirar", "pausa", "agora", "apoio"),
        }.get(situation.type, ("fatos", "seguranca", "apoio", memory.user_emotional_state))
        return not any(term in normalized for term in expected_terms)

    def _limit_sentences(self, text: str, *, max_sentences: int) -> str:
        sentences = [item.strip() for item in re.split(r"(?<=[.!?])\s+", text) if item.strip()]
        if len(sentences) <= max_sentences:
            return text
        return " ".join(sentences[:max_sentences])

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
