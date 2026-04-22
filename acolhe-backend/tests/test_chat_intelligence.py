from __future__ import annotations

from app.modules.chat.intelligence.conversation_memory_service import ConversationMemoryService
from app.modules.chat.intelligence.models import ConversationMemory
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
