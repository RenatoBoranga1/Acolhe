from __future__ import annotations

import re
import unicodedata

from app.modules.risk.schemas import RiskAssessmentResponse


class RiskService:
    CRITICAL_PATTERNS = {
        "risco suicida": [
            "quero morrer",
            "vou me matar",
            "nao quero viver",
            "tirar minha vida",
            "me matar",
        ],
        "ameaca imediata": [
            "ele esta aqui",
            "ela esta aqui",
            "agora comigo",
            "na minha porta",
            "estou presa",
            "ameaca de morte",
        ],
    }
    HIGH_SIGNALS = {
        "medo imediato": ["estou com medo", "tenho medo", "medo de encontrar", "to com medo"],
        "perseguicao": ["me seguindo", "me persegue", "perseguindo", "esperando na saida"],
        "chantagem ou coacao": ["chantagem", "coagindo", "me coagiu", "me obrigou", "me forcou"],
        "violencia fisica": ["me bateu", "agressao", "violencia fisica", "me empurrou"],
        "presenca do agressor": ["ele esta perto", "ela esta perto", "agressor aqui"],
    }
    MODERATE_SIGNALS = {
        "duvida sobre assedio": ["foi assedio", "passou do limite", "nao sei se foi"],
        "impacto emocional": ["estou abalada", "nao consigo dormir", "ansiosa", "culpa", "vergonha"],
        "registro": ["registrar", "organizar os fatos", "guardar provas"],
    }

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()

    def assess(self, message: str) -> RiskAssessmentResponse:
        normalized = self._normalize(message)
        reasons: list[str] = []
        actions: list[str] = []
        score = 0

        for label, patterns in self.CRITICAL_PATTERNS.items():
            if any(pattern in normalized for pattern in patterns):
                reasons.append(label)
                actions = [
                    "Buscar um local seguro imediatamente",
                    "Acionar emergencia local ou servico equivalente",
                    "Contatar uma pessoa de confianca agora",
                    "Abrir plano de seguranca",
                ]
                return RiskAssessmentResponse(
                    level="critical",
                    score=10,
                    reasons=reasons,
                    recommended_actions=actions,
                    requires_immediate_action=True,
                )

        for label, patterns in self.HIGH_SIGNALS.items():
            if any(pattern in normalized for pattern in patterns):
                reasons.append(label)
                score += 3

        for label, patterns in self.MODERATE_SIGNALS.items():
            if any(pattern in normalized for pattern in patterns):
                reasons.append(label)
                score += 1

        if score >= 6:
            level = "high"
            actions = [
                "Ir para um local seguro",
                "Contatar pessoa de confianca",
                "Evitar permanecer sozinha se isso aumentar o risco",
                "Usar o plano de seguranca",
            ]
        elif score >= 2:
            level = "moderate"
            actions = [
                "Organizar fatos importantes",
                "Pensar em proximos passos com seguranca",
                "Considerar apoio humano de confianca",
            ]
        else:
            level = "low"
            actions = [
                "Conversar no seu ritmo",
                "Registrar fatos se isso for util",
                "Buscar apoio humano se desejar",
            ]

        return RiskAssessmentResponse(
            level=level,
            score=score,
            reasons=reasons or ["sem sinais imediatos de crise"],
            recommended_actions=actions,
            requires_immediate_action=level in {"high", "critical"},
        )
