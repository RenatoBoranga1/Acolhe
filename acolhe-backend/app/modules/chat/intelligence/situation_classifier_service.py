from __future__ import annotations

import re
import unicodedata
from typing import Sequence

from app.modules.chat.intelligence.models import ConversationMemory, SituationClassification


class SituationClassifierService:
    PATTERNS = {
        "immediate_risk": (
            "vai me encontrar hoje",
            "esta aqui",
            "esta na minha porta",
            "estou presa",
            "ameaca de morte",
            "me matar",
            "quero morrer",
        ),
        "fear_of_reencounter": (
            "medo de encontrar",
            "encontrar essa pessoa",
            "ver essa pessoa hoje",
            "ele disse que vai me encontrar",
            "ela disse que vai me encontrar",
        ),
        "stalking": ("me seguindo", "me persegue", "perseguindo", "esperando na saida", "stalking"),
        "coercion_manipulation": ("chantagem", "coag", "me obrigou", "me forcou", "manipul"),
        "reporting_ambivalence": ("denunciar", "nao consigo decidir", "tenho medo de denunciar", "boletim"),
        "incident_record": ("registr", "resumo", "organizar", "linha do tempo", "guardar prova", "evidenc"),
        "support_request": ("falar com alguem", "pessoa de confianca", "pedir apoio", "contar para", "mensagem"),
        "workplace_harassment": ("chefe", "supervisor", "colega de trabalho", "empresa", "trabalho"),
        "academic_harassment": ("professor", "faculdade", "escola", "orientador", "curso"),
        "partner_harassment": ("namorado", "marido", "parceiro", "companheiro", "ex"),
        "emotional_crisis": ("panico", "desesperada", "nao aguento", "sem controle", "crise"),
        "harassment_uncertainty": (
            "nao sei se foi assedio",
            "foi assedio",
            "passou do limite",
            "estou exagerando",
            "exagerando",
            "comentarios sobre meu corpo",
            "toda semana",
        ),
        "initial_disclosure": ("aconteceu", "ele fez", "ela fez", "me tocou", "comentario", "comentarios"),
    }
    PRIORITY = (
        "immediate_risk",
        "fear_of_reencounter",
        "stalking",
        "coercion_manipulation",
        "emotional_crisis",
        "reporting_ambivalence",
        "incident_record",
        "support_request",
        "workplace_harassment",
        "academic_harassment",
        "partner_harassment",
        "harassment_uncertainty",
        "initial_disclosure",
    )

    def classify(
        self,
        *,
        message: str,
        history: Sequence[dict[str, str]],
        memory: ConversationMemory,
    ) -> SituationClassification:
        normalized = self._normalize(message)
        recent_context = self._normalize(" ".join(item.get("content", "") for item in history[-6:]))
        scores: dict[str, int] = {}
        signals: dict[str, list[str]] = {}

        for situation_type, patterns in self.PATTERNS.items():
            for pattern in patterns:
                if pattern in normalized:
                    scores[situation_type] = scores.get(situation_type, 0) + 3
                    signals.setdefault(situation_type, []).append(pattern)
                elif pattern in recent_context:
                    context_weight = 2 if situation_type in {"immediate_risk", "fear_of_reencounter", "stalking"} else 1
                    scores[situation_type] = scores.get(situation_type, 0) + context_weight
                    signals.setdefault(situation_type, []).append(f"contexto: {pattern}")

        if memory.immediate_fear:
            scores["fear_of_reencounter"] = scores.get("fear_of_reencounter", 0) + 2
            signals.setdefault("fear_of_reencounter", []).append("memoria: medo imediato")
        if memory.aggressor_relation == "boss":
            scores["workplace_harassment"] = scores.get("workplace_harassment", 0) + 2
        if memory.aggressor_relation == "teacher":
            scores["academic_harassment"] = scores.get("academic_harassment", 0) + 2
        if memory.wants_to_report in {"yes", "unsure"}:
            scores["reporting_ambivalence"] = scores.get("reporting_ambivalence", 0) + 1

        if not scores:
            return SituationClassification(
                type=memory.current_situation_type or "initial_disclosure",
                confidence=0.35,
                signals=["sem sinal forte; usando continuidade da conversa"],
            )

        selected = sorted(
            scores,
            key=lambda item: (-scores[item], self.PRIORITY.index(item) if item in self.PRIORITY else 999),
        )[0]
        confidence = min(0.95, 0.35 + (scores[selected] * 0.12))
        return SituationClassification(
            type=selected,
            confidence=round(confidence, 2),
            signals=signals.get(selected, [])[:6],
        )

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()
