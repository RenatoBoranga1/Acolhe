import 'dart:collection';

import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/chat/data/chat_api_client.dart';
import 'package:acolhe_mobile/features/chat/data/chat_fallback_service.dart';
import 'package:acolhe_mobile/features/chat/data/chat_repository.dart';
import 'package:acolhe_mobile/features/chat/data/chat_result.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
      'chat controller prioritizes backend metadata when remote chat is enabled',
      () async {
    final seededConversation = ConversationModel(
      id: 'conv-1',
      title: 'Conversa remota',
      lastRiskLevel: RiskLevel.low,
      discreetMode: false,
      messages: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final repository = _FakeChatRepository(
      remoteEnabled: true,
      initialConversation: seededConversation,
      responses: [
        ChatSendResult(
          conversationId: seededConversation.id,
          assistantMessage: ChatMessageModel(
            id: 'assistant-1',
            role: MessageRole.assistant,
            content:
                'Sua seguranca vem primeiro. Vamos pensar em passos curtos.',
            riskLevel: RiskLevel.high,
            createdAt: DateTime(2026, 1, 1, 10, 1),
          ),
          risk: const RiskAssessment(
            level: RiskLevel.high,
            score: 8,
            reasons: ['ameaca atual'],
            actions: ['Ir para um local seguro'],
            requiresImmediateAction: true,
          ),
          ctas: const ['Ajuda urgente', 'Abrir plano de seguranca'],
          suggestions: const ['Quero falar com alguem de confianca'],
          responseMode: 'safety_first',
          situationType: 'fear_of_reencounter',
          conversationContext: const {'source': 'backend', 'goal': 'safety'},
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_MemorySecureStorage()),
        chatRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(chatControllerProvider.notifier);
    await controller.load();
    await controller
        .sendMessage('Estou com medo de encontrar essa pessoa hoje.');

    final state = container.read(chatControllerProvider);
    expect(state.syncStatus, ChatSyncStatus.synced);
    expect(state.lastAssistantMessage?.id, 'assistant-1');
    expect(state.latestRisk.level, RiskLevel.high);
    expect(state.latestCtas, contains('Ajuda urgente'));
    expect(state.quickSuggestions, ['Quero falar com alguem de confianca']);
    expect(state.responseMode, 'safety_first');
    expect(state.situationType, 'fear_of_reencounter');
    expect(state.conversationContext?['source'], 'backend');
    expect(repository.sentHistories, hasLength(1));
  });

  test('retry replaces a fallback assistant reply instead of duplicating it',
      () async {
    final seededConversation = ConversationModel(
      id: 'conv-2',
      title: 'Conversa com fallback',
      lastRiskLevel: RiskLevel.low,
      discreetMode: false,
      messages: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final fallbackReply = ChatSendResult(
      conversationId: seededConversation.id,
      assistantMessage: ChatMessageModel(
        id: 'fallback-1',
        role: MessageRole.assistant,
        content: 'Mantive uma resposta local segura enquanto a conexao falhou.',
        riskLevel: RiskLevel.moderate,
        createdAt: DateTime(2026, 1, 1, 10, 2),
      ),
      risk: const RiskAssessment(
        level: RiskLevel.moderate,
        score: 4,
        reasons: ['instabilidade de rede'],
        actions: ['Tentar novamente quando fizer sentido'],
        requiresImmediateAction: false,
      ),
      ctas: const ['Registrar o que aconteceu'],
      suggestions: const ['Quero tentar novamente'],
      responseMode: 'local_safe_fallback',
      situationType: 'initial_disclosure',
      conversationContext: const {'source': 'mobile_local_fallback'},
      servedFromFallback: true,
      canRetryRemote: true,
      fallbackReason: 'timeout',
    );
    final remoteReply = ChatSendResult(
      conversationId: seededConversation.id,
      assistantMessage: ChatMessageModel(
        id: 'assistant-remote',
        role: MessageRole.assistant,
        content:
            'Entendo por que isso pode ter te afetado. Podemos organizar os fatos com calma.',
        riskLevel: RiskLevel.moderate,
        createdAt: DateTime(2026, 1, 1, 10, 3),
      ),
      risk: const RiskAssessment(
        level: RiskLevel.moderate,
        score: 3,
        reasons: ['relato sensivel'],
        actions: ['Organizar fatos'],
        requiresImmediateAction: false,
      ),
      ctas: const ['Registrar o que aconteceu'],
      suggestions: const ['Quero seguir por partes'],
      responseMode: 'structured_guidance',
      situationType: 'incident_record',
      conversationContext: const {'source': 'backend'},
    );
    final repository = _FakeChatRepository(
      remoteEnabled: true,
      initialConversation: seededConversation,
      responses: [fallbackReply, remoteReply],
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_MemorySecureStorage()),
        chatRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(chatControllerProvider.notifier);
    await controller.load();
    await controller.sendMessage('Preciso de ajuda para entender o que fazer.');

    var state = container.read(chatControllerProvider);
    expect(state.lastResponseUsedFallback, isTrue);
    expect(state.hasRetryAvailable, isTrue);
    expect(state.errorMessage, contains('demorou para responder'));

    await controller.retryLastResponse();

    state = container.read(chatControllerProvider);
    final messages = state.activeConversation.messages;
    expect(repository.sentHistories, hasLength(2));
    expect(repository.sentHistories.last, hasLength(1));
    expect(repository.sentHistories.last.single.role, MessageRole.user);
    expect(messages.where((item) => item.id == 'fallback-1'), isEmpty);
    expect(
        messages.where((item) => item.id == 'assistant-remote'), hasLength(1));
    expect(state.lastResponseUsedFallback, isFalse);
    expect(state.hasRetryAvailable, isFalse);
    expect(state.responseMode, 'structured_guidance');
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({
    required this.remoteEnabled,
    required ConversationModel initialConversation,
    required Iterable<ChatSendResult> responses,
  })  : _initialConversation = initialConversation,
        _responses = Queue<ChatSendResult>.from(responses),
        super(
          apiClient: ChatApiClient(http.Client(), apiBaseUrl: ''),
          fallbackService: const ChatFallbackService(),
        );

  final bool remoteEnabled;
  ConversationModel _initialConversation;
  final Queue<ChatSendResult> _responses;
  final List<List<ChatMessageModel>> sentHistories = [];

  @override
  bool get isRemoteEnabled => remoteEnabled;

  @override
  Future<List<ConversationModel>> listConversations() async {
    return [_initialConversation];
  }

  @override
  Future<ConversationModel> createConversation({
    required String title,
    required bool discreetMode,
  }) async {
    _initialConversation = _initialConversation.copyWith(
      title: title,
      discreetMode: discreetMode,
    );
    return _initialConversation;
  }

  @override
  Future<ConversationModel> getConversation(String conversationId) async {
    return _initialConversation;
  }

  @override
  Future<ConversationModel> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    _initialConversation = _initialConversation.copyWith(title: title);
    return _initialConversation;
  }

  @override
  Future<void> deleteConversation(String conversationId) async {}

  @override
  Future<ConversationMessagesPage> listMessages({
    required String conversationId,
    int page = 1,
    int pageSize = 40,
  }) async {
    return ConversationMessagesPage(
      conversationId: conversationId,
      page: page,
      pageSize: pageSize,
      total: _initialConversation.messages.length,
      hasMore: false,
      items: _initialConversation.messages,
    );
  }

  @override
  Future<ChatSendResult> sendMessage({
    required String? conversationId,
    required String message,
    required bool discreetMode,
    required List<ChatMessageModel> history,
  }) async {
    sentHistories.add(List<ChatMessageModel>.from(history));
    if (_responses.isEmpty) {
      throw StateError('No fake response queued for sendMessage.');
    }
    return _responses.removeFirst();
  }
}

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage();

  final Map<String, String> _strings = {};
  final Map<String, Map<String, dynamic>> _maps = {};
  final Map<String, List<Map<String, dynamic>>> _lists = {};

  @override
  Future<String?> readString(String key) async => _strings[key];

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => _maps[key];

  @override
  Future<List<Map<String, dynamic>>> readList(String key) async =>
      _lists[key] ?? [];

  @override
  Future<void> writeString(String key, String value) async {
    _strings[key] = value;
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    _maps[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> value) async {
    _lists[key] = value
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  Future<void> delete(String key) async {
    _strings.remove(key);
    _maps.remove(key);
    _lists.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _strings.clear();
    _maps.clear();
    _lists.clear();
  }
}
