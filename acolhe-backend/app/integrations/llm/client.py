from __future__ import annotations

import logging
from pathlib import Path

import httpx

from app.core.config import get_settings


logger = logging.getLogger(__name__)


class LLMClient:
    def __init__(self) -> None:
        self.settings = get_settings()

    def load_system_prompt(self) -> str:
        prompt_path = Path(__file__).resolve().parents[2] / "prompts" / "acolhe_system_prompt.md"
        return prompt_path.read_text(encoding="utf-8")

    def is_enabled(self) -> bool:
        return bool(self.settings.llm_enabled and self.settings.llm_api_key)

    def chat(
        self,
        *,
        message: str,
        history: list[dict[str, str]],
        risk_level: str,
        response_guidance: str,
        system_prompts: list[str] | None = None,
    ) -> str | None:
        if not self.is_enabled():
            return None

        instructions = (
            "Mantenha a resposta curta, segura, acolhedora e contextual. "
            f"O nivel de risco calculado foi: {risk_level}. "
            "Quando for apropriado, inclua uma interpretacao cuidadosa do que a pessoa trouxe, "
            "sem afirmar certeza absoluta. "
            "Se for alto ou critico, priorize seguranca imediata e reduza a resposta. "
            "Evite respostas formulaicas; use detalhes do contexto fornecido e varie a estrutura."
        )
        temperature = self._temperature_for_risk(risk_level)
        payload = {
            "model": self.settings.llm_model,
            "messages": [
                {"role": "system", "content": self.load_system_prompt()},
                {"role": "system", "content": instructions},
                *[
                    {"role": "system", "content": prompt}
                    for prompt in (system_prompts or [])
                    if prompt.strip()
                ],
                {"role": "system", "content": response_guidance},
                *history,
                {"role": "user", "content": message},
            ],
            "temperature": temperature,
            "top_p": 0.92,
            "presence_penalty": 0.2,
            "frequency_penalty": 0.35,
            "max_tokens": 220 if risk_level in {"high", "critical"} else 360,
        }

        try:
            with httpx.Client(timeout=self.settings.llm_timeout_seconds) as client:
                response = client.post(
                    f"{self.settings.llm_base_url.rstrip('/')}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.settings.llm_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
            return data["choices"][0]["message"]["content"].strip()
        except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError):
            logger.warning("LLM unavailable for chat response, using deterministic fallback.")
            return None

    def _temperature_for_risk(self, risk_level: str) -> float:
        if risk_level in {"high", "critical"}:
            return 0.28
        if risk_level == "moderate":
            return 0.52
        return 0.58
