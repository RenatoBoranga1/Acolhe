from __future__ import annotations

import re
import unicodedata
from typing import Sequence

from app.modules.chat.intelligence.models import (
    ConversationMemory,
    RiskAssessmentResult,
    SituationClassification,
)


class RiskAssessmentService:
    CRITICAL = {
        "risco suicida ou autoagressao": (
            "quero morrer",
            "vou me matar",
            "tirar minha vida",
            "me machucar",
            "nao quero viver",
        ),
        "perigo imediato": (
            "esta aqui",
            "na minha porta",
            "estou presa",
            "agora comigo",
            "ameaca de morte",
        ),
    }
    HIGH = {
        "medo imediato": ("estou com medo", "medo de encontrar", "vai me encontrar hoje", "hoje"),
        "ameaca atual": ("ameac", "disse que vai", "me intimidou"),
        "perseguicao": ("me seguindo", "perseguindo", "esperando na saida", "stalking"),
        "coercao ou chantagem": ("chantagem", "coag", "me obrigou", "me forcou"),
        "violencia fisica": ("me bateu", "me empurrou", "agressao", "violencia fisica"),
        "isolamento": ("estou sozinha", "nao tenho ninguem", "nao consigo pedir ajuda"),
    }
    MODERATE = {
        "duvida sobre assedio": ("foi assedio", "passou do limite", "estou exagerando"),
        "recorrencia": ("toda semana", "sempre", "varias vezes", "recorrente"),
        "impacto emocional": ("vergonha", "culpa", "ansiosa", "nao consigo dormir", "abalada"),
        "evidencias ou registro": ("print", "mensagem", "prova", "evidencia", "registrar"),
    }

    def assess(
        self,
        *,
        message: str,
        history: Sequence[dict[str, str]],
        memory: ConversationMemory,
        situation: SituationClassification,
        model_signals: Sequence[str] | None = None,
    ) -> RiskAssessmentResult:
        normalized = self._normalize(message)
        context = self._normalize(" ".join(item.get("content", "") for item in history[-6:]))
        triggers: list[str] = []
        score = 0.05

        for label, patterns in self.CRITICAL.items():
            if any(pattern in normalized for pattern in patterns):
                triggers.append(label)
                return RiskAssessmentResult(
                    level="critical",
                    score=0.97,
                    triggers=triggers,
                    rationale="Mensagem contem sinal de perigo imediato, suicidio ou autoagressao.",
                    recommended_mode="safety_first",
                    recommended_actions=[
                        "Buscar um local seguro imediatamente",
                        "Acionar emergencia local ou pessoa de confianca agora",
                        "Abrir plano de seguranca",
                    ],
                    requires_immediate_action=True,
                )

        for label, patterns in self.HIGH.items():
            if any(pattern in normalized for pattern in patterns):
                triggers.append(label)
                score += 0.28
            elif any(pattern in context for pattern in patterns):
                triggers.append(f"contexto: {label}")
                score += 0.12

        for label, patterns in self.MODERATE.items():
            if any(pattern in normalized for pattern in patterns):
                triggers.append(label)
                score += 0.12
            elif any(pattern in context for pattern in patterns):
                triggers.append(f"contexto: {label}")
                score += 0.05

        if situation.type in {"immediate_risk", "fear_of_reencounter", "stalking"}:
            score += 0.25
            triggers.append(f"tipo de situacao: {situation.type}")
        if situation.type in {"coercion_manipulation", "partner_harassment"}:
            score += 0.15
            triggers.append(f"tipo de situacao: {situation.type}")
        if memory.immediate_fear:
            score += 0.15
            triggers.append("memoria: medo imediato")
        if memory.support_network_status == "isolated":
            score += 0.12
            triggers.append("memoria: isolamento")
        if model_signals:
            triggers.extend([f"modelo: {item}" for item in model_signals[:3]])
            score += min(0.12, 0.04 * len(model_signals))

        score = min(score, 0.96)
        if score >= 0.82:
            level = "high"
            mode = "safety_first"
            actions = [
                "Ir para um local seguro",
                "Contatar pessoa de confianca",
                "Evitar ficar sozinha se isso aumentar o risco",
                "Usar o plano de seguranca",
            ]
        elif score >= 0.38:
            level = "moderate"
            mode = "structured_guidance"
            actions = [
                "Organizar fatos importantes",
                "Pensar em proximos passos com seguranca",
                "Considerar apoio humano de confianca",
            ]
        else:
            level = "low"
            mode = "calm_support"
            actions = [
                "Conversar no seu ritmo",
                "Registrar fatos se isso for util",
                "Buscar apoio humano se desejar",
            ]

        return RiskAssessmentResult(
            level=level,
            score=round(score, 2),
            triggers=triggers or ["sem sinais imediatos de crise"],
            rationale=self._build_rationale(level, triggers),
            recommended_mode=mode,
            recommended_actions=actions,
            requires_immediate_action=level in {"high", "critical"},
        )

    def _build_rationale(self, level: str, triggers: Sequence[str]) -> str:
        if level in {"high", "critical"}:
            return "Foram detectados sinais que podem indicar risco atual ou necessidade de protecao imediata."
        if level == "moderate":
            return "Ha sinais de impacto, recorrencia, duvida ou necessidade de organizacao cuidadosa."
        return "Nao apareceram sinais imediatos de crise na mensagem atual."

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()
