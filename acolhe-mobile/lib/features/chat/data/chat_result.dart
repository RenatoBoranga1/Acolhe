import 'package:acolhe_mobile/shared/models/app_models.dart';

class ChatSendResult {
  const ChatSendResult({
    required this.conversationId,
    required this.assistantMessage,
    required this.risk,
    required this.ctas,
    required this.suggestions,
    this.responseMode,
    this.situationType,
    this.conversationContext,
    this.backendFallbackUsed = false,
    this.validationRepaired = false,
    this.servedFromFallback = false,
    this.canRetryRemote = false,
    this.fallbackReason,
  });

  final String conversationId;
  final ChatMessageModel assistantMessage;
  final RiskAssessment risk;
  final List<String> ctas;
  final List<String> suggestions;
  final String? responseMode;
  final String? situationType;
  final Map<String, dynamic>? conversationContext;
  final bool backendFallbackUsed;
  final bool validationRepaired;
  final bool servedFromFallback;
  final bool canRetryRemote;
  final String? fallbackReason;
}

class ConversationMessagesPage {
  const ConversationMessagesPage({
    required this.conversationId,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
    required this.items,
  });

  final String conversationId;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;
  final List<ChatMessageModel> items;
}
