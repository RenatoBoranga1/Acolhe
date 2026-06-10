import 'package:acolhe_mobile/shared/models/app_models.dart';

enum SupportRequestStatus {
  waiting,
  assigned,
  active,
  closed,
  escalated,
  cancelled,
}

extension SupportRequestStatusX on SupportRequestStatus {
  static SupportRequestStatus fromBackend(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'assigned' => SupportRequestStatus.assigned,
      'active' => SupportRequestStatus.active,
      'closed' => SupportRequestStatus.closed,
      'escalated' => SupportRequestStatus.escalated,
      'cancelled' => SupportRequestStatus.cancelled,
      _ => SupportRequestStatus.waiting,
    };
  }

  String get label => switch (this) {
        SupportRequestStatus.waiting => 'aguardando apoiador',
        SupportRequestStatus.assigned => 'procurando alguem disponivel',
        SupportRequestStatus.active => 'apoiador conectado',
        SupportRequestStatus.closed => 'atendimento encerrado',
        SupportRequestStatus.escalated => 'encaminhado com prioridade',
        SupportRequestStatus.cancelled => 'solicitacao cancelada',
      };
}

enum SupportRoleType { user, supporter, specialist, admin }

extension SupportRoleTypeX on SupportRoleType {
  static SupportRoleType fromBackend(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'supporter' => SupportRoleType.supporter,
      'specialist' => SupportRoleType.specialist,
      'admin' => SupportRoleType.admin,
      _ => SupportRoleType.user,
    };
  }

  String get label => switch (this) {
        SupportRoleType.user => 'Pessoa atendida',
        SupportRoleType.supporter => 'Apoiador',
        SupportRoleType.specialist => 'Especialista verificado',
        SupportRoleType.admin => 'Moderacao',
      };
}

class SupportSummaryModel {
  const SupportSummaryModel({
    required this.contextMain,
    required this.emotionalState,
    required this.riskLevel,
    required this.situationType,
    required this.pointsToAvoid,
    required this.suggestedNextSteps,
    required this.safetyAlerts,
    required this.supporterCopilotSuggestions,
    required this.supporterReminders,
    required this.summaryText,
    required this.priorityScore,
  });

  final String contextMain;
  final String emotionalState;
  final RiskLevel riskLevel;
  final String situationType;
  final List<String> pointsToAvoid;
  final List<String> suggestedNextSteps;
  final List<String> safetyAlerts;
  final List<String> supporterCopilotSuggestions;
  final List<String> supporterReminders;
  final String summaryText;
  final double priorityScore;

  factory SupportSummaryModel.fromJson(Map<String, dynamic> json) {
    return SupportSummaryModel(
      contextMain: (json['context_main'] as String?) ??
          (json['contextMain'] as String?) ??
          '',
      emotionalState: (json['emotional_state'] as String?) ??
          (json['emotionalState'] as String?) ??
          'uncertain',
      riskLevel: RiskLevelX.fromLabel(
        (json['risk_level'] as String?) ??
            (json['riskLevel'] as String?) ??
            'low',
      ),
      situationType: (json['situation_type'] as String?) ??
          (json['situationType'] as String?) ??
          'support_request',
      pointsToAvoid: List<String>.from(
        (json['points_to_avoid'] as List?) ??
            (json['pointsToAvoid'] as List?) ??
            const [],
      ),
      suggestedNextSteps: List<String>.from(
        (json['suggested_next_steps'] as List?) ??
            (json['suggestedNextSteps'] as List?) ??
            const [],
      ),
      safetyAlerts: List<String>.from(
        (json['safety_alerts'] as List?) ??
            (json['safetyAlerts'] as List?) ??
            const [],
      ),
      supporterCopilotSuggestions: List<String>.from(
        (json['supporter_copilot_suggestions'] as List?) ??
            (json['supporterCopilotSuggestions'] as List?) ??
            const [],
      ),
      supporterReminders: List<String>.from(
        (json['supporter_reminders'] as List?) ??
            (json['supporterReminders'] as List?) ??
            const [],
      ),
      summaryText: (json['summary_text'] as String?) ??
          (json['summaryText'] as String?) ??
          '',
      priorityScore: (json['priority_score'] as num?)?.toDouble() ??
          (json['priorityScore'] as num?)?.toDouble() ??
          0,
    );
  }
}

class SupporterProfileModel {
  const SupporterProfileModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.roleType,
    required this.specialties,
    required this.verificationStatus,
    required this.isAvailable,
    required this.maxActiveSessions,
    required this.trainingCompleted,
    this.guidelinesAcceptedAt,
    this.presenceStatus,
    this.activeSessionCount = 0,
  });

  final String id;
  final String userId;
  final String displayName;
  final SupportRoleType roleType;
  final List<String> specialties;
  final String verificationStatus;
  final bool isAvailable;
  final int maxActiveSessions;
  final bool trainingCompleted;
  final DateTime? guidelinesAcceptedAt;
  final String? presenceStatus;
  final int activeSessionCount;

  bool get isVerifiedSpecialist =>
      roleType == SupportRoleType.specialist &&
      verificationStatus.toLowerCase() == 'verified';

  factory SupporterProfileModel.fromJson(Map<String, dynamic> json) {
    return SupporterProfileModel(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? (json['userId'] as String),
      displayName:
          (json['display_name'] as String?) ?? (json['displayName'] as String),
      roleType: SupportRoleTypeX.fromBackend(
        (json['role_type'] as String?) ?? (json['roleType'] as String?),
      ),
      specialties: List<String>.from(json['specialties'] as List? ?? const []),
      verificationStatus: (json['verification_status'] as String?) ??
          (json['verificationStatus'] as String?) ??
          'unverified',
      isAvailable: json['is_available'] as bool? ??
          json['isAvailable'] as bool? ??
          false,
      maxActiveSessions: (json['max_active_sessions'] as num?)?.toInt() ??
          (json['maxActiveSessions'] as num?)?.toInt() ??
          2,
      trainingCompleted: json['training_completed'] as bool? ??
          json['trainingCompleted'] as bool? ??
          false,
      guidelinesAcceptedAt: DateTime.tryParse(
        (json['guidelines_accepted_at'] as String?) ??
            (json['guidelinesAcceptedAt'] as String?) ??
            '',
      ),
      presenceStatus: (json['presence_status'] as String?) ??
          (json['presenceStatus'] as String?),
      activeSessionCount: (json['active_session_count'] as num?)?.toInt() ??
          (json['activeSessionCount'] as num?)?.toInt() ??
          0,
    );
  }
}

class SupportRequestModel {
  const SupportRequestModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.riskLevel,
    required this.situationType,
    required this.priorityScore,
    required this.requesterAlias,
    required this.createdAt,
    required this.safeSummary,
    required this.queueStatusLabel,
    this.distributionScore,
    this.recommendedSpecialty,
    this.conversationId,
    this.assignedSupporterId,
    this.assignedSpecialistId,
    this.assignedAt,
    this.closedAt,
    this.closeReason,
    this.sessionId,
  });

  final String id;
  final String userId;
  final String? conversationId;
  final SupportRequestStatus status;
  final RiskLevel riskLevel;
  final String situationType;
  final double priorityScore;
  final String requesterAlias;
  final String? assignedSupporterId;
  final String? assignedSpecialistId;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? closedAt;
  final String? closeReason;
  final SupportSummaryModel safeSummary;
  final String? sessionId;
  final String queueStatusLabel;
  final double? distributionScore;
  final String? recommendedSpecialty;

  bool get isWaiting =>
      status == SupportRequestStatus.waiting ||
      status == SupportRequestStatus.assigned;
  bool get isActive => status == SupportRequestStatus.active;

  factory SupportRequestModel.fromJson(Map<String, dynamic> json) {
    return SupportRequestModel(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? (json['userId'] as String),
      conversationId: (json['conversation_id'] as String?) ??
          json['conversationId'] as String?,
      status: SupportRequestStatusX.fromBackend(json['status'] as String?),
      riskLevel: RiskLevelX.fromLabel(
        (json['risk_level'] as String?) ??
            (json['riskLevel'] as String?) ??
            'low',
      ),
      situationType: (json['situation_type'] as String?) ??
          (json['situationType'] as String?) ??
          'support_request',
      priorityScore: (json['priority_score'] as num?)?.toDouble() ??
          (json['priorityScore'] as num?)?.toDouble() ??
          0,
      requesterAlias: (json['requester_alias'] as String?) ??
          (json['requesterAlias'] as String?) ??
          'Pessoa atendida',
      assignedSupporterId: (json['assigned_supporter_id'] as String?) ??
          json['assignedSupporterId'] as String?,
      assignedSpecialistId: (json['assigned_specialist_id'] as String?) ??
          json['assignedSpecialistId'] as String?,
      createdAt: DateTime.tryParse(
            (json['created_at'] as String?) ??
                (json['createdAt'] as String?) ??
                '',
          ) ??
          DateTime.now(),
      assignedAt: DateTime.tryParse(
        (json['assigned_at'] as String?) ??
            (json['assignedAt'] as String?) ??
            '',
      ),
      closedAt: DateTime.tryParse(
        (json['closed_at'] as String?) ?? (json['closedAt'] as String?) ?? '',
      ),
      closeReason:
          (json['close_reason'] as String?) ?? (json['closeReason'] as String?),
      safeSummary: SupportSummaryModel.fromJson(
        Map<String, dynamic>.from(json['safe_summary'] as Map? ?? const {}),
      ),
      sessionId:
          (json['session_id'] as String?) ?? json['sessionId'] as String?,
      queueStatusLabel: (json['queue_status_label'] as String?) ??
          (json['queueStatusLabel'] as String?) ??
          SupportRequestStatusX.fromBackend(json['status'] as String?).label,
      distributionScore: (json['distribution_score'] as num?)?.toDouble() ??
          (json['distributionScore'] as num?)?.toDouble(),
      recommendedSpecialty: (json['recommended_specialty'] as String?) ??
          (json['recommendedSpecialty'] as String?),
    );
  }
}

class HumanSupportMessageModel {
  const HumanSupportMessageModel({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    required this.isFlagged,
    required this.riskSignalDetected,
  });

  final String id;
  final String sessionId;
  final String senderId;
  final SupportRoleType senderRole;
  final String content;
  final DateTime createdAt;
  final bool isFlagged;
  final bool riskSignalDetected;

  factory HumanSupportMessageModel.fromJson(Map<String, dynamic> json) {
    return HumanSupportMessageModel(
      id: json['id'] as String,
      sessionId:
          (json['session_id'] as String?) ?? (json['sessionId'] as String),
      senderId: (json['sender_id'] as String?) ?? (json['senderId'] as String),
      senderRole: SupportRoleTypeX.fromBackend(
        (json['sender_role'] as String?) ?? (json['senderRole'] as String?),
      ),
      content: json['content'] as String,
      createdAt: DateTime.tryParse(
            (json['created_at'] as String?) ??
                (json['createdAt'] as String?) ??
                '',
          ) ??
          DateTime.now(),
      isFlagged:
          json['is_flagged'] as bool? ?? json['isFlagged'] as bool? ?? false,
      riskSignalDetected: json['risk_signal_detected'] as bool? ??
          json['riskSignalDetected'] as bool? ??
          false,
    );
  }
}

class HumanSupportSessionModel {
  const HumanSupportSessionModel({
    required this.id,
    required this.supportRequestId,
    required this.userId,
    required this.supporterId,
    required this.status,
    required this.messages,
    required this.copilotSuggestions,
    required this.supporterReminders,
    this.startedAt,
    this.endedAt,
    this.closeReason,
    this.supporterProfile,
    this.safeSummary,
  });

  final String id;
  final String supportRequestId;
  final String userId;
  final String supporterId;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? closeReason;
  final SupporterProfileModel? supporterProfile;
  final SupportSummaryModel? safeSummary;
  final List<HumanSupportMessageModel> messages;
  final List<String> copilotSuggestions;
  final List<String> supporterReminders;

  factory HumanSupportSessionModel.fromJson(Map<String, dynamic> json) {
    return HumanSupportSessionModel(
      id: json['id'] as String,
      supportRequestId: (json['support_request_id'] as String?) ??
          (json['supportRequestId'] as String),
      userId: (json['user_id'] as String?) ?? (json['userId'] as String),
      supporterId:
          (json['supporter_id'] as String?) ?? (json['supporterId'] as String),
      status: (json['status'] as String?) ?? 'active',
      startedAt: DateTime.tryParse(
        (json['started_at'] as String?) ?? (json['startedAt'] as String?) ?? '',
      ),
      endedAt: DateTime.tryParse(
        (json['ended_at'] as String?) ?? (json['endedAt'] as String?) ?? '',
      ),
      closeReason:
          (json['close_reason'] as String?) ?? (json['closeReason'] as String?),
      supporterProfile: json['supporter_profile'] is Map
          ? SupporterProfileModel.fromJson(
              Map<String, dynamic>.from(json['supporter_profile'] as Map),
            )
          : null,
      safeSummary: json['safe_summary'] is Map
          ? SupportSummaryModel.fromJson(
              Map<String, dynamic>.from(json['safe_summary'] as Map),
            )
          : null,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((item) => HumanSupportMessageModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      copilotSuggestions: List<String>.from(
        (json['copilot_suggestions'] as List?) ??
            (json['copilotSuggestions'] as List?) ??
            const [],
      ),
      supporterReminders: List<String>.from(
        (json['supporter_reminders'] as List?) ??
            (json['supporterReminders'] as List?) ??
            const [],
      ),
    );
  }
}

class QueueSnapshotModel {
  const QueueSnapshotModel({
    required this.request,
    required this.waitingMinutes,
    required this.priorityBucket,
    required this.distributionScore,
    required this.matchingReasons,
  });

  final SupportRequestModel request;
  final int waitingMinutes;
  final String priorityBucket;
  final double distributionScore;
  final List<String> matchingReasons;

  factory QueueSnapshotModel.fromJson(Map<String, dynamic> json) {
    return QueueSnapshotModel(
      request: SupportRequestModel.fromJson(
        Map<String, dynamic>.from(json['request'] as Map),
      ),
      waitingMinutes: (json['waiting_minutes'] as num?)?.toInt() ??
          (json['waitingMinutes'] as num?)?.toInt() ??
          0,
      priorityBucket: (json['priority_bucket'] as String?) ??
          (json['priorityBucket'] as String?) ??
          'moderado',
      distributionScore: (json['distribution_score'] as num?)?.toDouble() ??
          (json['distributionScore'] as num?)?.toDouble() ??
          0,
      matchingReasons: List<String>.from(
        (json['matching_reasons'] as List?) ??
            (json['matchingReasons'] as List?) ??
            const [],
      ),
    );
  }
}

class SupportPresenceModel {
  const SupportPresenceModel({
    required this.userId,
    required this.profileId,
    required this.displayName,
    required this.roleType,
    required this.presenceStatus,
    required this.isAvailable,
    required this.activeSessions,
    required this.updatedAt,
  });

  final String userId;
  final String profileId;
  final String displayName;
  final SupportRoleType roleType;
  final String presenceStatus;
  final bool isAvailable;
  final int activeSessions;
  final DateTime updatedAt;

  factory SupportPresenceModel.fromJson(Map<String, dynamic> json) {
    return SupportPresenceModel(
      userId: (json['user_id'] as String?) ?? (json['userId'] as String),
      profileId:
          (json['profile_id'] as String?) ?? (json['profileId'] as String),
      displayName: (json['display_name'] as String?) ??
          (json['displayName'] as String?) ??
          'Apoiador',
      roleType: SupportRoleTypeX.fromBackend(
        (json['role_type'] as String?) ?? (json['roleType'] as String?),
      ),
      presenceStatus: (json['presence_status'] as String?) ??
          (json['presenceStatus'] as String?) ??
          'offline',
      isAvailable: json['is_available'] as bool? ??
          json['isAvailable'] as bool? ??
          false,
      activeSessions: (json['active_sessions'] as num?)?.toInt() ??
          (json['activeSessions'] as num?)?.toInt() ??
          0,
      updatedAt: DateTime.tryParse(
            (json['updated_at'] as String?) ??
                (json['updatedAt'] as String?) ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}

class SupportModerationAlertModel {
  const SupportModerationAlertModel({
    required this.id,
    required this.supporterProfileId,
    required this.alertType,
    required this.severity,
    required this.rationale,
    required this.status,
    required this.createdAt,
    this.sessionId,
    this.messageId,
  });

  final String id;
  final String supporterProfileId;
  final String? sessionId;
  final String? messageId;
  final String alertType;
  final String severity;
  final String rationale;
  final String status;
  final DateTime createdAt;

  factory SupportModerationAlertModel.fromJson(Map<String, dynamic> json) {
    return SupportModerationAlertModel(
      id: json['id'] as String,
      supporterProfileId: (json['supporter_profile_id'] as String?) ??
          (json['supporterProfileId'] as String),
      sessionId:
          (json['session_id'] as String?) ?? (json['sessionId'] as String?),
      messageId:
          (json['message_id'] as String?) ?? (json['messageId'] as String?),
      alertType: (json['alert_type'] as String?) ??
          (json['alertType'] as String?) ??
          'moderation',
      severity: (json['severity'] as String?) ?? 'moderate',
      rationale: (json['rationale'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      createdAt: DateTime.tryParse(
            (json['created_at'] as String?) ??
                (json['createdAt'] as String?) ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}

class SupportMetricsModel {
  const SupportMetricsModel({
    required this.averageFirstAssignmentMinutes,
    required this.averageSessionMinutes,
    required this.sessionsPerDay,
    required this.sessionsBySupporter,
    required this.sessionsByRisk,
    required this.transferRate,
    required this.abandonmentRate,
    required this.totalClosedSessions,
  });

  final double averageFirstAssignmentMinutes;
  final double averageSessionMinutes;
  final List<Map<String, dynamic>> sessionsPerDay;
  final List<Map<String, dynamic>> sessionsBySupporter;
  final Map<String, int> sessionsByRisk;
  final double transferRate;
  final double abandonmentRate;
  final int totalClosedSessions;

  factory SupportMetricsModel.fromJson(Map<String, dynamic> json) {
    final sessionsByRiskRaw = Map<String, dynamic>.from(
      (json['sessions_by_risk'] as Map?) ??
          (json['sessionsByRisk'] as Map?) ??
          const {},
    );
    return SupportMetricsModel(
      averageFirstAssignmentMinutes:
          (json['average_first_assignment_minutes'] as num?)?.toDouble() ??
              (json['averageFirstAssignmentMinutes'] as num?)?.toDouble() ??
              0,
      averageSessionMinutes:
          (json['average_session_minutes'] as num?)?.toDouble() ??
              (json['averageSessionMinutes'] as num?)?.toDouble() ??
              0,
      sessionsPerDay: (json['sessions_per_day'] as List? ??
              json['sessionsPerDay'] as List? ??
              const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      sessionsBySupporter: (json['sessions_by_supporter'] as List? ??
              json['sessionsBySupporter'] as List? ??
              const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      sessionsByRisk: sessionsByRiskRaw.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      transferRate: (json['transfer_rate'] as num?)?.toDouble() ??
          (json['transferRate'] as num?)?.toDouble() ??
          0,
      abandonmentRate: (json['abandonment_rate'] as num?)?.toDouble() ??
          (json['abandonmentRate'] as num?)?.toDouble() ??
          0,
      totalClosedSessions: (json['total_closed_sessions'] as num?)?.toInt() ??
          (json['totalClosedSessions'] as num?)?.toInt() ??
          0,
    );
  }
}

class SupporterDashboardModel {
  const SupporterDashboardModel({
    required this.profile,
    required this.queue,
    required this.activeSessions,
    required this.recentSessions,
    required this.presence,
    required this.metrics,
    required this.openModerationAlerts,
  });

  final SupporterProfileModel profile;
  final List<QueueSnapshotModel> queue;
  final List<HumanSupportSessionModel> activeSessions;
  final List<HumanSupportSessionModel> recentSessions;
  final SupportPresenceModel presence;
  final SupportMetricsModel metrics;
  final int openModerationAlerts;

  factory SupporterDashboardModel.fromJson(Map<String, dynamic> json) {
    return SupporterDashboardModel(
      profile: SupporterProfileModel.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      queue: (json['queue'] as List? ?? const [])
          .map((item) => QueueSnapshotModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      activeSessions: (json['active_sessions'] as List? ??
              json['activeSessions'] as List? ??
              const [])
          .map((item) => HumanSupportSessionModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      recentSessions: (json['recent_sessions'] as List? ??
              json['recentSessions'] as List? ??
              const [])
          .map((item) => HumanSupportSessionModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      presence: SupportPresenceModel.fromJson(
        Map<String, dynamic>.from(json['presence'] as Map? ?? const {}),
      ),
      metrics: SupportMetricsModel.fromJson(
        Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
      ),
      openModerationAlerts: (json['open_moderation_alerts'] as num?)?.toInt() ??
          (json['openModerationAlerts'] as num?)?.toInt() ??
          0,
    );
  }
}

class AdminDashboardModel {
  const AdminDashboardModel({
    required this.queue,
    required this.activeSessions,
    required this.openReports,
    required this.moderationAlerts,
    required this.supporterPresence,
    required this.metrics,
  });

  final List<QueueSnapshotModel> queue;
  final List<HumanSupportSessionModel> activeSessions;
  final List<Map<String, dynamic>> openReports;
  final List<SupportModerationAlertModel> moderationAlerts;
  final List<SupportPresenceModel> supporterPresence;
  final SupportMetricsModel metrics;

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      queue: (json['queue'] as List? ?? const [])
          .map((item) => QueueSnapshotModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      activeSessions: (json['active_sessions'] as List? ??
              json['activeSessions'] as List? ??
              const [])
          .map((item) => HumanSupportSessionModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      openReports: (json['open_reports'] as List? ??
              json['openReports'] as List? ??
              const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      moderationAlerts: (json['moderation_alerts'] as List? ??
              json['moderationAlerts'] as List? ??
              const [])
          .map((item) => SupportModerationAlertModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      supporterPresence: (json['supporter_presence'] as List? ??
              json['supporterPresence'] as List? ??
              const [])
          .map((item) => SupportPresenceModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      metrics: SupportMetricsModel.fromJson(
        Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
      ),
    );
  }
}

class SupportRequestStatusModel {
  const SupportRequestStatusModel({
    required this.request,
    required this.activeSessionId,
  });

  final SupportRequestModel? request;
  final String? activeSessionId;

  factory SupportRequestStatusModel.fromJson(Map<String, dynamic> json) {
    final request = json['request'];
    return SupportRequestStatusModel(
      request: request is Map
          ? SupportRequestModel.fromJson(Map<String, dynamic>.from(request))
          : null,
      activeSessionId: (json['active_session_id'] as String?) ??
          (json['activeSessionId'] as String?),
    );
  }
}

class SupportRealtimeEventModel {
  const SupportRealtimeEventModel({
    required this.event,
    required this.payload,
  });

  final String event;
  final Map<String, dynamic> payload;

  String get normalizedEvent => event.trim().toUpperCase();

  factory SupportRealtimeEventModel.fromJson(Map<String, dynamic> json) {
    return SupportRealtimeEventModel(
      event: (json['event'] as String?) ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    );
  }
}
