import 'package:acolhe_mobile/features/human_support/data/support_api_client.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.read(supportApiClientProvider));
});

class SupportRepository {
  const SupportRepository(this._apiClient);

  final SupportApiClient _apiClient;

  bool get isRemoteEnabled => _apiClient.isEnabled;

  Future<SupportRequestModel> createSupportRequest({
    required String? conversationId,
    required String requesterAlias,
  }) {
    return _apiClient.createSupportRequest(
      conversationId: conversationId,
      requesterAlias: requesterAlias,
    );
  }

  Future<SupportRequestModel?> getCurrentSupportRequest() {
    return _apiClient.getCurrentSupportRequest();
  }

  Future<String?> getCurrentSessionId() {
    return _apiClient.getCurrentSessionId();
  }

  Future<void> cancelSupportRequest(String requestId) {
    return _apiClient.cancelSupportRequest(requestId);
  }

  Future<HumanSupportSessionModel> getUserSession(String sessionId) {
    return _apiClient.getUserSession(sessionId);
  }

  Future<HumanSupportMessageModel> sendUserMessage({
    required String sessionId,
    required String content,
  }) {
    return _apiClient.sendUserMessage(sessionId: sessionId, content: content);
  }

  Future<void> closeUserSession({
    required String sessionId,
    required String reason,
  }) {
    return _apiClient.closeUserSession(sessionId: sessionId, reason: reason);
  }

  Future<void> reportSupporter({
    required String sessionId,
    required String reason,
    String? description,
  }) {
    return _apiClient.reportSupporter(
      sessionId: sessionId,
      reason: reason,
      description: description,
    );
  }

  Future<SupporterProfileModel> acknowledgeGuidelines() {
    return _apiClient.acknowledgeGuidelines();
  }

  Future<SupporterProfileModel> getSupporterProfile() {
    return _apiClient.getSupporterProfile();
  }

  Future<SupporterProfileModel> updateSupporterStatus({
    required bool isAvailable,
    int maxActiveSessions = 2,
  }) {
    return _apiClient.updateSupporterStatus(
      isAvailable: isAvailable,
      maxActiveSessions: maxActiveSessions,
    );
  }

  Future<List<QueueSnapshotModel>> getSupporterQueue() {
    return _apiClient.getSupporterQueue();
  }

  Future<HumanSupportSessionModel> acceptSupportRequest(String requestId) {
    return _apiClient.acceptSupportRequest(requestId);
  }

  Future<List<HumanSupportSessionModel>> getActiveSupporterSessions() {
    return _apiClient.getActiveSupporterSessions();
  }

  Future<HumanSupportSessionModel> getSupporterSession(String sessionId) {
    return _apiClient.getSupporterSession(sessionId);
  }

  Future<HumanSupportMessageModel> sendSupporterMessage({
    required String sessionId,
    required String content,
  }) {
    return _apiClient.sendSupporterMessage(
      sessionId: sessionId,
      content: content,
    );
  }

  Future<void> transferSession({
    required String sessionId,
    required String reason,
    String? targetSpecialty,
  }) {
    return _apiClient.transferSession(
      sessionId: sessionId,
      reason: reason,
      targetSpecialty: targetSpecialty,
    );
  }

  Future<void> closeSupporterSession({
    required String sessionId,
    required String reason,
  }) {
    return _apiClient.closeSupporterSession(
      sessionId: sessionId,
      reason: reason,
    );
  }
}
