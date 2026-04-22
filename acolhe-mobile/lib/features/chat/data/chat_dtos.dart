import 'package:acolhe_mobile/features/chat/data/chat_result.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.role,
    required this.content,
    required this.riskLevel,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final String riskLevel;
  final DateTime createdAt;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ??
          json['riskLevel'] as String? ??
          'low',
      createdAt: DateTime.tryParse(
            json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  ChatMessageModel toDomain() {
    return ChatMessageModel(
      id: id,
      role: role == 'user' ? MessageRole.user : MessageRole.assistant,
      content: content,
      riskLevel: RiskLevelX.fromLabel(riskLevel),
      createdAt: createdAt,
    );
  }
}

class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.title,
    required this.lastRiskLevel,
    required this.updatedAt,
    required this.discreetMode,
    required this.messages,
  });

  final String id;
  final String title;
  final String lastRiskLevel;
  final DateTime updatedAt;
  final bool discreetMode;
  final List<ChatMessageDto> messages;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Nova conversa',
      lastRiskLevel: json['last_risk_level'] as String? ??
          json['lastRiskLevel'] as String? ??
          'low',
      updatedAt: DateTime.tryParse(
            json['updated_at'] as String? ?? json['updatedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      discreetMode: json['discreet_mode'] as bool? ??
          json['discreetMode'] as bool? ??
          false,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((item) =>
              ChatMessageDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }

  ConversationModel toDomain() {
    return ConversationModel(
      id: id,
      title: title,
      lastRiskLevel: RiskLevelX.fromLabel(lastRiskLevel),
      discreetMode: discreetMode,
      messages: messages.map((item) => item.toDomain()).toList(growable: false),
      createdAt: messages.isEmpty ? updatedAt : messages.first.createdAt,
      updatedAt: updatedAt,
    );
  }
}

class RiskAssessmentDto {
  const RiskAssessmentDto({
    required this.level,
    required this.score,
    required this.reasons,
    required this.recommendedActions,
    required this.requiresImmediateAction,
  });

  final String level;
  final int score;
  final List<String> reasons;
  final List<String> recommendedActions;
  final bool requiresImmediateAction;

  factory RiskAssessmentDto.fromJson(Map<String, dynamic> json) {
    return RiskAssessmentDto(
      level: json['level'] as String? ?? 'low',
      score: (json['score'] as num?)?.toInt() ?? 0,
      reasons: List<String>.from(json['reasons'] as List? ?? const []),
      recommendedActions: List<String>.from(
        (json['recommended_actions'] as List?) ??
            (json['actions'] as List?) ??
            const [],
      ),
      requiresImmediateAction: json['requires_immediate_action'] as bool? ??
          json['requiresImmediateAction'] as bool? ??
          false,
    );
  }

  RiskAssessment toDomain() {
    return RiskAssessment(
      level: RiskLevelX.fromLabel(level),
      score: score,
      reasons: reasons,
      actions: recommendedActions,
      requiresImmediateAction: requiresImmediateAction,
    );
  }
}

class ChatMessageResponseDto {
  const ChatMessageResponseDto({
    required this.conversationId,
    required this.assistantMessage,
    required this.risk,
    required this.ctas,
    required this.suggestions,
    this.responseMode,
    this.situationType,
    this.conversationContext,
    this.fallbackUsed = false,
    this.validationRepaired = false,
  });

  final String conversationId;
  final ChatMessageDto assistantMessage;
  final RiskAssessmentDto risk;
  final List<String> ctas;
  final List<String> suggestions;
  final String? responseMode;
  final String? situationType;
  final Map<String, dynamic>? conversationContext;
  final bool fallbackUsed;
  final bool validationRepaired;

  factory ChatMessageResponseDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageResponseDto(
      conversationId: json['conversation_id'] as String? ??
          json['conversationId'] as String,
      assistantMessage: ChatMessageDto.fromJson(
        Map<String, dynamic>.from(json['assistant_message'] as Map),
      ),
      risk: RiskAssessmentDto.fromJson(
          Map<String, dynamic>.from(json['risk'] as Map)),
      ctas: List<String>.from(json['ctas'] as List? ?? const []),
      suggestions: List<String>.from(json['suggestions'] as List? ?? const []),
      responseMode:
          json['response_mode'] as String? ?? json['responseMode'] as String?,
      situationType:
          json['situation_type'] as String? ?? json['situationType'] as String?,
      conversationContext: json['conversation_context'] == null
          ? null
          : Map<String, dynamic>.from(json['conversation_context'] as Map),
      fallbackUsed: json['fallback_used'] as bool? ??
          json['fallbackUsed'] as bool? ??
          false,
      validationRepaired: json['validation_repaired'] as bool? ??
          json['validationRepaired'] as bool? ??
          false,
    );
  }

  ChatSendResult toDomain() {
    return ChatSendResult(
      conversationId: conversationId,
      assistantMessage: assistantMessage.toDomain(),
      risk: risk.toDomain(),
      ctas: ctas,
      suggestions: suggestions,
      responseMode: responseMode,
      situationType: situationType,
      conversationContext: conversationContext,
      backendFallbackUsed: fallbackUsed,
      validationRepaired: validationRepaired,
    );
  }
}

class ContextMessageDto {
  const ContextMessageDto({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  factory ContextMessageDto.fromDomain(ChatMessageModel message) {
    return ContextMessageDto(
      role: message.role.name,
      content: message.content,
    );
  }
}
