from __future__ import annotations

from dataclasses import dataclass
import hashlib
import re
import unicodedata
from typing import Iterable, Sequence

from app.modules.risk.schemas import RiskAssessmentResponse


@dataclass(frozen=True)
class ConversationContext:
    primary_signal: str
    secondary_signals: tuple[str, ...]
    recent_user_messages: tuple[str, ...]
    recent_assistant_messages: tuple[str, ...]
    recent_openings: tuple[str, ...]
    should_offer_scope_note: bool
    should_ask_question: bool
    is_follow_up: bool


class ChatResponseEngine:
    SIGNAL_PRIORITY = ("safety", "uncertainty", "record", "support", "work", "impact", "general")
    SIGNAL_PATTERNS = {
        "safety": (
            "medo",
            "ameaca",
            "ameaca de morte",
            "risco",
            "seguranca",
            "local seguro",
            "encontrar essa pessoa",
            "encontrar ele",
            "encontrar ela",
            "hoje",
            "agora",
            "me seguindo",
            "persegu",
            "coag",
            "forcou",
            "presa",
            "agressor",
        ),
        "uncertainty": (
            "nao sei se foi",
            "foi assedio",
            "passou do limite",
            "nao sei por onde comecar",
            "duvida",
            "confuso",
        ),
        "record": (
            "registr",
            "resumo",
            "organizar",
            "cronolog",
            "guardar provas",
            "evidenc",
            "anotar",
            "linha do tempo",
        ),
        "support": (
            "apoio",
            "pessoa de confianca",
            "alguem de confianca",
            "contar para",
            "falar com",
            "mensagem",
            "rede de apoio",
        ),
        "work": (
            "chefe",
            "supervisor",
            "trabalho",
            "empresa",
            "colega",
            "professor",
            "faculdade",
            "escola",
            "curso",
        ),
        "impact": (
            "vergonha",
            "culpa",
            "confusa",
            "travada",
            "abalada",
            "ansiosa",
            "nao consigo dormir",
            "chorei",
            "mal",
        ),
    }
    OPENINGS = {
        "safety": (
            "Quero focar primeiro na sua seguranca.",
            "Antes de qualquer outra coisa, o mais importante agora e sua seguranca.",
            "Vamos priorizar o que pode te proteger neste momento.",
            "Faz sentido olhar primeiro para sua seguranca agora.",
        ),
        "uncertainty": (
            "Da para entender por que isso te deixou em duvida.",
            "Faz sentido querer olhar para isso com mais cuidado.",
            "Isso pode mesmo gerar muita duvida e confusao.",
            "Entendo por que voce esta tentando nomear melhor o que aconteceu.",
        ),
        "record": (
            "Colocar isso em ordem pode ajudar a trazer mais clareza.",
            "Organizar os fatos com calma pode te dar um pouco mais de firmeza.",
            "Registrar o que aconteceu pode ser util sem te obrigar a decidir nada agora.",
            "Faz sentido querer deixar isso mais claro para voce mesma.",
        ),
        "support": (
            "Pedir apoio nem sempre e simples, mas isso pode aliviar um pouco o peso.",
            "Buscar uma pessoa de confianca pode ser um passo importante e ainda assim cuidadoso.",
            "Faz sentido pensar em quem pode te apoiar sem te pressionar.",
            "Voce nao precisa carregar isso sozinha se nao quiser.",
        ),
        "work": (
            "Quando isso envolve um ambiente que voce precisa frequentar, o desgaste pode ser maior.",
            "Isso fica ainda mais delicado quando acontece em um lugar que faz parte da sua rotina.",
            "Se isso aconteceu em um contexto de trabalho ou estudo, e compreensivel que mexa com a sua seguranca.",
            "Situacoes assim costumam pesar ainda mais quando envolvem hierarquia ou convivio frequente.",
        ),
        "impact": (
            "Faz sentido isso ter mexido com voce.",
            "Isso parece ter sido bem desconfortavel de carregar.",
            "Nao deve ter sido facil lidar com isso por dentro.",
            "Entendo por que isso pode ter te afetado desse jeito.",
        ),
        "general": (
            "Podemos olhar para isso com calma.",
            "A gente pode ir por partes, no seu ritmo.",
            "Estou aqui para te ajudar a organizar isso sem pressa.",
            "Da para seguir com cuidado, sem te apressar.",
        ),
    }
    CONTEXT_LINES = {
        "safety": (
            "Se o receio e encontrar essa pessoa ou ficar mais exposta hoje, vale pensar primeiro nas proximas horas.",
            "Quando aparece medo de reencontro, faz sentido reduzir exposicao e aumentar apoio pratico.",
            "Se existe chance de contato ou aproximacao agora, o foco pode ser te deixar menos vulneravel.",
        ),
        "uncertainty": (
            "Voce nao precisa fechar um rotulo agora para levar o que viveu a serio.",
            "Da para olhar para os fatos sem se cobrar uma conclusao imediata.",
            "A gente pode separar o que foi dito, feito e como isso te afetou antes de dar nome a tudo.",
        ),
        "record": (
            "Transformar isso em um registro claro pode ajudar sem te empurrar para nenhuma decisao.",
            "Da para organizar data, lugar, pessoas envolvidas e impactos no seu ritmo.",
            "Um resumo neutro pode ser util tanto para voce quanto para qualquer passo futuro que queira considerar.",
        ),
        "support": (
            "Pedir apoio pode comecar por uma frase simples, sem entrar em todos os detalhes.",
            "Voce pode escolher quanto quer contar e para quem quer contar.",
            "Apoio nao precisa significar expor tudo de uma vez.",
        ),
        "work": (
            "Se isso aconteceu no trabalho, estudo ou outro ambiente frequente, pensar em exposicao e registros pode ajudar.",
            "Quando ha convivio continuo ou hierarquia, costuma ser util combinar protecao pratica e organizacao dos fatos.",
            "Se voce precisa voltar a esse ambiente, podemos pensar em medidas concretas para tornar isso menos pesado.",
        ),
        "impact": (
            "Reacoes como confusao, vergonha, culpa ou alerta constante podem aparecer depois de situacoes assim.",
            "Quando algo atravessa desse jeito, e comum ficar revivendo a cena ou se sentindo sem eixo.",
            "O que voce esta sentindo nao precisa ser minimizado para que a gente cuide disso com seriedade.",
        ),
        "general": (
            "Nao precisa contar tudo de uma vez para que isso seja levado com seriedade.",
            "A gente pode focar no pedaco que fizer mais sentido agora.",
            "Voce pode escolher entre organizar os fatos, pensar em seguranca ou ensaiar um pedido de apoio.",
        ),
    }
    SUPPORT_LINES = {
        "safety": (
            "Se quiser, eu posso te ajudar a montar um plano curto para hoje, pensar em um local seguro ou definir com quem falar primeiro.",
            "Podemos fazer um passo a passo bem pratico para agora, com foco em te deixar mais protegida.",
            "Se fizer sentido, eu te ajudo a escolher uma acao pequena e concreta para este momento.",
        ),
        "uncertainty": (
            "Se quiser, eu posso te ajudar a entender melhor a situacao ou organizar os fatos com calma.",
            "A gente pode olhar para o que aconteceu por etapas, sem te pressionar a concluir nada ja.",
            "Posso te ajudar a separar sinais importantes e pensar em proximos passos possiveis.",
        ),
        "record": (
            "Se fizer sentido, eu posso te ajudar a transformar isso em um rascunho pessoal claro e neutro.",
            "A gente pode montar um registro simples com data, local, pessoas e o que aconteceu.",
            "Posso te acompanhar na organizacao dos fatos de um jeito objetivo e sem pressa.",
        ),
        "support": (
            "Se quiser, eu posso te ajudar a escrever uma mensagem curta para alguem de confianca.",
            "Podemos pensar juntas em quem pode oferecer apoio mais seguro neste momento.",
            "Se fizer sentido, eu te ajudo a ensaiar o que dizer sem precisar explicar tudo.",
        ),
        "work": (
            "Posso te ajudar a pensar em proximos passos que preservem sua seguranca e sua rotina.",
            "Se fizer sentido, a gente pode organizar o que aconteceu e pensar em opcoes praticas para esse ambiente.",
            "Podemos combinar registro, apoio e medidas de protecao para esse contexto especifico.",
        ),
        "impact": (
            "Se quiser, eu posso te ajudar a organizar o que aconteceu ou pensar no que te ajudaria a se sentir um pouco mais firme agora.",
            "Podemos seguir com cuidado e escolher um proximo passo que nao te sobrecarregue.",
            "Se fizer sentido, a gente pode olhar para o que aconteceu e para o que voce precisa neste momento.",
        ),
        "general": (
            "Se quiser, eu posso te ajudar a organizar o que aconteceu ou pensar em proximos passos com calma.",
            "A gente pode seguir por um caminho mais pratico ou mais descritivo, dependendo do que voce precisa agora.",
            "Posso oferecer acolhimento inicial e orientacao geral, sempre no seu ritmo.",
        ),
    }
    QUESTIONS = {
        "safety": (
            "Voce esta em um lugar seguro agora?",
            "Tem alguem de confianca que possa ficar mais perto de voce hoje?",
            "O risco maior e nas proximas horas ou em algum horario especifico?",
        ),
        "uncertainty": (
            "Se fizer sentido, o que te deixou mais em duvida nessa situacao?",
            "Voce prefere olhar primeiro para o que aconteceu ou para como isso te afetou?",
            "Quer me contar o que aconteceu do jeito que ficar mais confortavel?",
        ),
        "record": (
            "Quer comecar pela data aproximada, pelo local ou pelo que foi dito ou feito?",
            "Voce prefere montar uma linha do tempo ou anotar os pontos principais primeiro?",
            "Qual parte seria mais facil de registrar agora?",
        ),
        "support": (
            "Quer que eu te ajude a montar uma mensagem curta para alguem de confianca?",
            "Ja existe alguem com quem voce se sentiria mais segura para falar?",
            "Voce prefere pensar em uma pessoa especifica ou no texto da mensagem primeiro?",
        ),
        "work": (
            "Isso aconteceu em um lugar que voce vai precisar frequentar novamente em breve?",
            "Tem alguma situacao pratica desse ambiente que te preocupa mais agora?",
            "Voce quer pensar primeiro em registro, protecao ou apoio nesse contexto?",
        ),
        "impact": (
            "O que esta pesando mais agora: medo, confusao, vergonha ou outra coisa?",
            "Voce quer organizar o que aconteceu ou pensar no que te ajudaria hoje?",
            "Tem alguma parte especifica disso que esta mais dificil de carregar agora?",
        ),
        "general": (
            "Voce prefere organizar os fatos ou pensar em proximos passos agora?",
            "Quer me contar um pouco mais, so ate onde for confortavel?",
            "Qual seria a ajuda mais util para voce neste momento?",
        ),
    }
    SCOPE_NOTES = (
        "Eu posso oferecer acolhimento inicial e orientacao geral, sem substituir apoio psicologico, juridico, medico ou policial.",
        "Posso te acompanhar com acolhimento inicial e orientacao geral, mas nao substituo ajuda profissional.",
        "Estou aqui para acolhimento inicial e orientacao geral, sem ocupar o lugar de apoio especializado.",
    )
    GENERIC_MARKERS = (
        "sinto muito que voce esteja passando por isso",
        "posso oferecer acolhimento inicial e orientacao geral",
        "sem julgamentos",
    )
    PROFESSIONAL_HINTS = (
        "psicolog",
        "terapeut",
        "advog",
        "polic",
        "medic",
        "delegacia",
        "boletim",
        "o que voce pode fazer",
    )
    CONTEXT_TERMS = {
        "safety": ("seguranca", "seguro", "local seguro", "hoje", "agora", "apoio"),
        "uncertainty": ("duvida", "fatos", "aconteceu", "nomear", "olhar"),
        "record": ("registro", "resumo", "linha do tempo", "data", "local", "fatos"),
        "support": ("apoio", "mensagem", "confianca", "conversa", "ajuda"),
        "work": ("trabalho", "ambiente", "rotina", "hierarquia", "registro"),
        "impact": ("afetou", "peso", "confusao", "vergonha", "medo"),
        "general": ("ritmo", "calma", "organizar", "proximos passos"),
    }

    def select_history(
        self,
        *,
        stored_history: Sequence[dict[str, str]],
        client_history: Sequence[dict[str, str]] | None,
        latest_message: str,
    ) -> list[dict[str, str]]:
        stored = self._sanitize_history(stored_history)
        client = self._sanitize_history(client_history or [])
        history = client if client and len(client) >= len(stored) else stored

        normalized_latest = self._normalize(latest_message)
        if not history or history[-1]["role"] != "user" or self._normalize(history[-1]["content"]) != normalized_latest:
            history = [*history, {"role": "user", "content": latest_message}]

        return history[-12:]

    def build_context(
        self,
        history: Sequence[dict[str, str]],
        *,
        latest_message: str,
        risk: RiskAssessmentResponse,
    ) -> ConversationContext:
        sanitized_history = self._sanitize_history(history)
        recent_user_messages = tuple(
            item["content"] for item in sanitized_history if item["role"] == "user"
        )[-4:]
        recent_assistant_messages = tuple(
            item["content"] for item in sanitized_history if item["role"] == "assistant"
        )[-3:]
        recent_openings = tuple(
            opening
            for opening in (self._first_sentence(item) for item in recent_assistant_messages)
            if opening
        )

        signal_scores = self._score_signals(
            latest_message=latest_message,
            recent_user_messages=recent_user_messages,
            risk=risk,
        )
        ordered_signals = sorted(
            signal_scores.items(),
            key=lambda item: (-item[1], self.SIGNAL_PRIORITY.index(item[0])),
        )
        primary_signal = ordered_signals[0][0] if ordered_signals else "general"
        secondary_signals = tuple(item[0] for item in ordered_signals[1:3])
        normalized_latest = self._normalize(latest_message)

        return ConversationContext(
            primary_signal=primary_signal,
            secondary_signals=secondary_signals,
            recent_user_messages=recent_user_messages,
            recent_assistant_messages=recent_assistant_messages,
            recent_openings=recent_openings,
            should_offer_scope_note=(
                len(recent_assistant_messages) == 0
                or any(term in normalized_latest for term in self.PROFESSIONAL_HINTS)
            ),
            should_ask_question=(
                risk.level in {"low", "moderate"}
                and len(latest_message.split()) <= 80
                and "nao quero responder" not in normalized_latest
                and "nao quero falar" not in normalized_latest
            ),
            is_follow_up=len(recent_user_messages) > 1 or len(recent_assistant_messages) > 0,
        )

    def build_llm_guidance(self, context: ConversationContext, risk: RiskAssessmentResponse) -> str:
        lines = [
            "Responda em portugues natural, com no maximo 4 frases curtas e linguagem nao repetitiva.",
            f"Foco principal da conversa: {self._signal_label(context.primary_signal)}.",
        ]
        if context.secondary_signals:
            labels = ", ".join(self._signal_label(item) for item in context.secondary_signals)
            lines.append(f"Sinais secundarios recentes: {labels}.")
        if context.is_follow_up:
            lines.append("A conversa ja esta em andamento; nao responda como se fosse o primeiro contato.")
        if context.recent_openings:
            lines.append(
                "Evite repetir estas aberturas recentes: "
                + " | ".join(context.recent_openings)
                + "."
            )
        if context.recent_assistant_messages:
            lines.append(
                "Nao reutilize frases ou estruturas muito parecidas com estas respostas recentes: "
                + " | ".join(self._truncate_text(item, 140) for item in context.recent_assistant_messages)
                + "."
            )
        if context.should_offer_scope_note:
            lines.append(
                "Se for apropriado, mencione em uma unica frase breve que voce oferece acolhimento inicial "
                "e orientacao geral, sem substituir ajuda profissional."
            )
        else:
            lines.append("Nao repita avisos de escopo nesta resposta, a menos que isso seja realmente necessario.")
        if risk.level in {"high", "critical"}:
            lines.append(
                "Como ha sinal de risco elevado, priorize seguranca imediata, reduza a resposta "
                "e faca no maximo uma pergunta curta."
            )
        else:
            lines.append(
                "Siga a estrutura: acolhimento breve, interpretacao do que foi dito, "
                "orientacao ou analise cuidadosa e pergunta opcional."
            )
        return " ".join(lines)

    def compose_response(
        self,
        *,
        latest_message: str,
        history: Sequence[dict[str, str]],
        risk: RiskAssessmentResponse,
        context: ConversationContext | None = None,
    ) -> str:
        context = context or self.build_context(history, latest_message=latest_message, risk=risk)
        if risk.level in {"high", "critical"} or context.primary_signal == "safety":
            return self._compose_safety_response(latest_message, risk, context)

        seed = self._seed_from(latest_message, history, risk.level)
        opening = self._pick_phrase(
            self.OPENINGS.get(context.primary_signal, self.OPENINGS["general"]),
            seed=f"{seed}|opening",
            blocked=context.recent_openings,
        )
        context_line = self._pick_phrase(
            self.CONTEXT_LINES.get(context.primary_signal, self.CONTEXT_LINES["general"]),
            seed=f"{seed}|context",
            blocked=context.recent_assistant_messages,
        )
        support_key = context.primary_signal
        if support_key == "general" and "work" in context.secondary_signals:
            support_key = "work"
        support_line = self._pick_phrase(
            self.SUPPORT_LINES.get(support_key, self.SUPPORT_LINES["general"]),
            seed=f"{seed}|support",
            blocked=context.recent_assistant_messages,
        )
        parts = [opening, context_line, support_line]

        if context.should_offer_scope_note:
            parts.append(
                self._pick_phrase(
                    self.SCOPE_NOTES,
                    seed=f"{seed}|scope",
                    blocked=context.recent_assistant_messages,
                )
            )

        body = " ".join(self._dedupe_text_parts(parts)[:4]).strip()
        body = self._limit_sentences(body, max_sentences=4)

        if context.should_ask_question:
            question = self._pick_phrase(
                self.QUESTIONS.get(context.primary_signal, self.QUESTIONS["general"]),
                seed=f"{seed}|question",
                blocked=context.recent_assistant_messages,
            )
            return f"{body}\n\n{question}".strip()

        return body

    def finalize_response(
        self,
        candidate: str | None,
        *,
        latest_message: str,
        history: Sequence[dict[str, str]],
        risk: RiskAssessmentResponse,
        context: ConversationContext | None = None,
    ) -> str:
        context = context or self.build_context(history, latest_message=latest_message, risk=risk)
        if not candidate or not candidate.strip():
            return self.compose_response(
                latest_message=latest_message,
                history=history,
                risk=risk,
                context=context,
            )

        repaired = self._sanitize_text(candidate)
        repaired = self._dedupe_sentences(repaired)
        repaired = self._limit_sentences(
            repaired,
            max_sentences=2 if risk.level in {"high", "critical"} else 4,
        )

        if risk.level in {"high", "critical"}:
            normalized = self._normalize(repaired)
            has_safety_terms = any(
                term in normalized
                for term in ("seguranca", "local seguro", "emergencia", "pessoa de confianca")
            )
            if not has_safety_terms or len(repaired) > 360:
                return self._compose_safety_response(latest_message, risk, context)

        if self._looks_repetitive(repaired, context.recent_assistant_messages, context.recent_openings):
            return self.compose_response(
                latest_message=latest_message,
                history=history,
                risk=risk,
                context=context,
            )

        if self._looks_generic(repaired, context):
            return self.compose_response(
                latest_message=latest_message,
                history=history,
                risk=risk,
                context=context,
            )

        return repaired

    def _compose_safety_response(
        self,
        latest_message: str,
        risk: RiskAssessmentResponse,
        context: ConversationContext,
    ) -> str:
        seed = self._seed_from(latest_message, context.recent_user_messages, risk.level)
        opening = self._pick_phrase(
            self.OPENINGS["safety"],
            seed=f"{seed}|opening",
            blocked=context.recent_openings,
        )
        detail_options = [
            "Se houver chance de contato, tente ir para um local seguro e acionar uma pessoa de confianca ou a emergencia local agora.",
            "Se voce estiver exposta ou em perigo imediato, procure um lugar mais seguro e busque ajuda humana neste momento.",
            "Se o risco for agora, vale reduzir contato, ir para um lugar seguro e chamar apoio imediatamente.",
        ]
        if risk.level == "critical":
            detail_options = [
                "Se o perigo for imediato, tente sair para um local seguro agora e acione emergencia local ou uma pessoa de confianca sem esperar.",
                "Se houver risco agora, priorize sair desse contexto, ir para um local seguro e chamar ajuda imediatamente.",
                "Se voce nao estiver segura neste momento, procure ajuda humana e um local seguro agora.",
            ]
        detail = self._pick_phrase(
            detail_options,
            seed=f"{seed}|detail",
            blocked=context.recent_assistant_messages,
        )
        question = self._pick_phrase(
            self.QUESTIONS["safety"],
            seed=f"{seed}|question",
            blocked=context.recent_assistant_messages,
        )
        return f"{opening} {detail}\n\n{question}"

    def _score_signals(
        self,
        *,
        latest_message: str,
        recent_user_messages: Sequence[str],
        risk: RiskAssessmentResponse,
    ) -> dict[str, int]:
        latest_normalized = self._normalize(latest_message)
        recent_normalized = self._normalize(" ".join(recent_user_messages))
        scores: dict[str, int] = {}

        for signal, patterns in self.SIGNAL_PATTERNS.items():
            score = 0
            for pattern in patterns:
                if pattern in latest_normalized:
                    score += 2
                if pattern in recent_normalized:
                    score += 1
            if signal == "safety" and risk.level in {"high", "critical"}:
                score += 5
            if signal == "safety" and "medo" in latest_normalized:
                score += 2
            if score > 0:
                scores[signal] = score
        return scores

    def _pick_phrase(
        self,
        options: Sequence[str],
        *,
        seed: str,
        blocked: Iterable[str],
    ) -> str:
        cleaned = [item.strip() for item in options if item.strip()]
        if not cleaned:
            return ""
        blocked_items = [self._normalize(item) for item in blocked if item.strip()]
        ordered = sorted(cleaned, key=lambda item: self._stable_rank(f"{seed}|{item}"))
        for item in ordered:
            if not self._matches_recent(item, blocked_items):
                return item
        return ordered[0]

    def _matches_recent(self, candidate: str, blocked_items: Sequence[str]) -> bool:
        normalized_candidate = self._normalize(candidate)
        for blocked in blocked_items:
            if normalized_candidate == blocked or self._is_similar(normalized_candidate, blocked):
                return True
        return False

    def _looks_repetitive(
        self,
        candidate: str,
        recent_messages: Sequence[str],
        recent_openings: Sequence[str],
    ) -> bool:
        normalized_candidate = self._normalize(candidate)
        candidate_opening = self._normalize(self._first_sentence(candidate))
        for item in recent_messages:
            normalized_item = self._normalize(item)
            if normalized_candidate == normalized_item or self._is_similar(normalized_candidate, normalized_item):
                return True
        for opening in recent_openings:
            normalized_opening = self._normalize(opening)
            if candidate_opening and (
                candidate_opening == normalized_opening
                or self._is_similar(candidate_opening, normalized_opening)
            ):
                return True
        return False

    def _looks_generic(self, candidate: str, context: ConversationContext) -> bool:
        normalized = self._normalize(candidate)
        if len(normalized.split()) < 8:
            return True

        if any(marker in normalized for marker in self.GENERIC_MARKERS):
            context_terms = self.CONTEXT_TERMS.get(context.primary_signal, self.CONTEXT_TERMS["general"])
            if not any(term in normalized for term in context_terms):
                return True
        return False

    def _dedupe_text_parts(self, parts: Sequence[str]) -> list[str]:
        unique: list[str] = []
        for part in parts:
            cleaned = self._sanitize_text(part)
            if cleaned and not any(
                self._is_similar(self._normalize(cleaned), self._normalize(existing))
                for existing in unique
            ):
                unique.append(cleaned)
        return unique

    def _dedupe_sentences(self, text: str) -> str:
        unique: list[str] = []
        for sentence in self._split_sentences(text):
            if not any(
                self._is_similar(self._normalize(sentence), self._normalize(existing))
                for existing in unique
            ):
                unique.append(sentence)
        return " ".join(unique).strip()

    def _limit_sentences(self, text: str, *, max_sentences: int) -> str:
        paragraphs = [item.strip() for item in text.split("\n") if item.strip()]
        limited: list[str] = []
        remaining = max_sentences
        for paragraph in paragraphs:
            if remaining <= 0:
                break
            sentences = self._split_sentences(paragraph)
            if not sentences:
                continue
            chunk = sentences[:remaining]
            limited.append(" ".join(chunk).strip())
            remaining -= len(chunk)
        return "\n\n".join(limited).strip() if limited else text.strip()

    def _split_sentences(self, text: str) -> list[str]:
        compact = re.sub(r"\s+", " ", text.strip())
        if not compact:
            return []
        return [item.strip() for item in re.split(r"(?<=[.!?])\s+", compact) if item.strip()]

    def _sanitize_text(self, text: str) -> str:
        compact = text.replace("\r\n", "\n").replace("\r", "\n")
        compact = re.sub(r"[ \t]+", " ", compact)
        compact = re.sub(r"\n{3,}", "\n\n", compact)
        return compact.strip()

    def _sanitize_history(self, history: Sequence[dict[str, str]]) -> list[dict[str, str]]:
        sanitized: list[dict[str, str]] = []
        for item in history:
            role = str(item.get("role", "")).strip().lower()
            content = str(item.get("content", "")).strip()
            if role not in {"user", "assistant"} or not content:
                continue
            sanitized.append({"role": role, "content": content})
        return sanitized[-12:]

    def _normalize(self, text: str) -> str:
        normalized = unicodedata.normalize("NFKD", text.lower())
        normalized = "".join(char for char in normalized if not unicodedata.combining(char))
        return re.sub(r"\s+", " ", normalized).strip()

    def _first_sentence(self, text: str) -> str:
        sentences = self._split_sentences(text)
        return sentences[0] if sentences else text.strip()

    def _is_similar(self, left: str, right: str) -> bool:
        if not left or not right:
            return False
        if left == right or left in right or right in left:
            return True

        left_tokens = {item for item in left.split() if len(item) > 3}
        right_tokens = {item for item in right.split() if len(item) > 3}
        if len(left_tokens) < 3 or len(right_tokens) < 3:
            return False

        overlap = len(left_tokens & right_tokens)
        baseline = min(len(left_tokens), len(right_tokens))
        return baseline > 0 and overlap / baseline >= 0.75

    def _seed_from(self, *parts: object) -> str:
        joined = "|".join(str(item) for item in parts)
        return hashlib.md5(joined.encode("utf-8")).hexdigest()

    def _stable_rank(self, value: str) -> str:
        return hashlib.md5(value.encode("utf-8")).hexdigest()

    def _signal_label(self, signal: str) -> str:
        labels = {
            "safety": "seguranca e risco atual",
            "uncertainty": "duvida sobre o que aconteceu",
            "record": "organizacao e registro dos fatos",
            "support": "busca de apoio e rede de confianca",
            "work": "contexto de trabalho, estudo ou convivio frequente",
            "impact": "impacto emocional e efeito da situacao",
            "general": "acolhimento inicial e proximo passo mais util",
        }
        return labels.get(signal, labels["general"])

    def _truncate_text(self, text: str, size: int) -> str:
        compact = self._sanitize_text(text)
        if len(compact) <= size:
            return compact
        return f"{compact[: size - 3].rstrip()}..."
