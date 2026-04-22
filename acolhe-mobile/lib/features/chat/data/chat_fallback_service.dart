import 'package:acolhe_mobile/features/chat/data/chat_result.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';

class ChatFallbackService {
  const ChatFallbackService();

  ChatSendResult buildSafeReply({
    required String conversationId,
    required String text,
    required List<ChatMessageModel> history,
  }) {
    final risk = _assessRisk(text);
    final response = _composeReply(text, history, risk);
    return ChatSendResult(
      conversationId: conversationId,
      assistantMessage: ChatMessageModel(
        id: generateId(),
        role: MessageRole.assistant,
        content: response,
        riskLevel: risk.level,
        createdAt: DateTime.now(),
      ),
      risk: risk,
      ctas: risk.requiresImmediateAction
          ? const [
              'Buscar local seguro',
              'Contatar pessoa de confianca',
              'Abrir plano de seguranca',
            ]
          : const [
              'Registrar o que aconteceu',
              'Pensar nos proximos passos',
              'Falar com alguem de confianca',
            ],
      suggestions: const [
        'Nao sei por onde comecar',
        'Quero entender se isso foi assedio',
        'Estou com medo',
        'Quero registrar o que aconteceu',
        'Quero pensar nos proximos passos',
        'Quero ajuda para falar com alguem de confianca',
      ],
      responseMode:
          risk.requiresImmediateAction ? 'safety_first' : 'local_safe_fallback',
      situationType: _inferSituationType(text),
      conversationContext: {
        'source': 'mobile_local_fallback',
        'history_size': history.length,
      },
      servedFromFallback: true,
    );
  }

  RiskAssessment _assessRisk(String text) {
    final normalized = text.toLowerCase();
    if (_containsAny(normalized, const [
      'quero morrer',
      'vou me matar',
      'tirar minha vida',
      'ele esta aqui',
      'estou presa',
      'na minha porta',
    ])) {
      return const RiskAssessment(
        level: RiskLevel.critical,
        score: 10,
        reasons: ['sinais de risco critico informados na mensagem'],
        actions: [
          'Procure um local seguro agora',
          'Acione emergencia local',
          'Contate uma pessoa de confianca imediatamente',
        ],
        requiresImmediateAction: true,
      );
    }

    var score = 0;
    final reasons = <String>[];
    if (_containsAny(
        normalized, const ['medo', 'ameaca', 'ameacou', 'encontrar hoje'])) {
      score += 3;
      reasons.add('medo imediato ou possivel ameaca');
    }
    if (_containsAny(normalized,
        const ['persegu', 'forcou', 'coag', 'me bateu', 'chantagem'])) {
      score += 3;
      reasons.add('coacao, perseguicao ou violencia');
    }
    if (_containsAny(
        normalized, const ['assedio', 'passou do limite', 'registrar'])) {
      score += 1;
      reasons.add('situacao sensivel que pede organizacao cuidadosa');
    }

    if (score >= 6) {
      return RiskAssessment(
        level: RiskLevel.high,
        score: score,
        reasons: reasons,
        actions: const [
          'Priorizar seguranca fisica',
          'Acionar apoio humano',
          'Evitar contato direto se houver risco',
        ],
        requiresImmediateAction: true,
      );
    }
    if (score >= 2) {
      return RiskAssessment(
        level: RiskLevel.moderate,
        score: score,
        reasons: reasons,
        actions: const [
          'Organizar fatos com calma',
          'Pensar em apoio de confianca',
          'Escolher proximos passos sem pressao',
        ],
        requiresImmediateAction: false,
      );
    }
    return const RiskAssessment(
      level: RiskLevel.low,
      score: 0,
      reasons: ['sem sinal explicito de risco imediato'],
      actions: [
        'Conversar no seu ritmo',
        'Registrar se isso ajudar',
        'Buscar apoio humano se fizer sentido',
      ],
      requiresImmediateAction: false,
    );
  }

  String _composeReply(
    String text,
    List<ChatMessageModel> history,
    RiskAssessment risk,
  ) {
    if (risk.requiresImmediateAction) {
      return 'Quero priorizar sua seguranca agora. Se houver risco imediato, tente ir para um local seguro e acionar emergencia local ou uma pessoa de confianca.\n\nVoce esta em um lugar seguro neste momento?';
    }

    final hasAskedAboutHarassment = text.toLowerCase().contains('assedio') ||
        text.toLowerCase().contains('passou do limite');
    final alreadyHadContext =
        history.any((item) => item.role == MessageRole.user);
    if (hasAskedAboutHarassment) {
      return 'Faz sentido querer olhar para isso com cuidado. A gente pode separar o que aconteceu, como voce se sentiu e se houve repeticao ou pressao, sem concluir nada com pressa.\n\nQuer comecar pelo que foi dito ou feito?';
    }
    if (alreadyHadContext) {
      return 'A gente pode seguir por partes, usando o que voce ja contou. Posso te ajudar a organizar os fatos, pensar em seguranca ou preparar uma mensagem para alguem de confianca.\n\nQual desses caminhos parece mais util agora?';
    }
    return 'Podemos comecar com calma. Voce pode contar so o que se sentir confortavel, e eu ajudo a organizar isso sem julgamento.\n\nVoce prefere falar sobre o que aconteceu ou pensar primeiro em proximos passos?';
  }

  String _inferSituationType(String text) {
    final normalized = text.toLowerCase();
    if (_containsAny(normalized, const ['medo', 'ameaca', 'encontrar hoje'])) {
      return 'medo_de_reencontro';
    }
    if (_containsAny(normalized, const ['registr', 'resumo', 'anotar'])) {
      return 'registro_do_ocorrido';
    }
    if (_containsAny(normalized, const ['assedio', 'passou do limite'])) {
      return 'duvida_se_foi_assedio';
    }
    return 'relato_inicial';
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }
}
