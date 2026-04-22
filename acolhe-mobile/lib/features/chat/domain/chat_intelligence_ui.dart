import 'package:acolhe_mobile/shared/models/app_models.dart';

enum ChatSituationKind {
  harassmentUncertainty,
  fearOfReencounter,
  workplaceHarassment,
  incidentRecord,
  reportingAmbivalence,
  emotionalCrisis,
  supportRequest,
  stalking,
  coercion,
  initialDisclosure,
  unknown,
}

extension ChatSituationKindX on ChatSituationKind {
  static ChatSituationKind fromBackend(String? value) {
    final normalized = _normalize(value);
    return switch (normalized) {
      'harassment_uncertainty' ||
      'duvida_se_foi_assedio' ||
      'uncertainty' =>
        ChatSituationKind.harassmentUncertainty,
      'fear_of_reencounter' ||
      'medo_de_reencontro' ||
      'risk_immediate' =>
        ChatSituationKind.fearOfReencounter,
      'workplace_harassment' ||
      'assedio_no_trabalho' ||
      'workplace' =>
        ChatSituationKind.workplaceHarassment,
      'incident_record' ||
      'registro_do_ocorrido' ||
      'private_record' =>
        ChatSituationKind.incidentRecord,
      'reporting_ambivalence' ||
      'inseguranca_para_denunciar' ||
      'decision_support' =>
        ChatSituationKind.reportingAmbivalence,
      'emotional_crisis' ||
      'crise_emocional' ||
      'grounding' =>
        ChatSituationKind.emotionalCrisis,
      'support_request' ||
      'pedido_de_apoio' ||
      'trusted_contact' =>
        ChatSituationKind.supportRequest,
      'stalking' || 'perseguicao' => ChatSituationKind.stalking,
      'coercion' || 'coercao' || 'manipulation' => ChatSituationKind.coercion,
      'initial_disclosure' ||
      'relato_inicial' =>
        ChatSituationKind.initialDisclosure,
      _ => ChatSituationKind.unknown,
    };
  }

  String get label => switch (this) {
        ChatSituationKind.harassmentUncertainty => 'Analise cuidadosa',
        ChatSituationKind.fearOfReencounter => 'Medo de reencontro',
        ChatSituationKind.workplaceHarassment => 'Contexto de trabalho',
        ChatSituationKind.incidentRecord => 'Registro do ocorrido',
        ChatSituationKind.reportingAmbivalence => 'Decisao sem pressa',
        ChatSituationKind.emotionalCrisis => 'Apoio de estabilizacao',
        ChatSituationKind.supportRequest => 'Pedido de apoio',
        ChatSituationKind.stalking => 'Perseguicao',
        ChatSituationKind.coercion => 'Coercao ou pressao',
        ChatSituationKind.initialDisclosure => 'Relato inicial',
        ChatSituationKind.unknown => 'Contexto em analise',
      };

  String get userFacingSummary => switch (this) {
        ChatSituationKind.harassmentUncertainty =>
          'A conversa esta focada em entender a situacao com cuidado, sem conclusoes apressadas.',
        ChatSituationKind.fearOfReencounter =>
          'A prioridade agora e reduzir exposicao e pensar em passos praticos de seguranca.',
        ChatSituationKind.workplaceHarassment =>
          'Podemos organizar fatos, recorrencia, evidencias e opcoes institucionais com cautela.',
        ChatSituationKind.incidentRecord =>
          'Se fizer sentido, transforme os fatos em um registro pessoal claro e cronologico.',
        ChatSituationKind.reportingAmbivalence =>
          'A decisao pode ser pensada por opcoes, sem pressao e com apoio humano quando possivel.',
        ChatSituationKind.emotionalCrisis =>
          'A resposta deve ser mais curta, calma e focada em estabilizacao imediata.',
        ChatSituationKind.supportRequest =>
          'Pode ser hora de acionar alguem de confianca com uma mensagem simples e segura.',
        ChatSituationKind.stalking =>
          'A conversa indica possivel acompanhamento indesejado; vale priorizar protecao e rede de apoio.',
        ChatSituationKind.coercion =>
          'A conversa indica pressao ou manipulacao; podemos separar fatos, limites e apoio seguro.',
        ChatSituationKind.initialDisclosure =>
          'A assistente esta acompanhando o relato inicial no ritmo da pessoa.',
        ChatSituationKind.unknown =>
          'A assistente esta coletando contexto suficiente para responder melhor.',
      };

  bool get shouldHighlightSafety =>
      this == ChatSituationKind.fearOfReencounter ||
      this == ChatSituationKind.stalking ||
      this == ChatSituationKind.coercion ||
      this == ChatSituationKind.emotionalCrisis;

  bool get shouldHighlightIncidentRecord =>
      this == ChatSituationKind.incidentRecord ||
      this == ChatSituationKind.workplaceHarassment ||
      this == ChatSituationKind.harassmentUncertainty;

  bool get shouldHighlightSupport =>
      this == ChatSituationKind.supportRequest ||
      this == ChatSituationKind.reportingAmbivalence ||
      this == ChatSituationKind.emotionalCrisis;
}

enum ChatResponseModeKind {
  calmSupport,
  structuredGuidance,
  safetyFirst,
  decisionSupport,
  groundingMode,
  localSafeFallback,
  unknown,
}

extension ChatResponseModeKindX on ChatResponseModeKind {
  static ChatResponseModeKind fromBackend(String? value) {
    final normalized = _normalize(value);
    return switch (normalized) {
      'calm_support' => ChatResponseModeKind.calmSupport,
      'structured_guidance' => ChatResponseModeKind.structuredGuidance,
      'safety_first' => ChatResponseModeKind.safetyFirst,
      'decision_support' => ChatResponseModeKind.decisionSupport,
      'grounding_mode' => ChatResponseModeKind.groundingMode,
      'local_safe_fallback' => ChatResponseModeKind.localSafeFallback,
      _ => ChatResponseModeKind.unknown,
    };
  }

  String get label => switch (this) {
        ChatResponseModeKind.calmSupport => 'Acolhimento calmo',
        ChatResponseModeKind.structuredGuidance => 'Orientacao estruturada',
        ChatResponseModeKind.safetyFirst => 'Seguranca primeiro',
        ChatResponseModeKind.decisionSupport => 'Apoio a decisao',
        ChatResponseModeKind.groundingMode => 'Estabilizacao',
        ChatResponseModeKind.localSafeFallback => 'Fallback local seguro',
        ChatResponseModeKind.unknown => 'Modo em analise',
      };
}

class ChatCtaIntent {
  const ChatCtaIntent({
    required this.label,
    required this.route,
    required this.priority,
  });

  final String label;
  final String route;
  final int priority;

  static ChatCtaIntent fromLabel(String label) {
    final normalized = _normalize(label);
    if (_containsAny(
        normalized, const ['emergencia', 'urgente', 'ligar', 'servico'])) {
      return ChatCtaIntent(label: label, route: '/urgent-help', priority: 0);
    }
    if (_containsAny(normalized, const ['plano', 'seguranca', 'fuga'])) {
      return ChatCtaIntent(label: label, route: '/safety-plan', priority: 1);
    }
    if (_containsAny(
        normalized, const ['apoio', 'confianca', 'contato', 'mensagem'])) {
      return ChatCtaIntent(
          label: label, route: '/support-network', priority: 2);
    }
    if (_containsAny(normalized,
        const ['registro', 'resumo', 'cronologico', 'evidencia', 'fato'])) {
      return ChatCtaIntent(
          label: label, route: '/incident-record', priority: 3);
    }
    if (_containsAny(
        normalized, const ['direito', 'informacao', 'orientacao'])) {
      return ChatCtaIntent(label: label, route: '/resources', priority: 4);
    }
    return ChatCtaIntent(label: label, route: '/chat', priority: 9);
  }
}

bool chatRiskNeedsPriority(RiskAssessment risk) {
  return risk.requiresImmediateAction ||
      risk.level.index >= RiskLevel.high.index;
}

bool isLocalFallbackContext(Map<String, dynamic>? conversationContext) {
  return conversationContext?['source'] == 'mobile_local_fallback';
}

String _normalize(String? value) {
  return (value ?? '')
      .toLowerCase()
      .trim()
      .replaceAll('\u00e7', 'c')
      .replaceAll('\u00e3', 'a')
      .replaceAll('\u00e1', 'a')
      .replaceAll('\u00e0', 'a')
      .replaceAll('\u00e2', 'a')
      .replaceAll('\u00e9', 'e')
      .replaceAll('\u00ea', 'e')
      .replaceAll('\u00ed', 'i')
      .replaceAll('\u00f3', 'o')
      .replaceAll('\u00f4', 'o')
      .replaceAll('\u00f5', 'o')
      .replaceAll('\u00fa', 'u')
      .replaceAll(RegExp(r'[\s-]+'), '_');
}

bool _containsAny(String value, List<String> needles) {
  final compact = value.replaceAll('_', ' ');
  return needles.any((needle) => compact.contains(needle));
}
