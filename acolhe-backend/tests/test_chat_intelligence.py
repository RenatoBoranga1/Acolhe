from __future__ import annotations

from app.modules.chat.intelligence.conversation_memory_service import ConversationMemoryService
from app.modules.chat.intelligence.models import (
    ConversationMemory,
    ResponseMode,
    RiskAssessmentResult,
    SituationClassification,
)
from app.modules.chat.intelligence.prompt_builder_service import PromptBuilderService
from app.modules.chat.intelligence.response_orchestrator_service import ResponseOrchestratorService
from app.modules.chat.intelligence.response_validator_service import ResponseValidatorService
from app.modules.chat.intelligence.risk_assessment_service import RiskAssessmentService
from app.modules.chat.intelligence.situation_classifier_service import SituationClassifierService
from app.modules.chat.intelligence.tone_selector_service import ToneSelectorService


def test_situation_classifier_detects_repeated_harassment_uncertainty() -> None:
    memory = ConversationMemory(conversation_id="conversation-1")
    classifier = SituationClassifierService()

    result = classifier.classify(
        message="Nao sei se estou exagerando, mas ele faz comentarios sobre meu corpo toda semana.",
        history=[],
        memory=memory,
    )

    assert result.type == "harassment_uncertainty"
    assert result.confidence >= 0.5
    assert result.signals


def test_risk_assessment_escalates_fear_of_reencounter() -> None:
    memory = ConversationMemory(conversation_id="conversation-1")
    situation = SituationClassifierService().classify(
        message="Estou com medo porque ele disse que vai me encontrar hoje.",
        history=[],
        memory=memory,
    )

    risk = RiskAssessmentService().assess(
        message="Estou com medo porque ele disse que vai me encontrar hoje.",
        history=[],
        memory=memory,
        situation=situation,
    )

    assert risk.level == "high"
    assert risk.score >= 0.82
    assert risk.recommended_mode == "safety_first"
    assert any("medo" in trigger or "situacao" in trigger for trigger in risk.triggers)


def test_tone_selector_uses_decision_support_for_reporting_ambivalence() -> None:
    memory = ConversationMemory(conversation_id="conversation-1", wants_to_report="unsure")
    situation = SituationClassifierService().classify(
        message="Quero denunciar, mas nao consigo decidir.",
        history=[],
        memory=memory,
    )
    risk = RiskAssessmentService().assess(
        message="Quero denunciar, mas nao consigo decidir.",
        history=[],
        memory=memory,
        situation=situation,
    )

    mode = ToneSelectorService().select(
        risk=risk,
        situation=situation,
        memory=memory,
        history=[],
    )

    assert situation.type == "reporting_ambivalence"
    assert mode.name == "decision_support"


def test_memory_updates_structured_context() -> None:
    service = ConversationMemoryService()
    memory = ConversationMemory(conversation_id="conversation-1")
    situation = SituationClassifierService().classify(
        message="Meu chefe faz isso toda semana e tenho prints das mensagens.",
        history=[],
        memory=memory,
    )
    risk = RiskAssessmentService().assess(
        message="Meu chefe faz isso toda semana e tenho prints das mensagens.",
        history=[],
        memory=memory,
        situation=situation,
    )

    updated = service.update(
        memory=memory,
        latest_message="Meu chefe faz isso toda semana e tenho prints das mensagens.",
        history=[{"role": "user", "content": "Meu chefe faz isso toda semana e tenho prints das mensagens."}],
        risk=risk,
        situation=situation,
        response_mode="structured_guidance",
    )

    assert updated.aggressor_relation == "boss"
    assert updated.repeated_behavior == "yes"
    assert updated.evidence_status == "mentioned"
    assert updated.current_situation_type == situation.type
    assert updated.known_facts


def test_prompt_builder_adds_specific_reporting_ambivalence_guidance() -> None:
    memory = ConversationMemory(
        conversation_id="conversation-1",
        wants_to_report="unsure",
        known_facts=["A usuaria quer denunciar, mas esta indecisa."],
    )
    risk = RiskAssessmentResult(
        level="moderate",
        score=0.35,
        triggers=["ambivalencia sobre denuncia"],
        rationale="sem risco imediato informado",
        recommended_mode="decision_support",
        recommended_actions=["organizar opcoes"],
        requires_immediate_action=False,
    )
    situation = SituationClassification(
        type="reporting_ambivalence",
        confidence=0.8,
        signals=["denunciar", "nao consigo decidir"],
    )

    prompt = PromptBuilderService().build(
        memory=memory,
        risk=risk,
        situation=situation,
        response_mode=ResponseMode("decision_support", "ambivalencia detectada"),
        recent_assistant_openings=["Podemos olhar para isso com calma."],
    )

    guidance = prompt.response_guidance.lower()
    assert "nao use imperativos" in guidance
    assert "preparar-se" in guidance
    assert "decidir denunciar" in guidance
    assert "evite repetir" in guidance


def test_validator_repairs_structural_repetition_even_with_different_words() -> None:
    memory = ConversationMemory(
        conversation_id="conversation-1",
        known_facts=["Comentarios sobre o corpo acontecem toda semana."],
    )
    risk = RiskAssessmentResult(
        level="moderate",
        score=0.4,
        triggers=["comentarios recorrentes"],
        rationale="risco moderado por recorrencia",
        recommended_mode="structured_guidance",
        recommended_actions=["organizar fatos"],
        requires_immediate_action=False,
    )
    situation = SituationClassification(
        type="harassment_uncertainty",
        confidence=0.9,
        signals=["comentarios sobre meu corpo", "toda semana"],
    )

    result = ResponseValidatorService().validate(
        candidate=(
            "Faz sentido isso ter te afetado. "
            "Posso te ajudar a organizar os comentarios repetidos e o contexto com calma. "
            "Quer me contar um pouco mais?"
        ),
        fallback=(
            "Os comentarios repetidos sobre seu corpo e o contexto importam para olhar isso com cuidado. "
            "Podemos separar fatos, frequencia e impacto sem afirmar nada com pressa."
        ),
        risk=risk,
        situation=situation,
        response_mode=ResponseMode("structured_guidance", "analise cuidadosa"),
        memory=memory,
        recent_assistant_messages=[
            "Faz sentido voce se sentir assim. Posso te ajudar a organizar isso com calma. Quer me contar um pouco mais?"
        ],
    )

    assert result.repaired is True
    assert "structural_repetition" in result.issues


def test_orchestrator_records_safe_metrics_for_fallback() -> None:
    result = ResponseOrchestratorService().respond(
        conversation_id="conversation-1",
        latest_message="Quero denunciar, mas nao consigo decidir.",
        stored_messages=[],
        client_history=[],
    )

    assert result.metrics.fallback_used is True
    assert result.metrics.situation_type == "reporting_ambivalence"
    assert result.metrics.risk_level in {"low", "moderate"}
    assert result.metrics.repaired in {True, False}
