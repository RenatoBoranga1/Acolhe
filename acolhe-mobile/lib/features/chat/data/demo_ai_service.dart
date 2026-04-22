import 'dart:convert';

import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:http/http.dart' as http;

class ChatReplyBundle {
  const ChatReplyBundle({
    required this.message,
    required this.risk,
    required this.ctas,
    required this.suggestions,
  });

  final ChatMessageModel message;
  final RiskAssessment risk;
  final List<String> ctas;
  final List<String> suggestions;
}

class DemoAiService {
  const DemoAiService();

  static const _openings = <String, List<String>>{
    'safety': [
      'Quero focar primeiro na sua seguranca.',
      'Antes de qualquer outra coisa, o mais importante agora e sua seguranca.',
      'Vamos priorizar o que pode te proteger neste momento.',
    ],
    'uncertainty': [
      'Da para entender por que isso te deixou em duvida.',
      'Faz sentido querer olhar para isso com mais cuidado.',
      'Entendo por que voce esta tentando nomear melhor o que aconteceu.',
    ],
    'record': [
      'Colocar isso em ordem pode ajudar a trazer mais clareza.',
      'Organizar os fatos com calma pode te dar um pouco mais de firmeza.',
      'Faz sentido querer deixar isso mais claro para voce mesma.',
    ],
    'support': [
      'Buscar uma pessoa de confianca pode ser um passo importante e ainda assim cuidadoso.',
      'Faz sentido pensar em quem pode te apoiar sem te pressionar.',
      'Voce nao precisa carregar isso sozinha se nao quiser.',
    ],
    'impact': [
      'Faz sentido isso ter mexido com voce.',
      'Isso parece ter sido bem desconfortavel de carregar.',
      'Nao deve ter sido facil lidar com isso por dentro.',
    ],
    'general': [
      'Podemos olhar para isso com calma.',
      'A gente pode ir por partes, no seu ritmo.',
      'Estou aqui para te ajudar a organizar isso sem pressa.',
    ],
  };

  static const _contextLines = <String, List<String>>{
    'safety': [
      'Se o receio e encontrar essa pessoa ou ficar mais exposta hoje, vale pensar primeiro nas proximas horas.',
      'Quando aparece medo de reencontro, faz sentido reduzir exposicao e aumentar apoio pratico.',
      'Se existe chance de contato agora, o foco pode ser te deixar menos vulneravel.',
    ],
    'uncertainty': [
      'Voce nao precisa fechar um rotulo agora para levar o que viveu a serio.',
      'Da para olhar para os fatos sem se cobrar uma conclusao imediata.',
      'A gente pode separar o que foi dito, feito e como isso te afetou antes de dar nome a tudo.',
    ],
    'record': [
      'Transformar isso em um registro claro pode ajudar sem te empurrar para nenhuma decisao.',
      'Da para organizar data, lugar, pessoas envolvidas e impactos no seu ritmo.',
      'Um resumo neutro pode ser util tanto para voce quanto para qualquer passo futuro.',
    ],
    'support': [
      'Pedir apoio pode comecar por uma frase simples, sem entrar em todos os detalhes.',
      'Voce pode escolher quanto quer contar e para quem quer contar.',
      'Apoio nao precisa significar expor tudo de uma vez.',
    ],
    'impact': [
      'Quando algo atravessa desse jeito, e comum ficar revivendo a cena ou se sentindo sem eixo.',
      'O que voce esta sentindo nao precisa ser minimizado para que a gente cuide disso com seriedade.',
      'Reacoes como confusao, vergonha ou alerta constante podem aparecer depois de situacoes assim.',
    ],
    'general': [
      'Nao precisa contar tudo de uma vez para que isso seja levado com seriedade.',
      'A gente pode focar no pedaco que fizer mais sentido agora.',
      'Voce pode escolher entre organizar os fatos, pensar em seguranca ou ensaiar um pedido de apoio.',
    ],
  };

  static const _supportLines = <String, List<String>>{
    'safety': [
      'Se quiser, eu posso te ajudar a montar um plano curto para hoje, pensar em um local seguro ou definir com quem falar primeiro.',
      'Podemos fazer um passo a passo bem pratico para agora, com foco em te deixar mais protegida.',
      'Se fizer sentido, eu te ajudo a escolher uma acao pequena e concreta para este momento.',
    ],
    'uncertainty': [
      'Se quiser, eu posso te ajudar a entender melhor a situacao ou organizar os fatos com calma.',
      'A gente pode olhar para o que aconteceu por etapas, sem te pressionar a concluir nada ja.',
      'Posso te ajudar a separar sinais importantes e pensar em proximos passos possiveis.',
    ],
    'record': [
      'Se fizer sentido, eu posso te ajudar a transformar isso em um rascunho pessoal claro e neutro.',
      'A gente pode montar um registro simples com data, local, pessoas e o que aconteceu.',
      'Posso te acompanhar na organizacao dos fatos de um jeito objetivo e sem pressa.',
    ],
    'support': [
      'Se quiser, eu posso te ajudar a escrever uma mensagem curta para alguem de confianca.',
      'Podemos pensar juntas em quem pode oferecer apoio mais seguro neste momento.',
      'Se fizer sentido, eu te ajudo a ensaiar o que dizer sem precisar explicar tudo.',
    ],
    'impact': [
      'Se quiser, eu posso te ajudar a organizar o que aconteceu ou pensar no que te ajudaria a se sentir um pouco mais firme agora.',
      'Podemos seguir com cuidado e escolher um proximo passo que nao te sobrecarregue.',
      'Se fizer sentido, a gente pode olhar para o que aconteceu e para o que voce precisa neste momento.',
    ],
    'general': [
      'Se quiser, eu posso te ajudar a organizar o que aconteceu ou pensar em proximos passos com calma.',
      'A gente pode seguir por um caminho mais pratico ou mais descritivo, dependendo do que voce precisa agora.',
      'Posso oferecer acolhimento inicial e orientacao geral, sempre no seu ritmo.',
    ],
  };

  static const _questions = <String, List<String>>{
    'safety': [
      'Voce esta em um lugar seguro agora?',
      'Tem alguem de confianca que possa ficar mais perto de voce hoje?',
      'O risco maior e nas proximas horas ou em algum horario especifico?',
    ],
    'uncertainty': [
      'Se fizer sentido, o que te deixou mais em duvida nessa situacao?',
      'Voce prefere olhar primeiro para o que aconteceu ou para como isso te afetou?',
      'Quer me contar o que aconteceu do jeito que ficar mais confortavel?',
    ],
    'record': [
      'Quer comecar pela data aproximada, pelo local ou pelo que foi dito ou feito?',
      'Voce prefere montar uma linha do tempo ou anotar os pontos principais primeiro?',
      'Qual parte seria mais facil de registrar agora?',
    ],
    'support': [
      'Quer que eu te ajude a montar uma mensagem curta para alguem de confianca?',
      'Ja existe alguem com quem voce se sentiria mais segura para falar?',
      'Voce prefere pensar em uma pessoa especifica ou no texto da mensagem primeiro?',
    ],
    'impact': [
      'O que esta pesando mais agora: medo, confusao, vergonha ou outra coisa?',
      'Voce quer organizar o que aconteceu ou pensar no que te ajudaria hoje?',
      'Tem alguma parte especifica disso que esta mais dificil de carregar agora?',
    ],
    'general': [
      'Voce prefere organizar os fatos ou pensar em proximos passos agora?',
      'Quer me contar um pouco mais, so ate onde for confortavel?',
      'Qual seria a ajuda mais util para voce neste momento?',
    ],
  };

  static const _signalPatterns = <String, List<String>>{
    'safety': [
      'medo',
      'ameaca',
      'risco',
      'seguranca',
      'local seguro',
      'encontrar essa pessoa',
      'hoje',
      'agora',
      'persegu',
      'coag',
      'forcou',
    ],
    'uncertainty': [
      'nao sei se foi',
      'foi assedio',
      'passou do limite',
      'nao sei por onde comecar',
      'duvida',
    ],
    'record': [
      'registr',
      'resumo',
      'organizar',
      'guardar provas',
      'evidenc',
      'anotar',
      'linha do tempo',
    ],
    'support': [
      'apoio',
      'pessoa de confianca',
      'alguem de confianca',
      'contar para',
      'falar com',
      'mensagem',
      'rede de apoio',
    ],
    'impact': [
      'vergonha',
      'culpa',
      'confusa',
      'travada',
      'abalada',
      'ansiosa',
      'nao consigo dormir',
      'chorei',
      'mal',
    ],
  };

  Future<ChatReplyBundle> sendMessage({
    required String text,
    required List<ChatMessageModel> history,
  }) async {
    if (AppEnvironment.useRemoteApi) {
      final response = await http.post(
        Uri.parse('${AppEnvironment.apiBaseUrl}/api/v1/chat/message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'history': _serializeHistory(history),
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatReplyBundle(
          message: ChatMessageModel.fromJson(
            Map<String, dynamic>.from(json['assistant_message'] as Map),
          ),
          risk: RiskAssessment.fromJson(
            Map<String, dynamic>.from(json['risk'] as Map),
          ),
          ctas: List<String>.from(json['ctas'] as List? ?? const []),
          suggestions: List<String>.from(json['suggestions'] as List? ?? const []),
        );
      }
    }

    final risk = assessRisk(text);
    final context = _buildContext(text, history, risk);
    final content = _composeFallbackReply(text, history, risk, context);
    return ChatReplyBundle(
      message: ChatMessageModel(
        id: generateId(),
        role: MessageRole.assistant,
        content: content,
        riskLevel: risk.level,
        createdAt: DateTime.now(),
      ),
      risk: risk,
      ctas: risk.level.index >= RiskLevel.high.index || context.primarySignal == 'safety'
          ? const [
              'Ligar para emergencia',
              'Contatar pessoa de confianca',
              'Abrir plano de seguranca',
              'Ver servicos de apoio',
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
    );
  }

  RiskAssessment assessRisk(String text) {
    final normalized = _normalize(text);
    if (_containsAny(normalized, const [
      'quero morrer',
      'vou me matar',
      'tirar minha vida',
      'ele esta aqui',
      'na minha porta',
      'estou presa',
    ])) {
      return const RiskAssessment(
        level: RiskLevel.critical,
        score: 10,
        reasons: ['risco imediato'],
        actions: [
          'Buscar um local seguro imediatamente',
          'Acionar emergencia local',
          'Contatar uma pessoa de confianca agora',
        ],
        requiresImmediateAction: true,
      );
    }

    var score = 0;
    final reasons = <String>[];

    if (_containsAny(normalized, const [
      'estou com medo',
      'medo de encontrar',
      'me ameac',
      'chantagem',
    ])) {
      score += 3;
      reasons.add('ameaca atual ou medo imediato');
    }

    if (_containsAny(normalized, const [
      'me seguindo',
      'persegu',
      'coag',
      'forcou',
      'me bateu',
    ])) {
      score += 3;
      reasons.add('coacao, perseguicao ou violencia');
    }

    if (_containsAny(normalized, const [
      'assedio',
      'passou do limite',
      'registrar',
      'nao sei se foi',
    ])) {
      score += 1;
      reasons.add('situacao requer organizacao cuidadosa');
    }

    if (score >= 6) {
      return RiskAssessment(
        level: RiskLevel.high,
        score: score,
        reasons: reasons,
        actions: const [
          'Ir para um local seguro',
          'Acionar pessoa de confianca',
          'Abrir plano de seguranca',
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
          'Organizar fatos no seu ritmo',
          'Pensar em proximos passos seguros',
          'Buscar apoio humano se desejar',
        ],
        requiresImmediateAction: false,
      );
    }

    return const RiskAssessment(
      level: RiskLevel.low,
      score: 0,
      reasons: ['sem sinais imediatos de crise'],
      actions: [
        'Conversar no seu ritmo',
        'Registrar se isso for util',
        'Buscar apoio humano quando quiser',
      ],
      requiresImmediateAction: false,
    );
  }

  String _composeFallbackReply(
    String text,
    List<ChatMessageModel> history,
    RiskAssessment risk,
    _ChatContext context,
  ) {
    if (risk.level.index >= RiskLevel.high.index || context.primarySignal == 'safety') {
      final opening = _pickVariant(
        _openings['safety']!,
        seed: '$text|safety|opening',
        blocked: context.recentOpenings,
      );
      final detail = _pickVariant(
        const [
          'Se houver chance de contato, tente ir para um local seguro e acionar uma pessoa de confianca ou a emergencia local agora.',
          'Se voce estiver exposta ou em perigo imediato, procure um lugar mais seguro e busque ajuda humana neste momento.',
          'Se o risco for agora, vale reduzir contato, ir para um lugar seguro e chamar apoio imediatamente.',
        ],
        seed: '$text|safety|detail',
        blocked: context.recentAssistantMessages,
      );
      final question = _pickVariant(
        _questions['safety']!,
        seed: '$text|safety|question',
        blocked: context.recentAssistantMessages,
      );
      return '$opening $detail\n\n$question';
    }

    final opening = _pickVariant(
      _openings[context.primarySignal] ?? _openings['general']!,
      seed: '$text|opening|${history.length}',
      blocked: context.recentOpenings,
    );
    final contextLine = _pickVariant(
      _contextLines[context.primarySignal] ?? _contextLines['general']!,
      seed: '$text|context|${history.length}',
      blocked: context.recentAssistantMessages,
    );
    final supportLine = _pickVariant(
      _supportLines[context.primarySignal] ?? _supportLines['general']!,
      seed: '$text|support|${history.length}',
      blocked: context.recentAssistantMessages,
    );

    final parts = <String>[
      opening,
      contextLine,
      supportLine,
    ];

    if (context.shouldOfferScopeNote) {
      parts.add(
        _pickVariant(
          const [
            'Eu posso oferecer acolhimento inicial e orientacao geral, sem substituir apoio psicologico, juridico, medico ou policial.',
            'Posso te acompanhar com acolhimento inicial e orientacao geral, mas nao substituo ajuda profissional.',
          ],
          seed: '$text|scope|${history.length}',
          blocked: context.recentAssistantMessages,
        ),
      );
    }

    final body = _limitSentences(_dedupeParts(parts).join(' '), 4);
    if (!context.shouldAskQuestion) {
      return body;
    }

    final question = _pickVariant(
      _questions[context.primarySignal] ?? _questions['general']!,
      seed: '$text|question|${history.length}',
      blocked: context.recentAssistantMessages,
    );
    return '$body\n\n$question';
  }

  _ChatContext _buildContext(
    String text,
    List<ChatMessageModel> history,
    RiskAssessment risk,
  ) {
    final recentMessages = [...history];
    final recentUserMessages = recentMessages
        .where((item) => item.role == MessageRole.user)
        .map((item) => item.content)
        .toList();
    final recentAssistantMessages = recentMessages
        .where((item) => item.role == MessageRole.assistant)
        .map((item) => item.content)
        .toList();

    final combined = _normalize(
      [
        ...recentUserMessages.skip(recentUserMessages.length > 4 ? recentUserMessages.length - 4 : 0),
        text,
      ].join(' '),
    );
    final latest = _normalize(text);
    final scores = <String, int>{};

    _signalPatterns.forEach((signal, patterns) {
      var score = 0;
      for (final pattern in patterns) {
        if (latest.contains(pattern)) {
          score += 2;
        }
        if (combined.contains(pattern)) {
          score += 1;
        }
      }
      if (signal == 'safety' && risk.level.index >= RiskLevel.high.index) {
        score += 5;
      }
      if (signal == 'safety' && latest.contains('medo')) {
        score += 2;
      }
      if (score > 0) {
        scores[signal] = score;
      }
    });

    final orderedSignals = scores.keys.toList()
      ..sort((a, b) {
        final scoreCompare = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.compareTo(b);
      });

    return _ChatContext(
      primarySignal: orderedSignals.isEmpty ? 'general' : orderedSignals.first,
      recentAssistantMessages: recentAssistantMessages.reversed.take(3).toList().reversed.toList(),
      recentOpenings: recentAssistantMessages
          .reversed
          .take(3)
          .map(_firstSentence)
          .where((item) => item.isNotEmpty)
          .toList()
          .reversed
          .toList(),
      shouldOfferScopeNote: recentAssistantMessages.isEmpty,
      shouldAskQuestion: risk.level.index <= RiskLevel.moderate.index && text.split(' ').length <= 80,
    );
  }

  List<Map<String, String>> _serializeHistory(List<ChatMessageModel> history) {
    final recent = history.length > 12 ? history.sublist(history.length - 12) : history;
    return recent
        .map((item) => {
              'role': item.role.name,
              'content': item.content,
            })
        .toList(growable: false);
  }

  String _pickVariant(
    List<String> options, {
    required String seed,
    required Iterable<String> blocked,
  }) {
    final ordered = [...options]
      ..sort((left, right) => _stableRank('$seed|$left').compareTo(_stableRank('$seed|$right')));
    final normalizedBlocked = blocked.map(_normalize).toList(growable: false);

    for (final option in ordered) {
      final normalized = _normalize(option);
      final isBlocked = normalizedBlocked.any((item) => _isSimilar(normalized, item));
      if (!isBlocked) {
        return option;
      }
    }
    return ordered.first;
  }

  List<String> _dedupeParts(List<String> parts) {
    final unique = <String>[];
    for (final part in parts) {
      if (part.trim().isEmpty) {
        continue;
      }
      final normalized = _normalize(part);
      final exists = unique.any((item) => _isSimilar(normalized, _normalize(item)));
      if (!exists) {
        unique.add(part.trim());
      }
    }
    return unique;
  }

  String _limitSentences(String text, int maxSentences) {
    final paragraphs = text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final kept = <String>[];
    var remaining = maxSentences;

    for (final paragraph in paragraphs) {
      if (remaining <= 0) {
        break;
      }
      final sentences = _splitSentences(paragraph);
      if (sentences.isEmpty) {
        continue;
      }
      final used = sentences.take(remaining).length;
      final chunk = sentences.take(remaining).join(' ');
      kept.add(chunk.trim());
      remaining -= used;
    }

    return kept.isEmpty ? text.trim() : kept.join('\n\n').trim();
  }

  List<String> _splitSentences(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return const [];
    }
    return compact
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _firstSentence(String text) {
    final sentences = _splitSentences(text);
    return sentences.isEmpty ? text.trim() : sentences.first;
  }

  int _stableRank(String value) {
    var total = 17;
    for (final codeUnit in value.codeUnits) {
      total = (total * 31 + codeUnit) & 0x7fffffff;
    }
    return total;
  }

  bool _isSimilar(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    if (left == right || left.contains(right) || right.contains(left)) {
      return true;
    }

    final leftTokens = left.split(' ').where((item) => item.length > 3).toSet();
    final rightTokens = right.split(' ').where((item) => item.length > 3).toSet();
    if (leftTokens.length < 3 || rightTokens.length < 3) {
      return false;
    }

    final overlap = leftTokens.intersection(rightTokens).length;
    final baseline = leftTokens.length < rightTokens.length ? leftTokens.length : rightTokens.length;
    return baseline > 0 && overlap / baseline >= 0.75;
  }

  String _normalize(String text) {
    final map = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    final lowered = text.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lowered.split('')) {
      buffer.write(map[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _containsAny(String text, List<String> patterns) =>
      patterns.any((pattern) => text.contains(pattern));
}

class _ChatContext {
  const _ChatContext({
    required this.primarySignal,
    required this.recentAssistantMessages,
    required this.recentOpenings,
    required this.shouldOfferScopeNote,
    required this.shouldAskQuestion,
  });

  final String primarySignal;
  final List<String> recentAssistantMessages;
  final List<String> recentOpenings;
  final bool shouldOfferScopeNote;
  final bool shouldAskQuestion;
}
