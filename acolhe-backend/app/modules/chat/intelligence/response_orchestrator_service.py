from __future__ import annotations

import hashlib
import logging
from typing import Sequence

from app.integrations.llm.client import LLMClient
from app.models import Message
from app.modules.chat.intelligence.conversation_memory_service import ConversationMemoryService
from app.modules.chat.intelligence.models import ChatOrchestrationResult, OrchestrationMetrics
from app.modules.chat.intelligence.prompt_builder_service import PromptBuilderService
from app.modules.chat.intelligence.response_validator_service import ResponseValidatorService
from app.modules.chat.intelligence.risk_assessment_service import RiskAssessmentService
from app.modules.chat.intelligence.situation_classifier_service import SituationClassifierService
from app.modules.chat.intelligence.tone_selector_service import ToneSelectorService
from app.modules.chat.response_engine import ChatResponseEngine


logger = logging.getLogger(__name__)


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
        fallback = self._situation_fallback(
            latest_message=latest_message,
            history=history,
            risk=api_risk,
            situation_type=situation.type,
            response_mode=response_mode.name,
            fallback_context=fallback_context,
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
        fallback_used = candidate is None
        validation = self.validator.validate(
            candidate=candidate or fallback,
            fallback=fallback,
            risk=risk,
            situation=situation,
            response_mode=response_mode,
            memory=memory,
            recent_assistant_messages=recent_assistant_messages,
        )
        fallback_used = fallback_used or validation.repaired
        ctas = self._ctas_for(risk=risk, situation_type=situation.type, response_mode=response_mode.name)
        metrics = OrchestrationMetrics(
            fallback_used=fallback_used,
            risk_level=risk.level,
            situation_type=situation.type,
            response_mode=response_mode.name,
            repaired=validation.repaired,
            validation_issues=validation.issues,
        )
        logger.info(
            "chat_orchestration_metrics fallback_used=%s risk_level=%s situation_type=%s "
            "response_mode=%s repaired=%s validation_issues=%s",
            metrics.fallback_used,
            metrics.risk_level,
            metrics.situation_type,
            metrics.response_mode,
            metrics.repaired,
            ",".join(metrics.validation_issues),
        )
        return ChatOrchestrationResult(
            assistant_text=validation.text,
            risk=risk,
            situation=situation,
            memory=memory,
            response_mode=response_mode,
            validation=validation,
            ctas=ctas,
            metrics=metrics,
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

    def _situation_fallback(
        self,
        *,
        latest_message: str,
        history: Sequence[dict[str, str]],
        risk,
        situation_type: str,
        response_mode: str,
        fallback_context,
    ) -> str:
        if risk.level in {"high", "critical"} or response_mode == "safety_first":
            if situation_type in {"fear_of_reencounter", "immediate_risk"}:
                return self._pick_situation_phrase(
                    [
                        (
                            "Sua seguranca vem primeiro agora. Se existe chance de encontrar essa pessoa hoje, "
                            "tente ir para um local seguro, evitar ficar sozinha e avisar uma pessoa de confianca ou emergencia local.\n\n"
                            "Voce esta em um lugar seguro neste momento?"
                        ),
                        (
                            "Quero focar nas proximas horas. Se essa pessoa pode se aproximar hoje, "
                            "procure um local seguro e acione alguem de confianca para nao lidar com isso sozinha.\n\n"
                            "Existe alguem que possa ficar perto de voce agora?"
                        ),
                        (
                            "Antes de analisar qualquer detalhe, vale reduzir sua exposicao. "
                            "Se houver risco de encontro hoje, tente ir para um local seguro e chamar ajuda humana imediatamente.\n\n"
                            "O risco e agora ou em um horario especifico?"
                        ),
                    ],
                    seed=f"{latest_message}|{len(history)}|{risk.level}|safety",
                    recent_messages=fallback_context.recent_assistant_messages,
                )
            return self.fallback_engine.compose_response(
                latest_message=latest_message,
                history=history,
                risk=risk,
                context=fallback_context,
            )

        situation_templates = {
            "harassment_uncertainty": [
                (
                    "Faz sentido querer olhar para isso com cuidado. Para entender se algo pode ter passado do limite, "
                    "vale observar o que foi dito ou feito, se houve repeticao, pressao, hierarquia e como isso te afetou.\n\n"
                    "O que mais te deixou em duvida: o comentario, a insistencia ou o contexto?"
                ),
                (
                    "A duvida nao invalida o desconforto. Comentarios repetidos, especialmente sobre corpo ou intimidade, "
                    "podem ser analisados pelo padrao, pelo contexto e pela liberdade que voce tinha para recusar ou se afastar.\n\n"
                    "Isso aconteceu uma vez ou vem se repetindo?"
                ),
                (
                    "Da para separar isso sem pressa: quais foram os fatos, se havia insistencia ou poder envolvido, "
                    "e qual impacto ficou em voce. Eu nao vou afirmar um enquadramento fechado, mas posso te ajudar a organizar esses sinais.\n\n"
                    "Qual parte parece mais importante agora?"
                ),
            ],
            "workplace_harassment": [
                (
                    "Quando isso envolve trabalho ou chefia, o peso pode ser maior por causa da hierarquia e da convivencia. "
                    "Pode ajudar registrar datas, falas, mensagens, testemunhas e se isso vem se repetindo, sem decidir nada sob pressao.\n\n"
                    "Voce precisa encontrar essa pessoa no ambiente de trabalho em breve?"
                ),
                (
                    "Em ambiente de trabalho, a rotina e a hierarquia podem deixar tudo mais delicado. "
                    "Um registro factual com data, local, quem estava presente e mensagens pode te dar mais clareza para escolher proximos passos.\n\n"
                    "O que te preocupa mais agora: exposicao, retalhacao ou ter que conviver com essa pessoa?"
                ),
            ],
            "incident_record": [
                (
                    "Organizar isso como rascunho pessoal pode trazer clareza sem transformar em documento oficial. "
                    "Voce pode comecar por data ou periodo aproximado, local, pessoas envolvidas, mensagens/prints, testemunhas e impactos percebidos.\n\n"
                    "Qual desses pontos seria mais facil registrar primeiro?"
                ),
                (
                    "Podemos montar uma linha do tempo neutra, apenas para voce. "
                    "Um bom comeco e anotar quando aconteceu, onde foi, quem estava envolvido, quais evidencias existem e quais consequencias voce percebeu.\n\n"
                    "Voce prefere comecar pela data, pelo local ou pela descricao do que aconteceu?"
                ),
                (
                    "Registrar nao te obriga a tomar nenhuma decisao agora. "
                    "A ideia e preservar fatos: data/hora, local, pessoas, testemunhas, prints ou documentos e observacoes sobre impactos.\n\n"
                    "Quer organizar isso em ordem cronologica?"
                ),
            ],
            "reporting_ambivalence": [
                (
                    "Ficar dividida sobre denunciar pode acontecer, e voce nao precisa decidir sob pressao. "
                    "Um caminho possivel e separar opcoes: registrar fatos, conversar com alguem de confianca, buscar orientacao qualificada e avaliar sua seguranca antes de qualquer decisao.\n\n"
                    "Voce quer pensar primeiro nos riscos, no preparo ou em quem poderia te apoiar?"
                ),
                (
                    "A indecisao pode ser um sinal de que voce esta tentando se proteger, nao de que esta errada. "
                    "Voce pode preparar informacoes, guardar evidencias e conversar com alguem qualificado antes de decidir denunciar ou nao.\n\n"
                    "O que pesa mais nessa decisao hoje?"
                ),
                (
                    "Denunciar nao precisa ser tratado como uma escolha imediata. "
                    "Podemos organizar opcoes com calma: seguranca, registro dos fatos, apoio de confianca e orientacao profissional sem compromisso.\n\n"
                    "Qual dessas opcoes parece menos pesada para comecar?"
                ),
            ],
            "emotional_crisis": [
                (
                    "Vamos simplificar agora. Tente apoiar os pes no chao, respirar devagar e olhar ao redor para nomear uma coisa que voce consegue ver.\n\n"
                    "Tem alguem de confianca que possa ficar com voce ou receber uma mensagem curta agora?"
                ),
                (
                    "Neste momento, nao precisamos resolver tudo. Tente soltar os ombros, respirar uma vez mais devagar e buscar um ponto fixo no ambiente.\n\n"
                    "Voce consegue mandar uma mensagem simples para alguem de confianca?"
                ),
            ],
        }
        options = situation_templates.get(situation_type)
        if options:
            return self._pick_situation_phrase(
                options,
                seed=f"{latest_message}|{len(history)}|{situation_type}",
                recent_messages=fallback_context.recent_assistant_messages,
            )

        return self.fallback_engine.compose_response(
            latest_message=latest_message,
            history=history,
            risk=risk,
            context=fallback_context,
        )

    def _pick_situation_phrase(
        self,
        options: list[str],
        *,
        seed: str,
        recent_messages: Sequence[str],
    ) -> str:
        ordered = sorted(options, key=lambda item: hashlib.md5(f"{seed}|{item}".encode()).hexdigest())
        normalized_recent = [self._normalize(item) for item in recent_messages]
        for item in ordered:
            normalized = self._normalize(item)
            if not any(normalized == recent or self._token_overlap(normalized, recent) >= 0.72 for recent in normalized_recent):
                return item
        return ordered[0]

    def _normalize(self, text: str) -> str:
        return " ".join(text.lower().split())

    def _token_overlap(self, left: str, right: str) -> float:
        left_tokens = {item for item in left.split() if len(item) > 3}
        right_tokens = {item for item in right.split() if len(item) > 3}
        if not left_tokens or not right_tokens:
            return 0.0
        return len(left_tokens & right_tokens) / min(len(left_tokens), len(right_tokens))

    def _first_sentence(self, text: str) -> str:
        stripped = text.strip()
        for separator in (".", "!", "?"):
            if separator in stripped:
                return stripped.split(separator, 1)[0] + separator
        return stripped
