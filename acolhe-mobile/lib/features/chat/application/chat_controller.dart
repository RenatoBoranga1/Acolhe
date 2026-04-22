import 'dart:async';

import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/data/demo_ai_service.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingResponseContext {
  const PendingResponseContext({
    required this.conversationId,
    required this.prompt,
    required this.userMessageId,
  });

  final String conversationId;
  final String prompt;
  final String userMessageId;
}

class ChatState {
  const ChatState({
    required this.conversations,
    required this.activeConversationId,
    required this.isTyping,
    required this.latestRisk,
    required this.isHydrated,
    this.errorMessage,
    this.retryContext,
  });

  final List<ConversationModel> conversations;
  final String activeConversationId;
  final bool isTyping;
  final RiskAssessment latestRisk;
  final bool isHydrated;
  final String? errorMessage;
  final PendingResponseContext? retryContext;

  bool get hasRetryAvailable => retryContext != null;

  ConversationModel get activeConversation {
    return conversations.firstWhere(
      (item) => item.id == activeConversationId,
      orElse: () => conversations.first,
    );
  }

  ChatState copyWith({
    List<ConversationModel>? conversations,
    String? activeConversationId,
    bool? isTyping,
    RiskAssessment? latestRisk,
    bool? isHydrated,
    String? errorMessage,
    bool clearError = false,
    PendingResponseContext? retryContext,
    bool clearRetryContext = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isTyping: isTyping ?? this.isTyping,
      latestRisk: latestRisk ?? this.latestRisk,
      isHydrated: isHydrated ?? this.isHydrated,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      retryContext: clearRetryContext ? null : retryContext ?? this.retryContext,
    );
  }

  factory ChatState.initial() {
    final now = DateTime.now();
    final seedConversation = ConversationModel(
      id: generateId(),
      title: 'Primeira conversa',
      lastRiskLevel: RiskLevel.moderate,
      discreetMode: false,
      createdAt: now.subtract(const Duration(minutes: 8)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
      messages: [
        ChatMessageModel(
          id: generateId(),
          role: MessageRole.assistant,
          content:
              'Posso oferecer acolhimento inicial e orientacao geral. Nao substituo apoio psicologico, juridico, medico ou policial. Se houver risco imediato, procure emergencia local ou uma pessoa de confianca.',
          riskLevel: RiskLevel.low,
          createdAt: now.subtract(const Duration(minutes: 7)),
        ),
        ChatMessageModel(
          id: generateId(),
          role: MessageRole.user,
          content: 'Nao sei se o que aconteceu comigo foi assedio.',
          riskLevel: RiskLevel.moderate,
          createdAt: now.subtract(const Duration(minutes: 6)),
        ),
        ChatMessageModel(
          id: generateId(),
          role: MessageRole.assistant,
          content:
              'Posso te ajudar a olhar para isso com cuidado, sem julgamentos. Se quiser, tambem posso te ajudar a organizar os fatos ou pensar em proximos passos com seguranca.',
          riskLevel: RiskLevel.moderate,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    return ChatState(
      conversations: [seedConversation],
      activeConversationId: seedConversation.id,
      isTyping: false,
      latestRisk: const RiskAssessment(
        level: RiskLevel.moderate,
        score: 2,
        reasons: ['seed'],
        actions: ['Conversar com calma'],
        requiresImmediateAction: false,
      ),
      isHydrated: false,
    );
  }
}

final demoAiServiceProvider = Provider<DemoAiService>((ref) => const DemoAiService());

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.read(secureStorageProvider),
    ref.read(demoAiServiceProvider),
    ref,
  );
});

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._storage, this._service, this._ref) : super(ChatState.initial()) {
    unawaited(load());
  }

  final SecureStorageService _storage;
  final DemoAiService _service;
  final Ref _ref;

  Future<void> load() async {
    final storedSession = await _storage.readMap(StorageKeys.chatSession);
    if (storedSession != null &&
        storedSession['conversations'] is List &&
        (storedSession['conversations'] as List).isNotEmpty) {
      final conversations = (storedSession['conversations'] as List<dynamic>)
          .map((item) => ConversationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final sorted = _sortConversations(conversations);
      final activeId = _resolveActiveConversationId(
        sorted,
        storedSession['activeConversationId'] as String?,
      );
      final selected = sorted.firstWhere((item) => item.id == activeId);
      state = state.copyWith(
        conversations: sorted,
        activeConversationId: selected.id,
        latestRisk: _riskFromConversation(selected),
        isHydrated: true,
        clearError: true,
        clearRetryContext: true,
      );
      return;
    }

    final legacyConversations = await _storage.readList(StorageKeys.chatState);
    if (legacyConversations.isNotEmpty) {
      final parsed = legacyConversations
          .map((item) => ConversationModel.fromJson(item))
          .toList(growable: false);
      final sorted = _sortConversations(parsed);
      final first = sorted.first;
      state = state.copyWith(
        conversations: sorted,
        activeConversationId: first.id,
        latestRisk: _riskFromConversation(first),
        isHydrated: true,
        clearError: true,
        clearRetryContext: true,
      );
      await persist();
      return;
    }

    state = state.copyWith(isHydrated: true);
    await persist();
  }

  Future<void> persist() async {
    final encoded = encodeConversations(state.conversations);
    await _storage.writeMap(
      StorageKeys.chatSession,
      {
        'activeConversationId': state.activeConversationId,
        'conversations': encoded,
      },
    );
    await _storage.writeList(StorageKeys.chatState, encoded);
  }

  Future<void> switchConversation(String conversationId) async {
    final exists = state.conversations.any((item) => item.id == conversationId);
    if (!exists) {
      return;
    }
    final selected = state.conversations.firstWhere((item) => item.id == conversationId);
    state = state.copyWith(
      activeConversationId: conversationId,
      latestRisk: _riskFromConversation(selected),
      clearError: true,
    );
    await persist();
  }

  Future<void> newConversation() async {
    final conversation = _createBlankConversation();
    state = state.copyWith(
      conversations: _sortConversations([conversation, ...state.conversations]),
      activeConversationId: conversation.id,
      latestRisk: _riskFromConversation(conversation),
      clearError: true,
      clearRetryContext: true,
    );
    await persist();
  }

  Future<void> renameConversation(String conversationId, String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return;
    }
    final updated = state.conversations.map((conversation) {
      if (conversation.id != conversationId) {
        return conversation;
      }
      return conversation.copyWith(title: normalized, updatedAt: DateTime.now());
    }).toList(growable: false);
    state = state.copyWith(conversations: _sortConversations(updated));
    await persist();
  }

  Future<void> deleteConversation(String conversationId) async {
    final remaining = state.conversations
        .where((conversation) => conversation.id != conversationId)
        .toList(growable: false);

    if (remaining.isEmpty) {
      final fallback = _createBlankConversation();
      state = state.copyWith(
        conversations: [fallback],
        activeConversationId: fallback.id,
        latestRisk: _riskFromConversation(fallback),
        clearError: true,
        clearRetryContext: true,
      );
      await persist();
      return;
    }

    final sorted = _sortConversations(remaining);
    final activeId = state.activeConversationId == conversationId
        ? sorted.first.id
        : _resolveActiveConversationId(sorted, state.activeConversationId);
    final active = sorted.firstWhere((conversation) => conversation.id == activeId);
    state = state.copyWith(
      conversations: sorted,
      activeConversationId: activeId,
      latestRisk: _riskFromConversation(active),
      clearError: true,
      clearRetryContext: state.retryContext?.conversationId == conversationId,
    );
    await persist();
  }

  Future<void> clearCurrentConversation() async {
    final active = state.activeConversation;
    final resetConversation = active.copyWith(
      title: _defaultConversationTitle(active.discreetMode),
      lastRiskLevel: RiskLevel.low,
      messages: const [],
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(
      conversations: _replaceConversation(resetConversation),
      latestRisk: _riskFromConversation(resetConversation),
      clearError: true,
      clearRetryContext: true,
    );
    await persist();
  }

  Future<void> sendMessage(String text) async {
    if (state.isTyping) {
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final active = state.activeConversation;
    final now = DateTime.now();
    final userMessage = ChatMessageModel(
      id: generateId(),
      role: MessageRole.user,
      content: trimmed,
      riskLevel: RiskLevel.low,
      createdAt: now,
    );

    final currentMessages = [...active.messages, userMessage];
    final optimisticConversation = active.copyWith(
      title: _deriveConversationTitle(active, trimmed),
      messages: currentMessages,
      updatedAt: now,
    );

    state = state.copyWith(
      conversations: _replaceConversation(optimisticConversation),
      activeConversationId: optimisticConversation.id,
      isTyping: true,
      clearError: true,
      retryContext: PendingResponseContext(
        conversationId: optimisticConversation.id,
        prompt: trimmed,
        userMessageId: userMessage.id,
      ),
    );
    await persist();

    await _completeAssistantResponse(
      conversationId: optimisticConversation.id,
      prompt: trimmed,
      history: currentMessages,
    );
  }

  Future<void> retryLastResponse() async {
    if (state.isTyping || state.retryContext == null) {
      return;
    }

    final retryContext = state.retryContext!;
    final hasConversation = state.conversations.any(
      (item) => item.id == retryContext.conversationId,
    );
    if (!hasConversation) {
      state = state.copyWith(clearRetryContext: true, clearError: true);
      return;
    }
    final conversation = state.conversations.firstWhere(
      (item) => item.id == retryContext.conversationId,
    );

    state = state.copyWith(isTyping: true, clearError: true);
    await _completeAssistantResponse(
      conversationId: conversation.id,
      prompt: retryContext.prompt,
      history: conversation.messages,
    );
  }

  Future<void> _completeAssistantResponse({
    required String conversationId,
    required String prompt,
    required List<ChatMessageModel> history,
  }) async {
    try {
      final reply = await _service
          .sendMessage(text: prompt, history: history)
          .timeout(const Duration(seconds: 20));

      final hasConversation = state.conversations.any(
        (conversation) => conversation.id == conversationId,
      );
      if (!hasConversation) {
        state = state.copyWith(
          isTyping: false,
          clearRetryContext: true,
          clearError: true,
        );
        return;
      }
      final updatedConversation = state.conversations.firstWhere(
        (conversation) => conversation.id == conversationId,
      );
      final completed = updatedConversation.copyWith(
        lastRiskLevel: reply.risk.level,
        messages: [...updatedConversation.messages, reply.message],
        updatedAt: DateTime.now(),
      );

      final latestRisk = state.activeConversationId == conversationId
          ? reply.risk
          : state.latestRisk;

      state = state.copyWith(
        conversations: _replaceConversation(completed),
        isTyping: false,
        latestRisk: latestRisk,
        clearError: true,
        clearRetryContext: true,
      );
      await persist();
    } on TimeoutException {
      state = state.copyWith(
        isTyping: false,
        errorMessage:
            'A resposta demorou mais do que o esperado. Quando voce quiser, tente novamente.',
      );
    } catch (_) {
      state = state.copyWith(
        isTyping: false,
        errorMessage:
            'Nao consegui responder agora. Sua mensagem continua salva e voce pode tentar de novo.',
      );
    }
  }

  List<ConversationModel> _replaceConversation(ConversationModel updated) {
    if (!state.conversations.any((item) => item.id == updated.id)) {
      return _sortConversations([updated, ...state.conversations]);
    }
    final items = state.conversations
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    return _sortConversations(items);
  }

  List<ConversationModel> _sortConversations(List<ConversationModel> conversations) {
    final sorted = [...conversations];
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  String _resolveActiveConversationId(
    List<ConversationModel> conversations,
    String? requestedId,
  ) {
    if (requestedId != null &&
        conversations.any((conversation) => conversation.id == requestedId)) {
      return requestedId;
    }
    return conversations.first.id;
  }

  ConversationModel _createBlankConversation() {
    final discreetMode = _ref.read(authControllerProvider).discreetMode;
    final now = DateTime.now();
    return ConversationModel(
      id: generateId(),
      title: _defaultConversationTitle(discreetMode),
      lastRiskLevel: RiskLevel.low,
      discreetMode: discreetMode,
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  String _defaultConversationTitle(bool discreetMode) {
    return discreetMode ? 'Espaco privado' : 'Nova conversa';
  }

  String _deriveConversationTitle(ConversationModel conversation, String prompt) {
    if (!_isGenericConversationTitle(conversation.title) || conversation.messages.isNotEmpty) {
      return conversation.title;
    }

    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return conversation.title;
    }

    final strippedPunctuation = normalized.replaceAll(RegExp(r'[.!?]+$'), '');
    if (strippedPunctuation.length <= 42) {
      return strippedPunctuation;
    }
    return '${strippedPunctuation.substring(0, 39)}...';
  }

  bool _isGenericConversationTitle(String title) {
    final normalized = title.toLowerCase();
    return normalized == 'nova conversa' ||
        normalized == 'espaco privado' ||
        normalized == 'primeira conversa';
  }

  RiskAssessment _riskFromConversation(ConversationModel conversation) {
    return RiskAssessment(
      level: conversation.lastRiskLevel,
      score: conversation.lastRiskLevel.index,
      reasons: const ['estado atual da conversa'],
      actions: conversation.lastRiskLevel.index >= RiskLevel.high.index
          ? const [
              'Priorizar seguranca imediata',
              'Acionar apoio humano',
              'Usar o plano de seguranca',
            ]
          : const [
              'Conversar no seu ritmo',
              'Organizar fatos com calma',
              'Escolher proximos passos quando fizer sentido',
            ],
      requiresImmediateAction: conversation.lastRiskLevel.index >= RiskLevel.high.index,
    );
  }
}
