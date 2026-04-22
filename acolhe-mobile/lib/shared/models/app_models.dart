import 'dart:convert';

enum RiskLevel { low, moderate, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'baixo',
        RiskLevel.moderate => 'moderado',
        RiskLevel.high => 'alto',
        RiskLevel.critical => 'critico',
      };

  static RiskLevel fromLabel(String value) {
    return RiskLevel.values.firstWhere(
      (item) => item.label == value.toLowerCase(),
      orElse: () => RiskLevel.low,
    );
  }
}

enum MessageRole { user, assistant }

String generateId() => DateTime.now().microsecondsSinceEpoch.toString();

class RiskAssessment {
  const RiskAssessment({
    required this.level,
    required this.score,
    required this.reasons,
    required this.actions,
    required this.requiresImmediateAction,
  });

  final RiskLevel level;
  final int score;
  final List<String> reasons;
  final List<String> actions;
  final bool requiresImmediateAction;

  Map<String, dynamic> toJson() => {
        'level': level.label,
        'score': score,
        'reasons': reasons,
        'actions': actions,
        'requiresImmediateAction': requiresImmediateAction,
      };

  factory RiskAssessment.fromJson(Map<String, dynamic> json) => RiskAssessment(
        level: RiskLevelX.fromLabel((json['level'] as String?) ?? 'baixo'),
        score: (json['score'] as num?)?.toInt() ?? 0,
        reasons: List<String>.from(json['reasons'] as List? ?? const []),
        actions: List<String>.from(
          (json['actions'] as List?) ?? (json['recommended_actions'] as List?) ?? const [],
        ),
        requiresImmediateAction: json['requiresImmediateAction'] as bool? ??
            json['requires_immediate_action'] as bool? ??
            false,
      );
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.riskLevel,
    required this.createdAt,
  });

  final String id;
  final MessageRole role;
  final String content;
  final RiskLevel riskLevel;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'riskLevel': riskLevel.label,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        role: (json['role'] as String) == 'user' ? MessageRole.user : MessageRole.assistant,
        content: json['content'] as String,
        riskLevel: RiskLevelX.fromLabel(
          (json['riskLevel'] as String?) ?? (json['risk_level'] as String?) ?? 'baixo',
        ),
        createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      );
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.title,
    required this.lastRiskLevel,
    required this.discreetMode,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RiskLevel lastRiskLevel;
  final bool discreetMode;
  final List<ChatMessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmptyConversation => messages.isEmpty;

  ChatMessageModel? get lastMessage => messages.isEmpty ? null : messages.last;

  String get previewText {
    final previewSource = lastMessage?.content.trim() ?? '';
    if (previewSource.isEmpty) {
      return 'Comece quando quiser.';
    }
    if (previewSource.length <= 86) {
      return previewSource;
    }
    return '${previewSource.substring(0, 83)}...';
  }

  ConversationModel copyWith({
    String? id,
    String? title,
    RiskLevel? lastRiskLevel,
    bool? discreetMode,
    List<ChatMessageModel>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      lastRiskLevel: lastRiskLevel ?? this.lastRiskLevel,
      discreetMode: discreetMode ?? this.discreetMode,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'lastRiskLevel': lastRiskLevel.label,
        'discreetMode': discreetMode,
        'messages': messages.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        lastRiskLevel: RiskLevelX.fromLabel(
          (json['lastRiskLevel'] as String?) ?? (json['last_risk_level'] as String?) ?? 'baixo',
        ),
        discreetMode: json['discreetMode'] as bool? ?? json['discreet_mode'] as bool? ?? false,
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((item) => ChatMessageModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        createdAt: DateTime.tryParse(
              (json['createdAt'] as String?) ?? (json['created_at'] as String?) ?? '',
            ) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(
              (json['updatedAt'] as String?) ?? (json['updated_at'] as String?) ?? '',
            ) ??
            DateTime.now(),
      );
}

class IncidentRecordModel {
  const IncidentRecordModel({
    required this.id,
    required this.occurredOn,
    required this.occurredAt,
    required this.location,
    required this.description,
    required this.peopleInvolved,
    required this.witnesses,
    required this.attachments,
    required this.observations,
    required this.perceivedImpacts,
    required this.summary,
  });

  final String id;
  final String occurredOn;
  final String occurredAt;
  final String location;
  final String description;
  final List<String> peopleInvolved;
  final List<String> witnesses;
  final List<String> attachments;
  final String observations;
  final List<String> perceivedImpacts;
  final String summary;

  IncidentRecordModel copyWith({String? summary}) => IncidentRecordModel(
        id: id,
        occurredOn: occurredOn,
        occurredAt: occurredAt,
        location: location,
        description: description,
        peopleInvolved: peopleInvolved,
        witnesses: witnesses,
        attachments: attachments,
        observations: observations,
        perceivedImpacts: perceivedImpacts,
        summary: summary ?? this.summary,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'occurredOn': occurredOn,
        'occurredAt': occurredAt,
        'location': location,
        'description': description,
        'peopleInvolved': peopleInvolved,
        'witnesses': witnesses,
        'attachments': attachments,
        'observations': observations,
        'perceivedImpacts': perceivedImpacts,
        'summary': summary,
      };

  factory IncidentRecordModel.fromJson(Map<String, dynamic> json) => IncidentRecordModel(
        id: json['id'] as String,
        occurredOn: (json['occurredOn'] as String?) ?? (json['occurred_on'] as String?) ?? '',
        occurredAt: (json['occurredAt'] as String?) ?? (json['occurred_at'] as String?) ?? '',
        location: (json['location'] as String?) ?? '',
        description: json['description'] as String,
        peopleInvolved: List<String>.from(
          (json['peopleInvolved'] as List?) ?? (json['people_involved'] as List?) ?? const [],
        ),
        witnesses: List<String>.from(json['witnesses'] as List? ?? const []),
        attachments: List<String>.from(json['attachments'] as List? ?? const []),
        observations: (json['observations'] as String?) ?? '',
        perceivedImpacts: List<String>.from(
          (json['perceivedImpacts'] as List?) ??
              (json['perceived_impacts'] as List?) ??
              const [],
        ),
        summary: (json['summary'] as String?) ??
            (json['chronological_summary'] as String?) ??
            '',
      );
}

class SafetyPlanModel {
  const SafetyPlanModel({
    required this.safeLocations,
    required this.warningSigns,
    required this.immediateSteps,
    required this.priorityContacts,
    required this.personalNotes,
    required this.emergencyChecklist,
  });

  final List<String> safeLocations;
  final List<String> warningSigns;
  final List<String> immediateSteps;
  final List<String> priorityContacts;
  final String personalNotes;
  final List<String> emergencyChecklist;

  SafetyPlanModel copyWith({
    List<String>? safeLocations,
    List<String>? warningSigns,
    List<String>? immediateSteps,
    List<String>? priorityContacts,
    String? personalNotes,
    List<String>? emergencyChecklist,
  }) =>
      SafetyPlanModel(
        safeLocations: safeLocations ?? this.safeLocations,
        warningSigns: warningSigns ?? this.warningSigns,
        immediateSteps: immediateSteps ?? this.immediateSteps,
        priorityContacts: priorityContacts ?? this.priorityContacts,
        personalNotes: personalNotes ?? this.personalNotes,
        emergencyChecklist: emergencyChecklist ?? this.emergencyChecklist,
      );

  Map<String, dynamic> toJson() => {
        'safeLocations': safeLocations,
        'warningSigns': warningSigns,
        'immediateSteps': immediateSteps,
        'priorityContacts': priorityContacts,
        'personalNotes': personalNotes,
        'emergencyChecklist': emergencyChecklist,
      };

  factory SafetyPlanModel.fromJson(Map<String, dynamic> json) => SafetyPlanModel(
        safeLocations: List<String>.from(
          (json['safeLocations'] as List?) ?? (json['safe_locations'] as List?) ?? const [],
        ),
        warningSigns: List<String>.from(
          (json['warningSigns'] as List?) ?? (json['warning_signs'] as List?) ?? const [],
        ),
        immediateSteps: List<String>.from(
          (json['immediateSteps'] as List?) ?? (json['immediate_steps'] as List?) ?? const [],
        ),
        priorityContacts: List<String>.from(
          (json['priorityContacts'] as List?) ?? (json['priority_contacts'] as List?) ?? const [],
        ),
        personalNotes: (json['personalNotes'] as String?) ?? (json['personal_notes'] as String?) ?? '',
        emergencyChecklist: List<String>.from(
          (json['emergencyChecklist'] as List?) ??
              (json['emergency_checklist'] as List?) ??
              const [],
        ),
      );
}

class TrustedContactModel {
  const TrustedContactModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.priority,
    required this.readyMessage,
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final int priority;
  final String readyMessage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'priority': priority,
        'readyMessage': readyMessage,
      };

  factory TrustedContactModel.fromJson(Map<String, dynamic> json) => TrustedContactModel(
        id: json['id'] as String,
        name: json['name'] as String,
        relationship: json['relationship'] as String,
        phone: (json['phone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        priority: (json['priority'] as num?)?.toInt() ?? 1,
        readyMessage: (json['readyMessage'] as String?) ?? (json['ready_message'] as String?) ?? '',
      );
}

class ResourceArticleModel {
  const ResourceArticleModel({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    required this.ctaLabel,
  });

  final String id;
  final String slug;
  final String category;
  final String title;
  final String summary;
  final String body;
  final String ctaLabel;

  factory ResourceArticleModel.fromJson(Map<String, dynamic> json) => ResourceArticleModel(
        id: (json['id'] as String?) ?? generateId(),
        slug: json['slug'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        body: json['body'] as String,
        ctaLabel: (json['ctaLabel'] as String?) ?? (json['cta_label'] as String?) ?? '',
      );
}

class AuthStateModel {
  const AuthStateModel({
    required this.isLoading,
    required this.onboardingCompleted,
    required this.hasPin,
    required this.isUnlocked,
    required this.biometricsEnabled,
    required this.discreetMode,
    required this.autoLockMinutes,
    required this.aliasName,
    required this.notificationsHidden,
    required this.quickExitEnabled,
    required this.privacyShield,
  });

  final bool isLoading;
  final bool onboardingCompleted;
  final bool hasPin;
  final bool isUnlocked;
  final bool biometricsEnabled;
  final bool discreetMode;
  final int autoLockMinutes;
  final String aliasName;
  final bool notificationsHidden;
  final bool quickExitEnabled;
  final bool privacyShield;

  String get currentAppName => discreetMode ? aliasName : 'Acolhe';

  AuthStateModel copyWith({
    bool? isLoading,
    bool? onboardingCompleted,
    bool? hasPin,
    bool? isUnlocked,
    bool? biometricsEnabled,
    bool? discreetMode,
    int? autoLockMinutes,
    String? aliasName,
    bool? notificationsHidden,
    bool? quickExitEnabled,
    bool? privacyShield,
  }) {
    return AuthStateModel(
      isLoading: isLoading ?? this.isLoading,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      hasPin: hasPin ?? this.hasPin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      discreetMode: discreetMode ?? this.discreetMode,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      aliasName: aliasName ?? this.aliasName,
      notificationsHidden: notificationsHidden ?? this.notificationsHidden,
      quickExitEnabled: quickExitEnabled ?? this.quickExitEnabled,
      privacyShield: privacyShield ?? this.privacyShield,
    );
  }

  Map<String, dynamic> toJson() => {
        'onboardingCompleted': onboardingCompleted,
        'hasPin': hasPin,
        'isUnlocked': isUnlocked,
        'biometricsEnabled': biometricsEnabled,
        'discreetMode': discreetMode,
        'autoLockMinutes': autoLockMinutes,
        'aliasName': aliasName,
        'notificationsHidden': notificationsHidden,
        'quickExitEnabled': quickExitEnabled,
      };

  factory AuthStateModel.initial() => const AuthStateModel(
        isLoading: true,
        onboardingCompleted: false,
        hasPin: false,
        isUnlocked: false,
        biometricsEnabled: false,
        discreetMode: false,
        autoLockMinutes: 5,
        aliasName: 'Aurora',
        notificationsHidden: true,
        quickExitEnabled: true,
        privacyShield: false,
      );

  factory AuthStateModel.fromJson(Map<String, dynamic> json) => AuthStateModel(
        isLoading: false,
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        hasPin: json['hasPin'] as bool? ?? false,
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
        discreetMode: json['discreetMode'] as bool? ?? false,
        autoLockMinutes: (json['autoLockMinutes'] as num?)?.toInt() ?? 5,
        aliasName: (json['aliasName'] as String?) ?? 'Aurora',
        notificationsHidden: json['notificationsHidden'] as bool? ?? true,
        quickExitEnabled: json['quickExitEnabled'] as bool? ?? true,
        privacyShield: false,
      );
}

List<Map<String, dynamic>> encodeConversations(List<ConversationModel> items) =>
    items.map((item) => item.toJson()).toList();

String prettyJoin(List<String> items) => items.where((item) => item.trim().isNotEmpty).join(', ');

String encodeListText(List<String> items) => items.join('\n');

List<String> decodeListText(String value) => value
    .split('\n')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String encodeModelJson(Map<String, dynamic> value) => jsonEncode(value);
