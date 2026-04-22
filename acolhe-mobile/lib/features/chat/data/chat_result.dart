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
    this.servedFromFallback = false,
  });

  final String conversationId;
  final ChatMessageModel assistantMessage;
  final RiskAssessment risk;
  final List<String> ctas;
  final List<String> suggestions;
  final String? responseMode;
  final String? situationType;
  final Map<String, dynamic>? conversationContext;
  final bool servedFromFallback;
}
