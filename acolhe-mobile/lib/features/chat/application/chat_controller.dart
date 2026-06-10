import 'dart:async';

import 'package:acolhe_mobile/core/config/backend_config.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/data/chat_repository.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatSyncStatus { localOnly, syncing, synced, offline }

extension ChatSyncStatusX on ChatSyncStatus {
  String get label => switch (this) {
        ChatSyncStatus.localOnly => 'Modo offline seguro ativado',
        ChatSyncStatus.syncing => 'Reconectando ao servico inteligente...',
        ChatSyncStatus.synced => 'Conectado',
        ChatSyncStatus.offline => 'Modo offline seguro ativado',
      };
}

class PendingResponseContext {
  const PendingResponseContext({
    required this.conversationId,
    required this.prompt,
    required this.userMessageId,
    this.assistantMessageIdToReplace,
  });

  final String conversationId;
  final String prompt;
  final String userMessageId;
  final String? assistantMessageIdToReplace;
}

class ChatState {
  const ChatState({
    required this.conversations,
    required this.activeConversationId,
    required this.isTyping,
    required this.isLoadingHistory,
    required this.latestRisk,
    required this.isHydrated,
    required this.syncStatus,
    required this.latestCtas,
    required this.quickSuggestions,
    required this.lastResponseUsedFallback,
    required this.lastResponseWasRepaired,
    required this.loadedMessagePages,
    required this.hasMoreMessagesByConversation,
    this.lastAssistantMessage,
    this.errorMessage,
    this.retryContext,
    this.responseMode,
    this.situationType,
    this.conversationContext,
    this.lastSyncedAt,
  });

  final List<ConversationModel> conversations;
  final String activeConversationId;
  final bool isTyping;
  final bool isLoadingHistory;
  final RiskAssessment latestRisk;
  final bool isHydrated;
  final ChatSyncStatus syncStatus;
  final List<String> latestCtas;
  final List<String> quickSuggestions;
  final bool lastResponseUsedFallback;
  final bool lastResponseWasRepaired;
  final Map<String, int> loadedMessagePages;
  final Map<String, bool> hasMoreMessagesByConversation;
  final ChatMessageModel? lastAssistantMessage;
  final String? errorMessage;
  final PendingResponseContext? retryContext;
  final String? responseMode;
  final String? situationType;
  final Map<String, dynamic>? conversationContext;
  final DateTime? lastSyncedAt;

  bool get hasRetryAvailable => retryContext != null;
  bool get hasMoreMessages =>
      hasMoreMessagesByConversation[activeConversationId] ?? false;

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
    bool? isLoadingHistory,
    RiskAssessment? latestRisk,
    bool? isHydrated,
    ChatSyncStatus? syncStatus,
    List<String>? latestCtas,
    List<String>? quickSuggestions,
    bool? lastResponseUsedFallback,
    bool? lastResponseWasRepaired,
    Map<String, int>? loadedMessagePages,
    Map<String, bool>? hasMoreMessagesByConversation,
    ChatMessageModel? lastAssistantMessage,
    String? errorMessage,
    bool clearError = false,
    PendingResponseContext? retryContext,
    bool clearRetryContext = false,
    String? responseMode,
    String? situationType,
    Map<String, dynamic>? conversationContext,
    DateTime? lastSyncedAt,
    bool clearResponseMetadata = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isTyping: isTyping ?? this.isTyping,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      latestRisk: latestRisk ?? this.latestRisk,
      isHydrated: isHydrated ?? this.isHydrated,
      syncStatus: syncStatus ?? this.syncStatus,
      latestCtas: latestCtas ?? this.latestCtas,
      quickSuggestions: quickSuggestions ?? this.quickSuggestions,
      lastResponseUsedFallback: clearResponseMetadata
          ? false
          : lastResponseUsedFallback ?? this.lastResponseUsedFallback,
      lastResponseWasRepaired: clearResponseMetadata
          ? false
          : lastResponseWasRepaired ?? this.lastResponseWasRepaired,
      loadedMessagePages: loadedMessagePages ?? this.loadedMessagePages,
      hasMoreMessagesByConversation:
          hasMoreMessagesByConversation ?? this.hasMoreMessagesByConversation,
      lastAssistantMessage: clearResponseMetadata
          ? null
          : lastAssistantMessage ?? this.lastAssistantMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      retryContext:
          clearRetryContext ? null : retryContext ?? this.retryContext,
      responseMode:
          clearResponseMetadata ? null : responseMode ?? this.responseMode,
      situationType:
          clearResponseMetadata ? null : situationType ?? this.situationType,
      conversationContext: clearResponseMetadata
          ? null
          : conversationContext ?? this.conversationContext,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
      isLoadingHistory: false,
      latestRisk: const RiskAssessment(
        level: RiskLevel.moderate,
        score: 2,
        reasons: ['seed'],
        actions: ['Conversar com calma'],
        requiresImmediateAction: false,
      ),
      isHydrated: false,
      syncStatus: ChatSyncStatus.localOnly,
      latestCtas: const [],
      quickSuggestions: defaultChatSuggestions,
      lastResponseUsedFallback: false,
      lastResponseWasRepaired: false,
      loadedMessagePages: {seedConversation.id: 1},
      hasMoreMessagesByConversation: {seedConversation.id: false},
      lastAssistantMessage: null,
    );
  }

  static const defaultChatSuggestions = [
    'Nao sei por onde comecar',
    'Quero entender se isso foi assedio',
    'Estou com medo',
    'Quero registrar o que aconteceu',
    'Quero pensar nos proximos passos',
    'Quero ajuda para falar com alguem de confianca',
  ];
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.read(secureStorageProvider),
    ref.watch(chatRepositoryProvider),
    ref,
  );
});

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._storage, this._repository, this._ref)
      : super(ChatState.initial()) {
    unawaited(load());
  }

  static const int _historyPageSize = 40;

  final SecureStorageService _storage;
  final ChatRepository _repository;
  final Ref _ref;

  Future<void> load() async {
    final cached = await _readCachedSession();
    if (cached != null) {
      final selected = cached.conversations.firstWhere(
        (item) => item.id == cached.activeConversationId,
      );
      state = state.copyWith(
        conversations: cached.conversations,
        activeConversationId: selected.id,
        loadedMessagePages: {
          for (final conversation in cached.conversations)
            conversation.id: conversation.messages.isEmpty ? 0 : 1,
        },
        hasMoreMessagesByConversation: {
          for (final conversation in cached.conversations)
            conversation.id: false,
        },
        latestRisk: _riskFromConversation(selected),
        isHydrated: true,
        syncStatus: _repository.isRemoteEnabled
            ? ChatSyncStatus.syncing
            : _localSafeSyncStatus(),
        clearError: true,
        clearRetryContext: true,
      );
    }

    if (_repository.isRemoteEnabled) {
      await _loadRemoteConversations(cached);
      return;
    }

    if (cached != null) {
      return;
    }

    state = state.copyWith(
      isHydrated: true,
      syncStatus: _localSafeSyncStatus(),
    );
    await persist();
  }

  Future<void> _loadRemoteConversations(_CachedChatSession? cached) async {
    try {
      var remoteConversations = await _repository.listConversations();
      if (remoteConversations.isEmpty) {
        final discreetMode = _ref.read(authControllerProvider).discreetMode;
        final created = await _repository.createConversation(
          title: _defaultConversationTitle(discreetMode),
          discreetMode: discreetMode,
        );
        remoteConversations = [created];
      }
      final merged = cached == null
          ? remoteConversations
          : _mergeConversations(
              localConversations: cached.conversations,
              remoteConversations: remoteConversations,
            );
      final sorted = _sortConversations(merged);
      final activeId = _resolveActiveConversationId(
        sorted,
        state.activeConversationId,
      );
      final selected = sorted.firstWhere((item) => item.id == activeId);
      state = state.copyWith(
        conversations: sorted,
        activeConversationId: selected.id,
        loadedMessagePages: {
          for (final conversation in sorted)
            conversation.id: conversation.messages.isEmpty ? 0 : 1,
        },
        hasMoreMessagesByConversation: {
          for (final conversation in sorted) conversation.id: false,
        },
        latestRisk: _riskFromConversation(selected),
        isHydrated: true,
        syncStatus: ChatSyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        clearError: true,
        clearRetryContext: true,
      );
      await _hydrateConversationFromBackend(
        selected.id,
        showSyncState: false,
      );
      await persist();
      return;
    } catch (_) {
      state = state.copyWith(
        isHydrated: true,
        syncStatus: ChatSyncStatus.offline,
        errorMessage: cached == null
            ? 'Nao consegui conectar ao backend agora. O chat continua disponivel em modo local seguro.'
            : 'Nao consegui atualizar pelo backend agora. Mostrando o cache local deste aparelho.',
      );
    }
  }

  Future<_CachedChatSession?> _readCachedSession() async {
    final storedSession = await _storage.readMap(StorageKeys.chatSession);
    if (storedSession != null &&
        storedSession['conversations'] is List &&
        (storedSession['conversations'] as List).isNotEmpty) {
      final conversations = (storedSession['conversations'] as List<dynamic>)
          .map((item) => ConversationModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
      final sorted = _sortConversations(conversations);
      final activeId = _resolveActiveConversationId(
        sorted,
        storedSession['activeConversationId'] as String?,
      );
      return _CachedChatSession(
          conversations: sorted, activeConversationId: activeId);
    }

    final legacyConversations = await _storage.readList(StorageKeys.chatState);
    if (legacyConversations.isEmpty) {
      return null;
    }
    final parsed = legacyConversations
        .map((item) => ConversationModel.fromJson(item))
        .toList(growable: false);
    final sorted = _sortConversations(parsed);
    return _CachedChatSession(
        conversations: sorted, activeConversationId: sorted.first.id);
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
    final selected =
        state.conversations.firstWhere((item) => item.id == conversationId);
    state = state.copyWith(
      activeConversationId: conversationId,
      latestRisk: _riskFromConversation(selected),
      latestCtas: const [],
      clearError: true,
      clearResponseMetadata: true,
    );
    await persist();
    if (_repository.isRemoteEnabled) {
      await _hydrateConversationFromBackend(conversationId);
    }
  }

  Future<void> newConversation() async {
    final discreetMode = _ref.read(authControllerProvider).discreetMode;
    var syncStatus = state.syncStatus;
    String? errorMessage;
    var conversation = _createBlankConversation();

    if (_repository.isRemoteEnabled) {
      try {
        conversation = await _repository.createConversation(
          title: _defaultConversationTitle(discreetMode),
          discreetMode: discreetMode,
        );
        syncStatus = ChatSyncStatus.synced;
      } catch (_) {
        syncStatus = ChatSyncStatus.offline;
        errorMessage =
            'Nao consegui criar a conversa no backend agora. Criei uma conversa local segura.';
      }
    }

    state = state.copyWith(
      conversations: _sortConversations([conversation, ...state.conversations]),
      activeConversationId: conversation.id,
      loadedMessagePages: {
        ...state.loadedMessagePages,
        conversation.id: conversation.messages.isEmpty ? 0 : 1,
      },
      hasMoreMessagesByConversation: {
        ...state.hasMoreMessagesByConversation,
        conversation.id: false,
      },
      latestRisk: _riskFromConversation(conversation),
      syncStatus: syncStatus,
      lastSyncedAt: syncStatus == ChatSyncStatus.synced ? DateTime.now() : null,
      errorMessage: errorMessage,
      clearError: true,
      clearRetryContext: true,
      clearResponseMetadata: true,
    );
    if (errorMessage != null) {
      state = state.copyWith(errorMessage: errorMessage);
    }
    await persist();
  }

  Future<void> renameConversation(String conversationId, String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_repository.isRemoteEnabled) {
      try {
        final remoteConversation = await _repository.renameConversation(
          conversationId: conversationId,
          title: normalized,
        );
        final updated = state.conversations.map((conversation) {
          if (conversation.id != conversationId) {
            return conversation;
          }
          return conversation.copyWith(
            title: remoteConversation.title,
            discreetMode: remoteConversation.discreetMode,
            lastRiskLevel: remoteConversation.lastRiskLevel,
            updatedAt: remoteConversation.updatedAt,
          );
        }).toList(growable: false);
        state = state.copyWith(
          conversations: _sortConversations(updated),
          syncStatus: ChatSyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          clearError: true,
        );
        await persist();
        return;
      } catch (_) {
        state = state.copyWith(
          errorMessage:
              'Nao consegui renomear a conversa no backend agora. Tente novamente quando fizer sentido.',
          syncStatus: ChatSyncStatus.offline,
        );
        return;
      }
    }

    final updated = state.conversations.map((conversation) {
      if (conversation.id != conversationId) {
        return conversation;
      }
      return conversation.copyWith(
          title: normalized, updatedAt: DateTime.now());
    }).toList(growable: false);
    state = state.copyWith(conversations: _sortConversations(updated));
    await persist();
  }

  Future<void> deleteConversation(String conversationId) async {
    if (_repository.isRemoteEnabled) {
      try {
        await _repository.deleteConversation(conversationId);
      } catch (_) {
        state = state.copyWith(
          errorMessage:
              'Nao consegui excluir a conversa no backend agora. Tente novamente para evitar inconsistencias.',
          syncStatus: ChatSyncStatus.offline,
        );
        return;
      }
    }

    final remaining = state.conversations
        .where((conversation) => conversation.id != conversationId)
        .toList(growable: false);
    final updatedLoadedPages = Map<String, int>.from(state.loadedMessagePages)
      ..remove(conversationId);
    final updatedHasMore =
        Map<String, bool>.from(state.hasMoreMessagesByConversation)
          ..remove(conversationId);

    if (remaining.isEmpty) {
      final discreetMode = _ref.read(authControllerProvider).discreetMode;
      var fallback = _createBlankConversation();
      var syncStatus = _repository.isRemoteEnabled
          ? ChatSyncStatus.offline
          : _localSafeSyncStatus();
      String? errorMessage;
      if (_repository.isRemoteEnabled) {
        try {
          fallback = await _repository.createConversation(
            title: _defaultConversationTitle(discreetMode),
            discreetMode: discreetMode,
          );
          syncStatus = ChatSyncStatus.synced;
        } catch (_) {
          errorMessage =
              'A conversa foi removida, mas nao consegui criar uma nova no backend agora.';
        }
      }
      state = state.copyWith(
        conversations: [fallback],
        activeConversationId: fallback.id,
        loadedMessagePages: {fallback.id: fallback.messages.isEmpty ? 0 : 1},
        hasMoreMessagesByConversation: {fallback.id: false},
        latestRisk: _riskFromConversation(fallback),
        latestCtas: const [],
        syncStatus: syncStatus,
        lastSyncedAt:
            syncStatus == ChatSyncStatus.synced ? DateTime.now() : null,
        errorMessage: errorMessage,
        clearError: true,
        clearRetryContext: true,
        clearResponseMetadata: true,
      );
      if (errorMessage != null) {
        state = state.copyWith(errorMessage: errorMessage);
      }
      await persist();
      return;
    }

    final sorted = _sortConversations(remaining);
    final activeId = state.activeConversationId == conversationId
        ? sorted.first.id
        : _resolveActiveConversationId(sorted, state.activeConversationId);
    final active =
        sorted.firstWhere((conversation) => conversation.id == activeId);
    state = state.copyWith(
      conversations: sorted,
      activeConversationId: activeId,
      loadedMessagePages: updatedLoadedPages,
      hasMoreMessagesByConversation: updatedHasMore,
      latestRisk: _riskFromConversation(active),
      latestCtas: const [],
      clearError: true,
      clearRetryContext: state.retryContext?.conversationId == conversationId,
      clearResponseMetadata: true,
    );
    await persist();
    if (_repository.isRemoteEnabled &&
        state.activeConversation.messages.isNotEmpty) {
      await _hydrateConversationFromBackend(state.activeConversationId);
    }
  }

  Future<void> loadOlderMessages() async {
    if (!_repository.isRemoteEnabled ||
        state.isLoadingHistory ||
        !state.hasMoreMessages) {
      return;
    }

    final active = state.activeConversation;
    final nextPage = (state.loadedMessagePages[active.id] ?? 1) + 1;
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final page = await _repository.listMessages(
        conversationId: active.id,
        page: nextPage,
        pageSize: _historyPageSize,
      );
      final knownIds = active.messages.map((item) => item.id).toSet();
      final olderItems = page.items
          .where((item) => !knownIds.contains(item.id))
          .toList(growable: false);
      final updatedConversation = active.copyWith(
        messages: [...olderItems, ...active.messages],
        updatedAt: active.updatedAt,
      );
      state = state.copyWith(
        conversations: _replaceConversation(updatedConversation),
        isLoadingHistory: false,
        loadedMessagePages: {
          ...state.loadedMessagePages,
          active.id: page.page,
        },
        hasMoreMessagesByConversation: {
          ...state.hasMoreMessagesByConversation,
          active.id: page.hasMore,
        },
        syncStatus: ChatSyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
      await persist();
    } catch (_) {
      state = state.copyWith(
        isLoadingHistory: false,
        syncStatus: ChatSyncStatus.offline,
        errorMessage:
            'Nao consegui carregar mensagens anteriores agora. O historico local continua disponivel.',
      );
    }
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
      loadedMessagePages: {
        ...state.loadedMessagePages,
        active.id: 0,
      },
      hasMoreMessagesByConversation: {
        ...state.hasMoreMessagesByConversation,
        active.id: false,
      },
      latestRisk: _riskFromConversation(resetConversation),
      latestCtas: const [],
      clearError: true,
      clearRetryContext: true,
      clearResponseMetadata: true,
    );
    await persist();
  }

  Future<void> _hydrateConversationFromBackend(
    String conversationId, {
    bool showSyncState = true,
  }) async {
    if (!_repository.isRemoteEnabled) {
      return;
    }
    final exists = state.conversations.any((item) => item.id == conversationId);
    if (!exists) {
      return;
    }

    if (showSyncState) {
      state = state.copyWith(
        isLoadingHistory: true,
        syncStatus: ChatSyncStatus.syncing,
        clearError: true,
      );
    }

    try {
      final remoteConversation =
          await _repository.getConversation(conversationId);
      final page = await _repository.listMessages(
        conversationId: conversationId,
        page: 1,
        pageSize: _historyPageSize,
      );
      final hydratedConversation = remoteConversation.copyWith(
        messages: page.items,
      );
      final activeId = state.activeConversationId == conversationId
          ? hydratedConversation.id
          : state.activeConversationId;
      final activeConversation = activeId == hydratedConversation.id
          ? hydratedConversation
          : state.conversations.firstWhere(
              (item) => item.id == activeId,
              orElse: () => hydratedConversation,
            );
      state = state.copyWith(
        conversations: _replaceConversation(
          hydratedConversation,
          previousId: conversationId,
        ),
        activeConversationId: activeId,
        latestRisk: _riskFromConversation(activeConversation),
        isLoadingHistory: false,
        syncStatus: ChatSyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        loadedMessagePages: {
          ...state.loadedMessagePages,
          hydratedConversation.id: page.page,
        },
        hasMoreMessagesByConversation: {
          ...state.hasMoreMessagesByConversation,
          hydratedConversation.id: page.hasMore,
        },
        clearError: true,
      );
      await persist();
    } catch (_) {
      state = state.copyWith(
        isLoadingHistory: false,
        syncStatus: ChatSyncStatus.offline,
        errorMessage:
            'Nao consegui sincronizar a conversa completa agora. O cache local continua disponivel.',
      );
    }
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
      isLoadingHistory: false,
      syncStatus: _repository.isRemoteEnabled
          ? ChatSyncStatus.syncing
          : _localSafeSyncStatus(),
      clearError: true,
      clearResponseMetadata: true,
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
    final sanitizedHistory = retryContext.assistantMessageIdToReplace == null
        ? conversation.messages
        : conversation.messages
            .where(
              (item) => item.id != retryContext.assistantMessageIdToReplace,
            )
            .toList(growable: false);
    final sanitizedConversation =
        retryContext.assistantMessageIdToReplace == null
            ? conversation
            : conversation.copyWith(
                messages: sanitizedHistory,
                updatedAt: DateTime.now(),
              );

    state = state.copyWith(
      conversations: retryContext.assistantMessageIdToReplace == null
          ? state.conversations
          : _replaceConversation(sanitizedConversation),
      isTyping: true,
      clearError: true,
    );
    await persist();
    await _completeAssistantResponse(
      conversationId: sanitizedConversation.id,
      prompt: retryContext.prompt,
      history: sanitizedHistory,
    );
  }

  Future<void> _completeAssistantResponse({
    required String conversationId,
    required String prompt,
    required List<ChatMessageModel> history,
  }) async {
    try {
      final reply = await _repository
          .sendMessage(
            conversationId: conversationId,
            message: prompt,
            discreetMode: state.conversations
                .firstWhere((conversation) => conversation.id == conversationId)
                .discreetMode,
            history: history,
          )
          .timeout(const Duration(seconds: 28));

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
        id: reply.conversationId,
        lastRiskLevel: reply.risk.level,
        messages: [...updatedConversation.messages, reply.assistantMessage],
        updatedAt: DateTime.now(),
      );
      final preservedPage = state.loadedMessagePages[conversationId] ?? 1;
      final preservedHasMore =
          state.hasMoreMessagesByConversation[conversationId] ?? false;
      final nextLoadedPages = Map<String, int>.from(state.loadedMessagePages);
      final nextHasMoreMessages =
          Map<String, bool>.from(state.hasMoreMessagesByConversation);
      if (reply.conversationId != conversationId) {
        nextLoadedPages.remove(conversationId);
        nextHasMoreMessages.remove(conversationId);
      }
      nextLoadedPages[reply.conversationId] =
          preservedPage < 1 ? 1 : preservedPage;
      nextHasMoreMessages[reply.conversationId] = preservedHasMore;

      final isActiveConversation = state.activeConversationId == conversationId;
      final latestRisk = isActiveConversation ? reply.risk : state.latestRisk;
      final activeConversationId = isActiveConversation
          ? reply.conversationId
          : state.activeConversationId;

      state = state.copyWith(
        conversations:
            _replaceConversation(completed, previousId: conversationId),
        activeConversationId: activeConversationId,
        isTyping: false,
        latestRisk: latestRisk,
        latestCtas: reply.ctas,
        quickSuggestions: reply.suggestions.isEmpty
            ? ChatState.defaultChatSuggestions
            : reply.suggestions,
        lastAssistantMessage: reply.assistantMessage,
        responseMode: reply.responseMode,
        situationType: reply.situationType,
        conversationContext: reply.conversationContext,
        lastResponseUsedFallback:
            reply.servedFromFallback || reply.backendFallbackUsed,
        lastResponseWasRepaired: reply.validationRepaired,
        loadedMessagePages: nextLoadedPages,
        hasMoreMessagesByConversation: nextHasMoreMessages,
        syncStatus: reply.servedFromFallback
            ? (_repository.isRemoteEnabled
                ? ChatSyncStatus.offline
                : _localSafeSyncStatus())
            : ChatSyncStatus.synced,
        lastSyncedAt:
            reply.servedFromFallback ? state.lastSyncedAt : DateTime.now(),
        errorMessage: reply.servedFromFallback
            ? _fallbackStatusMessage(reply.fallbackReason)
            : null,
        clearError: !reply.servedFromFallback,
        retryContext: reply.canRetryRemote
            ? PendingResponseContext(
                conversationId: reply.conversationId,
                prompt: prompt,
                userMessageId:
                    state.retryContext?.userMessageId ?? generateId(),
                assistantMessageIdToReplace: reply.assistantMessage.id,
              )
            : null,
        clearRetryContext: !reply.canRetryRemote,
      );
      await persist();
    } on TimeoutException {
      state = state.copyWith(
        isTyping: false,
        isLoadingHistory: false,
        syncStatus: ChatSyncStatus.offline,
        errorMessage:
            'A resposta demorou mais do que o esperado. Quando voce quiser, tente novamente.',
      );
    } catch (_) {
      state = state.copyWith(
        isTyping: false,
        isLoadingHistory: false,
        syncStatus: ChatSyncStatus.offline,
        errorMessage:
            'Nao consegui responder agora. Sua mensagem continua salva e voce pode tentar de novo.',
      );
    }
  }

  List<ConversationModel> _replaceConversation(
    ConversationModel updated, {
    String? previousId,
  }) {
    final targetId = previousId ?? updated.id;
    if (!state.conversations
        .any((item) => item.id == targetId || item.id == updated.id)) {
      return _sortConversations([updated, ...state.conversations]);
    }
    final items = state.conversations
        .where((item) => item.id != updated.id || item.id == targetId)
        .map((item) => item.id == targetId ? updated : item)
        .toList(growable: false);
    return _sortConversations(items);
  }

  List<ConversationModel> _mergeConversations({
    required List<ConversationModel> localConversations,
    required List<ConversationModel> remoteConversations,
  }) {
    final byId = <String, ConversationModel>{
      for (final conversation in localConversations)
        conversation.id: conversation,
    };

    for (final remote in remoteConversations) {
      final local = byId[remote.id];
      byId[remote.id] = local == null
          ? remote
          : _resolveConversationConflict(local: local, remote: remote);
    }

    return byId.values.toList(growable: false);
  }

  ConversationModel _resolveConversationConflict({
    required ConversationModel local,
    required ConversationModel remote,
  }) {
    if (local.updatedAt.isAfter(remote.updatedAt) &&
        local.messages.length >= remote.messages.length) {
      return local;
    }
    if (remote.messages.length >= local.messages.length) {
      return remote;
    }

    return local.copyWith(
      lastRiskLevel: remote.lastRiskLevel.index > local.lastRiskLevel.index
          ? remote.lastRiskLevel
          : local.lastRiskLevel,
      updatedAt: local.updatedAt.isAfter(remote.updatedAt)
          ? local.updatedAt
          : remote.updatedAt,
    );
  }

  List<ConversationModel> _sortConversations(
      List<ConversationModel> conversations) {
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

  String _deriveConversationTitle(
      ConversationModel conversation, String prompt) {
    if (!_isGenericConversationTitle(conversation.title) ||
        conversation.messages.isNotEmpty) {
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
      requiresImmediateAction:
          conversation.lastRiskLevel.index >= RiskLevel.high.index,
    );
  }

  String _fallbackStatusMessage(String? fallbackReason) {
    return switch (fallbackReason) {
      'not_configured' =>
        'Modo offline seguro ativado. Enquanto o servico inteligente nao fica disponivel, mantive uma resposta local segura para voce continuar.',
      'timeout' =>
        'O servico inteligente demorou para responder. Mantive uma resposta local segura e voce pode tentar novamente quando quiser.',
      'rate_limited' =>
        'O servico inteligente recebeu muitas tentativas agora. Mantive uma resposta local segura e voce pode tentar novamente em instantes.',
      'conversation_not_found' =>
        'A conversa precisou ser reorganizada para continuar com seguranca. Use a resposta local por enquanto ou tente novamente.',
      'server_error' =>
        'O servico inteligente ficou indisponivel agora. Mantive uma resposta local segura e voce pode tentar novamente.',
      _ =>
        'Sem conexao com o servico inteligente agora. Usei uma resposta local segura e sua mensagem continua salva neste aparelho.',
    };
  }

  ChatSyncStatus _localSafeSyncStatus() {
    final backend = _ref.read(backendConfigProvider);
    if (backend.isLoading || backend.isDiscovering) {
      return ChatSyncStatus.syncing;
    }
    if (backend.hasCompletedDiscovery) {
      return ChatSyncStatus.offline;
    }
    return ChatSyncStatus.localOnly;
  }
}

class _CachedChatSession {
  const _CachedChatSession({
    required this.conversations,
    required this.activeConversationId,
  });

  final List<ConversationModel> conversations;
  final String activeConversationId;
}
