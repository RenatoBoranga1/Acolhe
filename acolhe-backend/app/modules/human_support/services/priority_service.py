from __future__ import annotations

from app.models import SupportRequest, SupporterProfile


class SupportPriorityService:
    def priority_bucket(self, risk_level: str) -> str:
        return (
            "critico"
            if risk_level == "critical"
            else "alto"
            if risk_level == "high"
            else "moderado"
            if risk_level == "moderate"
            else "baixo"
        )

    def request_score(
        self,
        request: SupportRequest,
        *,
        waiting_minutes: int,
        has_support_network: bool | None,
        immediate_fear: bool | None,
    ) -> float:
        base = float(request.priority_score or 0)
        time_bonus = min(waiting_minutes / 180.0, 0.18)
        isolation_bonus = 0.06 if has_support_network is False else 0
        fear_bonus = 0.08 if immediate_fear else 0
        risk_bonus = {
            "critical": 0.16,
            "high": 0.10,
            "moderate": 0.04,
        }.get(request.risk_level, 0)
        return round(min(base + time_bonus + isolation_bonus + fear_bonus + risk_bonus, 1.0), 2)

    def distribution_score(
        self,
        request: SupportRequest,
        *,
        supporter_profile: SupporterProfile,
        waiting_minutes: int,
        active_sessions: int,
    ) -> tuple[float, list[str]]:
        summary_payload = dict(request.summary_payload or {})
        requested_specialty = summary_payload.get("requested_specialty")
        support_network = summary_payload.get("support_network_status")
        immediate_fear = summary_payload.get("immediate_fear") is True
        score = self.request_score(
            request,
            waiting_minutes=waiting_minutes,
            has_support_network=False if support_network == "isolated" else None,
            immediate_fear=immediate_fear,
        )
        reasons: list[str] = []

        if requested_specialty and requested_specialty in (supporter_profile.specialties or []):
            score += 0.12
            reasons.append("Especialidade sugerida compativel.")
        elif requested_specialty:
            reasons.append("Pedido pede especialidade especifica.")

        if request.situation_type == "workplace_harassment" and any(
            "trabalho" in item.lower() for item in (supporter_profile.specialties or [])
        ):
            score += 0.06
            reasons.append("Experiencia aderente ao contexto de trabalho.")

        if request.risk_level in {"high", "critical"}:
            reasons.append("Risco elevado exige resposta rapida.")

        if waiting_minutes >= 20:
            reasons.append("Tempo de espera ja relevante.")

        load_penalty = min(active_sessions * 0.08, 0.24)
        if active_sessions > 0:
            reasons.append("Carga atual do apoiador considerada na distribuicao.")

        final_score = round(max(min(score - load_penalty, 1.0), 0.0), 2)
        return final_score, reasons
