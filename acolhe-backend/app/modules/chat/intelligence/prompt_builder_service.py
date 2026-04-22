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
            "Estrategia harassment_uncertainty: acolha a duvida sem fechar conclusao juridica. "
            "Faca uma leitura cuidadosa de sinais como comentarios indesejados, repeticao, insistencia, "
            "hierarquia, desconforto e impacto. Evite a frase generica 'posso ajudar a analisar'; "
            "traga um criterio concreto e uma pergunta leve sobre padrao, contexto ou limite ultrapassado."
        ),
        "initial_disclosure": (
            "Estrategia: permita relato no ritmo da pessoa, nao peca detalhes desnecessarios, "
            "e ofereca organizacao leve."
        ),
        "fear_of_reencounter": (
            "Estrategia fear_of_reencounter: trate como planejamento das proximas horas. "
            "Pergunte de forma curta se a pessoa esta segura agora, mencione reduzir exposicao, "
            "evitar ficar sozinha se possivel, combinar apoio humano e escolher local seguro. "
            "Nao alongue explicacoes nem volte para analise conceitual antes de checar seguranca."
        ),
        "workplace_harassment": (
            "Estrategia workplace_harassment: reconheca a assimetria de poder, convivencia obrigatoria, "
            "medo de retalhacao e impacto profissional. Sugira registro factual de datas, falas, "
            "testemunhas, mensagens e recorrencia. Fale em opcoes de apoio institucional ou humano "
            "sem inventar politicas, leis, prazos ou canais especificos."
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
            "Estrategia reporting_ambivalence: valide que ambivalencia e comum e nao significa fraqueza. "
            "Nao use imperativos como 'denuncie'. Organize caminhos possiveis: registrar fatos, "
            "conversar com pessoa de confianca, buscar orientacao qualificada, avaliar seguranca e decidir depois. "
            "Ajude a comparar riscos, preparo e apoio sem empurrar decisao."
        ),
        "incident_record": (
            "Estrategia incident_record: seja estruturada e neutra. Oriente uma linha do tempo com data aproximada, "
            "hora, local, pessoas envolvidas, testemunhas, mensagens, prints/documentos, consequencias e observacoes. "
            "Rotule qualquer organizacao como rascunho pessoal, nao documento oficial."
        ),
        "support_request": (
            "Estrategia: ajude a escolher pessoa de confianca e montar mensagem simples sem expor tudo."
        ),
        "emotional_crisis": (
            "Estrategia emotional_crisis: reduza complexidade. Use frases curtas, uma orientacao por vez, "
            "foco em aterramento, respiracao simples, pausa, agua, sentar-se e chamar apoio humano se possivel. "
            "Nao faca analise longa, nao peca relato detalhado e nao sobrecarregue com muitas opcoes."
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
        specificity_prompt = self._specificity_prompt(
            memory=memory,
            risk=risk,
            situation=situation,
            response_mode=response_mode,
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
                specificity_prompt,
                mode_prompt,
                anti_repetition_prompt,
                (
                    "Responda em ate 4 frases curtas, ou ate 2 frases se o risco for alto/critico. "
                    "Use pelo menos um detalhe contextual disponivel e termine com no maximo uma pergunta leve."
                ),
            ]
        )
        return PromptBundle(
            system_prompts=[
                context_prompt,
                risk_prompt,
                situation_prompt,
                specificity_prompt,
                mode_prompt,
                anti_repetition_prompt,
            ],
            response_guidance=response_guidance,
        )

    def _specificity_prompt(
        self,
        *,
        memory: ConversationMemory,
        risk: RiskAssessmentResult,
        situation: SituationClassification,
        response_mode: ResponseMode,
    ) -> str:
        facts = "; ".join(memory.known_facts[-4:]) if memory.known_facts else "nenhum fato estruturado ainda"
        shared_context = (
            "Instrucoes de especificidade: evite resposta intercambiavel. "
            f"Fatos conhecidos: {facts}. "
            f"Estado emocional: {memory.user_emotional_state}; relacao com agressor: {memory.aggressor_relation}; "
            f"recorrencia: {memory.repeated_behavior}; evidencias: {memory.evidence_status}; "
            f"rede de apoio: {memory.support_network_status}; quer denunciar: {memory.wants_to_report}. "
            "Se um campo estiver desconhecido, nao invente; formule como possibilidade ou pergunte de modo leve."
        )
        situation_requirements = {
            "harassment_uncertainty": (
                "Inclua uma lente concreta: comportamento indesejado, repeticao, contexto, poder ou impacto. "
                "Nao diga que foi ou nao foi assedio com certeza."
            ),
            "fear_of_reencounter": (
                "Inclua uma acao pratica para hoje: local seguro, companhia, evitar encontro a sos ou combinar check-in. "
                "A primeira prioridade e seguranca atual."
            ),
            "workplace_harassment": (
                "Inclua a dimensao de trabalho/hierarquia/rotina e sugira registro factual sem citar leis ou RH como obrigacao."
            ),
            "incident_record": (
                "Inclua pelo menos tres campos de registro: data/hora, local, pessoas, mensagens/prints, testemunhas ou impactos."
            ),
            "reporting_ambivalence": (
                "Inclua opcoes sem imposicao e normalize a indecisao. Diferencie preparar-se de decidir denunciar."
            ),
            "emotional_crisis": (
                "Use linguagem de estabilizacao imediata, frases simples e pouca informacao. Priorize apoio humano se houver risco."
            ),
        }.get(
            situation.type,
            "Conecte a resposta ao objetivo atual da conversa e ofereca um proximo passo pequeno.",
        )
        risk_requirement = (
            "Como o risco e alto/critico, nao faca analise longa: cheque seguranca e indique ajuda humana imediata."
            if risk.level in {"high", "critical"} or response_mode.name == "safety_first"
            else "Como o risco nao e alto, mantenha acolhimento e orientacao sem alarmismo."
        )
        return f"{shared_context} {situation_requirements} {risk_requirement}"
