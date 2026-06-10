import 'dart:async';
import 'dart:convert';

import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/core/config/backend_config.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final supportApiClientProvider = Provider<SupportApiClient>((ref) {
  final effectiveBaseUrl = ref
      .watch(backendConfigProvider.select((state) => state.effectiveBaseUrl));
  final apiBaseUrl = ApiConfig(
    baseUrl: ApiConfig.normalizeBaseUrl(effectiveBaseUrl),
    environment: AppEnvironment.current,
    source: ApiEndpointSource.none,
  ).versionedApiBaseUrl;
  return SupportApiClient(
    ref.read(backendHttpClientProvider),
    apiBaseUrl: apiBaseUrl,
  );
});

class SupportApiException implements Exception {
  const SupportApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SupportApiException($statusCode): $message';
}

class SupportApiClient {
  SupportApiClient(
    this._client, {
    required String apiBaseUrl,
    this.timeout = const Duration(seconds: 24),
  }) : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final Duration timeout;
  final String _apiBaseUrl;

  bool get isEnabled => _apiBaseUrl.isNotEmpty;

  Future<SupportRequestModel> createSupportRequest({
    required String? conversationId,
    required String requesterAlias,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/support/request'),
        headers: _headers,
        body: jsonEncode({
          'conversation_id': conversationId,
          'consent_to_human_handoff': true,
          'requester_alias': requesterAlias,
        }),
      ),
    );
    return SupportRequestModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SupportRequestModel?> getCurrentSupportRequest() async {
    final status = await getCurrentSupportStatus();
    return status.request;
  }

  Future<SupportRequestStatusModel> getCurrentSupportStatus() async {
    final response = await _send(
      () => _client.get(_uri('/support/request/current'), headers: _headers),
    );
    return SupportRequestStatusModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String?> getCurrentSessionId() async {
    final status = await getCurrentSupportStatus();
    return status.activeSessionId;
  }

  Future<void> cancelSupportRequest(String requestId) async {
    await _send(
      () => _client.post(
        _uri('/support/request/$requestId/cancel'),
        headers: _headers,
      ),
    );
  }

  Future<HumanSupportSessionModel> getUserSession(String sessionId) async {
    final response = await _send(
      () => _client.get(_uri('/support/session/$sessionId'), headers: _headers),
    );
    return HumanSupportSessionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<HumanSupportMessageModel> sendUserMessage({
    required String sessionId,
    required String content,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/support/session/$sessionId/messages'),
        headers: _headers,
        body: jsonEncode({'content': content}),
      ),
    );
    return HumanSupportMessageModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> closeUserSession({
    required String sessionId,
    required String reason,
  }) async {
    await _send(
      () => _client.post(
        _uri('/support/session/$sessionId/close'),
        headers: _headers,
        body: jsonEncode({'reason': reason}),
      ),
    );
  }

  Future<void> reportSupporter({
    required String sessionId,
    required String reason,
    String? description,
  }) async {
    await _send(
      () => _client.post(
        _uri('/support/session/$sessionId/report'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        }),
      ),
    );
  }

  Future<SupporterProfileModel> acknowledgeGuidelines() async {
    final response = await _send(
      () => _client.post(
        _uri('/supporter/guidelines/acknowledge'),
        headers: _headers,
      ),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return SupporterProfileModel.fromJson(
      Map<String, dynamic>.from(decoded['profile'] as Map),
    );
  }

  Future<SupporterProfileModel> getSupporterProfile() async {
    final response = await _send(
      () => _client.get(_uri('/supporter/profile'), headers: _headers),
    );
    return SupporterProfileModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SupporterProfileModel> updateSupporterStatus({
    required bool isAvailable,
    int maxActiveSessions = 2,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/supporter/status'),
        headers: _headers,
        body: jsonEncode({
          'is_available': isAvailable,
          'max_active_sessions': maxActiveSessions,
        }),
      ),
    );
    return SupporterProfileModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<QueueSnapshotModel>> getSupporterQueue() async {
    final response = await _send(
      () => _client.get(_uri('/supporter/queue'), headers: _headers),
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => QueueSnapshotModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<SupporterDashboardModel> getSupporterDashboard() async {
    final response = await _send(
      () => _client.get(_uri('/supporter/dashboard'), headers: _headers),
    );
    return SupporterDashboardModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminDashboardModel> getAdminDashboard() async {
    final response = await _send(
      () => _client.get(_uri('/admin/support/dashboard'), headers: _headers),
    );
    return AdminDashboardModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SupportModerationAlertModel>> getModerationAlerts() async {
    final response = await _send(
      () => _client.get(
        _uri('/admin/support/moderation-alerts'),
        headers: _headers,
      ),
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => SupportModerationAlertModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<HumanSupportSessionModel> acceptSupportRequest(
      String requestId) async {
    final response = await _send(
      () => _client.post(
        _uri('/supporter/request/$requestId/accept'),
        headers: _headers,
      ),
    );
    return HumanSupportSessionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<HumanSupportSessionModel>> getActiveSupporterSessions() async {
    final response = await _send(
      () => _client.get(_uri('/supporter/sessions/active'), headers: _headers),
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => HumanSupportSessionModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<HumanSupportSessionModel> getSupporterSession(String sessionId) async {
    final response = await _send(
      () =>
          _client.get(_uri('/supporter/session/$sessionId'), headers: _headers),
    );
    return HumanSupportSessionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<HumanSupportMessageModel> sendSupporterMessage({
    required String sessionId,
    required String content,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/supporter/session/$sessionId/messages'),
        headers: _headers,
        body: jsonEncode({'content': content}),
      ),
    );
    return HumanSupportMessageModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> transferSession({
    required String sessionId,
    required String reason,
    String? targetSpecialty,
  }) async {
    await _send(
      () => _client.post(
        _uri('/supporter/session/$sessionId/transfer'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
          if (targetSpecialty != null && targetSpecialty.trim().isNotEmpty)
            'target_specialty': targetSpecialty.trim(),
        }),
      ),
    );
  }

  Future<void> closeSupporterSession({
    required String sessionId,
    required String reason,
  }) async {
    await _send(
      () => _client.post(
        _uri('/supporter/session/$sessionId/close'),
        headers: _headers,
        body: jsonEncode({'reason': reason}),
      ),
    );
  }

  Uri _uri(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    if (!isEnabled) {
      throw const SupportApiException(
        'O servico humano ainda nao esta disponivel nesta conexao.',
      );
    }
    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const SupportApiException(
        'A conexao com a Rede Acolhe demorou mais do que o esperado.',
      );
    } on Object catch (error) {
      throw SupportApiException('Falha ao conectar com a Rede Acolhe: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupportApiException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on Object {
      // Keep generic safe error below.
    }
    return 'A Rede Acolhe retornou status ${response.statusCode}.';
  }

  static Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
