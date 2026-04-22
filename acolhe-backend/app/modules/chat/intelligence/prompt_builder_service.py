from __future__ import annotations

from app.modules.chat.intelligence.conversation_memory_service import ConversationMemoryService
from app.modules.chat.intelligence.models import (
    ConversationMemory,
    PromptBundle,
    ResponseMode,
    RiskAssessmentResult,
    SituationClassification,
)


class PromptBuilderService:
    MODE_INSTRUCTIONS = {
        "calm_support": (
            "Modo calm_support: responda com acolhimento gentil, linguagem leve e seguranca emocional. "
            "Evite excesso de analise; ajude a pessoa a se sentir acompanhada."
        ),
        "structured_guidance": (
            "Modo structured_guidance: responda de forma clara, organizada e analitica sem frieza. "
            "Ajude a separar fatos, padroes e proximos passos."
        ),
        "safety_first": (
            "Modo safety_first: seja direto, curto e focado em protecao imediata. "
            "Nao explore detalhes antes de checar seguranca."
        ),
        "decision_support": (
            "Modo decision_support: valide ambivalencia, ofereca opcoes e nao pressione decisoes. "
            "Ajude a comparar caminhos com cuidado."
        ),
        "grounding_mode": (
            "Modo grounding_mode: use frases muito simples e calmas. "
            "Foque em estabilizacao, respiracao, pausa e apoio humano."
        ),
    }
    SITUATION_STRATEGIES = {
        "harassment_uncertainty": (
            "Estrategia: acolha a duvida, explique que desconforto, repeticao e contexto importam, "
            "e ajude a analisar sem afirmar categoricamente."
        ),
        "initial_disclosure": (
            "Estrategia: permita relato no ritmo da pessoa, nao peca detalhes desnecessarios, "
            "e ofereca organizacao leve."
        ),
        "fear_of_reencounter": (
            "Estrategia: priorize seguranca pratica para as proximas horas, apoio humano e reducao de exposicao."
        ),
        "workplace_harassment": (
            "Estrategia: reconheca o peso de hierarquia/convivio, sugira registro de fatos e medidas praticas de seguranca."
        ),
        "academic_harassment": (
            "Estrategia: reconheca o contexto institucional, sugira registro e apoio seguro sem inventar procedimentos."
        ),
        "partner_harassment": (
            "Estrategia: considere vinculo afetivo, ambivalencia e seguranca; evite julgamentos."
        ),
        "stalking": (
            "Estrategia: trate como risco potencial, foque em seguranca, apoio e preservacao de evidencias."
        ),
        "coercion_manipulation": (
            "Estrategia: nomeie a pressao com cuidado, reforce que decisoes devem ser seguras e no ritmo da pessoa."
        ),
        "reporting_ambivalence": (
            "Estrategia: valide indecisao, nao pressione denuncia, organize opcoes e preparacao."
        ),
        "incident_record": (
            "Estrategia: oriente cronologia, data, local, pessoas, mensagens, prints, testemunhas e impactos."
        ),
        "support_request": (
            "Estrategia: ajude a escolher pessoa de confianca e montar mensagem simples sem expor tudo."
        ),
        "emotional_crisis": (
            "Estrategia: reduza complexidade, use frases curtas e foque em estabilizacao e apoio humano."
        ),
        "immediate_risk": (
            "Estrategia: interrompa fluxo comum, priorize seguranca imediata e ajuda humana real."
        ),
    }

    def __init__(self) -> None:
        self.memory_service = ConversationMemoryService()

    def build(
        self,
        *,
        memory: ConversationMemory,
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        response_mode: ResponseMode,
        recent_assistant_openings: list[str],
    ) -> PromptBundle:
        context_prompt = self.memory_service.to_prompt_context(memory)
        risk_prompt = (
            "Classificacao de risco atual: "
            f"nivel={risk.level}; score={risk.score}; gatilhos={', '.join(risk.triggers)}; "
            f"modo_recomendado={risk.recommended_mode}; racional={risk.rationale}."
        )
        situation_prompt = (
            "Tipo de situacao atual: "
            f"{situation.type}; confianca={situation.confidence}; sinais={', '.join(situation.signals)}. "
            + self.SITUATION_STRATEGIES.get(situation.type, self.SITUATION_STRATEGIES["initial_disclosure"])
        )
        mode_prompt = self.MODE_INSTRUCTIONS.get(response_mode.name, self.MODE_INSTRUCTIONS["calm_support"])
        anti_repetition_prompt = (
            "Evite repetir aberturas, frases e estruturas recentes. "
            f"Aberturas recentes a evitar: {' | '.join(recent_assistant_openings) if recent_assistant_openings else 'nenhuma'}."
        )
        response_guidance = " ".join(
            [
                context_prompt,
                risk_prompt,
                situation_prompt,
                mode_prompt,
                anti_repetition_prompt,
                "Responda em ate 4 frases curtas, ou ate 2 frases se o risco for alto/critico.",
            ]
        )
        return PromptBundle(
            system_prompts=[
                context_prompt,
                risk_prompt,
                situation_prompt,
                mode_prompt,
                anti_repetition_prompt,
            ],
            response_guidance=response_guidance,
        )
