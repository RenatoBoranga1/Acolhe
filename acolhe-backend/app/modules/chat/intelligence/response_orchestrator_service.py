from __future__ import annotations

from typing import Sequence

from app.integrations.llm.client import LLMClient
from app.models import Message
from app.modules.chat.intelligence.conversation_memory_service import ConversationMemoryService
from app.modules.chat.intelligence.models import ChatOrchestrationResult
from app.modules.chat.intelligence.prompt_builder_service import PromptBuilderService
from app.modules.chat.intelligence.response_validator_service import ResponseValidatorService
from app.modules.chat.intelligence.risk_assessment_service import RiskAssessmentService
from app.modules.chat.intelligence.situation_classifier_service import SituationClassifierService
from app.modules.chat.intelligence.tone_selector_service import ToneSelectorService
from app.modules.chat.response_engine import ChatResponseEngine


class ResponseOrchestratorService:
    def __init__(self) -> None:
        self.memory_service = ConversationMemoryService()
        self.situation_classifier = SituationClassifierService()
        self.risk_assessment = RiskAssessmentService()
        self.tone_selector = ToneSelectorService()
        self.prompt_builder = PromptBuilderService()
        self.validator = ResponseValidatorService()
        self.fallback_engine = ChatResponseEngine()
        self.llm_client = LLMClient()

    def respond(
        self,
        *,
        conversation_id: str,
        latest_message: str,
        stored_messages: Sequence[Message],
        client_history: Sequence[dict[str, str]] | None,
    ) -> ChatOrchestrationResult:
        stored_history = [
            {"role": item.role, "content": item.content}
            for item in stored_messages
        ]
        history = self.fallback_engine.select_history(
            stored_history=stored_history,
            client_history=client_history or [],
            latest_message=latest_message,
        )
        previous_memory = self.memory_service.load(
            conversation_id=conversation_id,
            messages=stored_messages,
        )
        situation = self.situation_classifier.classify(
            message=latest_message,
            history=history,
            memory=previous_memory,
        )
        risk = self.risk_assessment.assess(
            message=latest_message,
            history=history,
            memory=previous_memory,
            situation=situation,
        )
        preliminary_mode = self.tone_selector.select(
            risk=risk,
            situation=situation,
            memory=previous_memory,
            history=history,
        )
        memory = self.memory_service.update(
            memory=previous_memory,
            latest_message=latest_message,
            history=history,
            risk=risk,
            situation=situation,
            response_mode=preliminary_mode.name,
        )
        response_mode = self.tone_selector.select(
            risk=risk,
            situation=situation,
            memory=memory,
            history=history,
        )
        memory.response_mode = response_mode.name
        recent_assistant_messages = [
            item["content"] for item in history if item.get("role") == "assistant"
        ][-3:]
        recent_openings = [self._first_sentence(item) for item in recent_assistant_messages]
        prompt_bundle = self.prompt_builder.build(
            memory=memory,
            risk=risk,
            situation=situation,
            response_mode=response_mode,
            recent_assistant_openings=recent_openings,
        )
        api_risk = risk.to_response()
        fallback_context = self.fallback_engine.build_context(
            history,
            latest_message=latest_message,
            risk=api_risk,
        )
        fallback = self.fallback_engine.compose_response(
            latest_message=latest_message,
            history=history,
            risk=api_risk,
            context=fallback_context,
        )
        candidate = self.llm_client.chat(
            message=latest_message,
            history=history[:-1],
            risk_level=risk.level,
            response_guidance=prompt_bundle.response_guidance,
            system_prompts=prompt_bundle.system_prompts,
        )
        if candidate:
            candidate = self.fallback_engine.finalize_response(
                candidate,
                latest_message=latest_message,
                history=history,
                risk=api_risk,
                context=fallback_context,
            )
        validation = self.validator.validate(
            candidate=candidate or fallback,
            fallback=fallback,
            risk=risk,
            situation=situation,
            response_mode=response_mode,
            memory=memory,
            recent_assistant_messages=recent_assistant_messages,
        )
        ctas = self._ctas_for(risk=risk, situation_type=situation.type, response_mode=response_mode.name)
        return ChatOrchestrationResult(
            assistant_text=validation.text,
            risk=risk,
            situation=situation,
            memory=memory,
            response_mode=response_mode,
            validation=validation,
            ctas=ctas,
        )

    def _ctas_for(self, *, risk, situation_type: str, response_mode: str) -> list[str]:
        if risk.level in {"high", "critical"} or response_mode == "safety_first":
            return [
                "Ligar para emergencia",
                "Contatar pessoa de confianca",
                "Abrir plano de seguranca",
                "Ver servicos de apoio",
            ]
        if situation_type == "incident_record":
            return ["Gerar resumo cronologico", "Adicionar evidencia", "Salvar registro privado"]
        if situation_type == "support_request":
            return ["Escrever mensagem pronta", "Abrir rede de apoio", "Escolher contato"]
        if situation_type == "reporting_ambivalence":
            return ["Organizar opcoes", "Registrar fatos", "Falar com pessoa de confianca"]
        return [
            "Registrar o que aconteceu",
            "Montar plano de seguranca",
            "Falar com pessoa de confianca",
        ]

    def _first_sentence(self, text: str) -> str:
        stripped = text.strip()
        for separator in (".", "!", "?"):
            if separator in stripped:
                return stripped.split(separator, 1)[0] + separator
        return stripped
