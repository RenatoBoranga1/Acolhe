import 'package:acolhe_mobile/features/chat/data/chat_api_client.dart';
import 'package:acolhe_mobile/features/chat/data/chat_dtos.dart';
import 'package:acolhe_mobile/features/chat/data/chat_fallback_service.dart';
import 'package:acolhe_mobile/features/chat/data/chat_result.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatFallbackServiceProvider = Provider<ChatFallbackService>((ref) {
  return const ChatFallbackService();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    apiClient: ref.read(chatApiClientProvider),
    fallbackService: ref.read(chatFallbackServiceProvider),
  );
});

class ChatRepository {
  const ChatRepository({
    required ChatApiClient apiClient,
    required ChatFallbackService fallbackService,
  })  : _apiClient = apiClient,
        _fallbackService = fallbackService;

  final ChatApiClient _apiClient;
  final ChatFallbackService _fallbackService;

  bool get isRemoteEnabled => _apiClient.isEnabled;

  Future<List<ConversationModel>> listConversations() async {
    final conversations = await _apiClient.listConversations();
    return conversations.map((item) => item.toDomain()).toList(growable: false);
  }

  Future<ConversationModel> createConversation({
    required String title,
    required bool discreetMode,
  }) async {
    final conversation = await _apiClient.createConversation(
      title: title,
      discreetMode: discreetMode,
    );
    return conversation.toDomain();
  }

  Future<ChatSendResult> sendMessage({
    required String? conversationId,
    required String message,
    required bool discreetMode,
    required List<ChatMessageModel> history,
  }) async {
    if (!isRemoteEnabled) {
      return _fallbackService.buildSafeReply(
        conversationId: conversationId ?? generateId(),
        text: message,
        history: history,
      );
    }

    try {
      return await _sendRemote(
        conversationId: conversationId,
        message: message,
        discreetMode: discreetMode,
        history: history,
      );
    } on ChatApiException catch (error) {
      if (error.statusCode == 404 && conversationId != null) {
        try {
          return await _sendRemote(
            conversationId: null,
            message: message,
            discreetMode: discreetMode,
            history: history,
          );
        } on Object {
          // Fall through to local safety fallback below.
        }
      }
      return _fallbackService.buildSafeReply(
        conversationId: conversationId ?? generateId(),
        text: message,
        history: history,
      );
    } on Object {
      return _fallbackService.buildSafeReply(
        conversationId: conversationId ?? generateId(),
        text: message,
        history: history,
      );
    }
  }

  Future<ChatSendResult> _sendRemote({
    required String? conversationId,
    required String message,
    required bool discreetMode,
    required List<ChatMessageModel> history,
  }) async {
    final recentHistory =
        history.length > 12 ? history.sublist(history.length - 12) : history;
    final response = await _apiClient.sendMessage(
      conversationId: conversationId,
      message: message,
      discreetMode: discreetMode,
      history: recentHistory
          .map(ContextMessageDto.fromDomain)
          .toList(growable: false),
    );
    return response.toDomain();
  }
}
