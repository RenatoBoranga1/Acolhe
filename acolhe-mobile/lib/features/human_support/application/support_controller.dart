import 'dart:async';

import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/human_support/data/support_repository.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportState {
  const SupportState({
    required this.isLoading,
    required this.isSubmitting,
    required this.isSyncing,
    required this.connectionLabel,
    required this.isOtherParticipantTyping,
    required this.queue,
    required this.activeSupporterSessions,
    this.currentRequest,
    this.activeSession,
    this.supporterProfile,
    this.supporterDashboard,
    this.adminDashboard,
    this.selectedSupporterSession,
    this.latestModerationAlert,
    this.statusMessage,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isSyncing;
  final String connectionLabel;
  final bool isOtherParticipantTyping;
  final SupportRequestModel? currentRequest;
  final HumanSupportSessionModel? activeSession;
  final SupporterProfileModel? supporterProfile;
  final SupporterDashboardModel? supporterDashboard;
  final AdminDashboardModel? adminDashboard;
  final List<QueueSnapshotModel> queue;
  final List<HumanSupportSessionModel> activeSupporterSessions;
  final HumanSupportSessionModel? selectedSupporterSession;
  final SupportModerationAlertModel? latestModerationAlert;
  final String? statusMessage;
  final String? errorMessage;

  bool get hasActiveHumanSession => activeSession != null;
  bool get isWaitingInQueue =>
      currentRequest != null &&
      currentRequest!.isWaiting &&
      activeSession == null;

  SupportState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isSyncing,
    String? connectionLabel,
    bool? isOtherParticipantTyping,
    SupportRequestModel? currentRequest,
    HumanSupportSessionModel? activeSession,
    SupporterProfileModel? supporterProfile,
    SupporterDashboardModel? supporterDashboard,
    AdminDashboardModel? adminDashboard,
    List<QueueSnapshotModel>? queue,
    List<HumanSupportSessionModel>? activeSupporterSessions,
    HumanSupportSessionModel? selectedSupporterSession,
    SupportModerationAlertModel? latestModerationAlert,
    String? statusMessage,
    String? errorMessage,
    bool clearCurrentRequest = false,
    bool clearActiveSession = false,
    bool clearSelectedSupporterSession = false,
    bool clearStatusMessage = false,
    bool clearErrorMessage = false,
    bool clearSupporterDashboard = false,
    bool clearAdminDashboard = false,
    bool clearLatestModerationAlert = false,
  }) {
    return SupportState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSyncing: isSyncing ?? this.isSyncing,
      connectionLabel: connectionLabel ?? this.connectionLabel,
      isOtherParticipantTyping:
          isOtherParticipantTyping ?? this.isOtherParticipantTyping,
      currentRequest:
          clearCurrentRequest ? null : currentRequest ?? this.currentRequest,
      activeSession:
          clearActiveSession ? null : activeSession ?? this.activeSession,
      supporterProfile: supporterProfile ?? this.supporterProfile,
      supporterDashboard: clearSupporterDashboard
          ? null
          : supporterDashboard ?? this.supporterDashboard,
      adminDashboard:
          clearAdminDashboard ? null : adminDashboard ?? this.adminDashboard,
      queue: queue ?? this.queue,
      activeSupporterSessions:
          activeSupporterSessions ?? this.activeSupporterSessions,
      selectedSupporterSession: clearSelectedSupporterSession
          ? null
          : selectedSupporterSession ?? this.selectedSupporterSession,
      latestModerationAlert: clearLatestModerationAlert
          ? null
          : latestModerationAlert ?? this.latestModerationAlert,
      statusMessage:
          clearStatusMessage ? null : statusMessage ?? this.statusMessage,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  factory SupportState.initial() => const SupportState(
        isLoading: false,
        isSubmitting: false,
        isSyncing: false,
        connectionLabel: 'Modo offline seguro ativado',
        isOtherParticipantTyping: false,
        queue: [],
        activeSupporterSessions: [],
      );
}

final supportControllerProvider =
    StateNotifierProvider<SupportController, SupportState>((ref) {
  return SupportController(
    ref.read(supportRepositoryProvider),
    ref,
  );
});

class SupportController extends StateNotifier<SupportState> {
  SupportController(this._repository, this._ref)
      : super(SupportState.initial()) {
    unawaited(load());
  }

  final SupportRepository _repository;
  final Ref _ref;

  StreamSubscription<SupportRealtimeEventModel>? _userRealtimeSubscription;
  StreamSubscription<SupportRealtimeEventModel>? _sessionRealtimeSubscription;
  StreamSubscription<SupportRealtimeEventModel>? _dashboardRealtimeSubscription;
  Timer? _retryTimer;

  String? _sessionRealtimeKey;
  String? _dashboardRealtimeKey;

  @override
  void dispose() {
    _retryTimer?.cancel();
    unawaited(_userRealtimeSubscription?.cancel());
    unawaited(_sessionRealtimeSubscription?.cancel());
    unawaited(_dashboardRealtimeSubscription?.cancel());
    super.dispose();
  }

  Future<void> load() async {
    if (!_repository.isRemoteEnabled) {
      await _goOffline(
        message:
            'A Rede Acolhe precisa de conexao com o backend para colocar voce na fila de acolhimento humano.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isSyncing: true,
      connectionLabel: 'Sincronizando...',
      clearErrorMessage: true,
    );

    try {
      final status = await _repository.getCurrentSupportStatus();
      HumanSupportSessionModel? activeSession;
      if (status.activeSessionId != null) {
        activeSession =
            await _repository.getUserSession(status.activeSessionId!);
      }

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        currentRequest: status.request,
        activeSession: activeSession,
        isOtherParticipantTyping: false,
        connectionLabel: 'Conectado',
        clearStatusMessage: true,
        clearErrorMessage: true,
      );

      await _connectUserRealtime();
      if (activeSession != null) {
        await _connectSessionRealtime(
          sessionId: activeSession.id,
          actor: 'user',
        );
      } else {
        await _disconnectSessionRealtime();
      }
    } catch (_) {
      await _goOffline(
        message:
            'Nao consegui atualizar a Rede Acolhe agora. Voce pode continuar no chat com IA enquanto tentamos novamente.',
      );
      _scheduleReconnect(load);
    }
  }

  Future<bool> requestHumanSupport() async {
    if (!_repository.isRemoteEnabled) {
      state = state.copyWith(
        errorMessage:
            'A Rede Acolhe precisa de conexao para localizar uma pessoa disponivel.',
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearErrorMessage: true,
      clearStatusMessage: true,
    );

    try {
      final conversationId =
          _ref.read(chatControllerProvider).activeConversationId;
      final request = await _repository.createSupportRequest(
        conversationId: conversationId,
        requesterAlias: 'Pessoa atendida',
      );
      state = state.copyWith(
        isSubmitting: false,
        currentRequest: request,
        connectionLabel: 'Conectado',
        statusMessage:
            'Sua solicitacao entrou na fila da Rede Acolhe. Enquanto isso, o chat com IA continua disponivel.',
      );
      await _connectUserRealtime();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage:
            'Nao consegui colocar voce na fila agora. Tente novamente em instantes.',
      );
      return false;
    }
  }

  Future<bool> cancelCurrentRequest() async {
    final request = state.currentRequest;
    if (request == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.cancelSupportRequest(request.id);
      await _disconnectSessionRealtime();
      state = state.copyWith(
        isSubmitting: false,
        clearCurrentRequest: true,
        clearActiveSession: true,
        isOtherParticipantTyping: false,
        statusMessage: 'A solicitacao foi retirada da fila com seguranca.',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui retirar a solicitacao da fila agora.',
      );
      return false;
    }
  }

  Future<void> refreshUserSupport() async {
    if (!_repository.isRemoteEnabled) {
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      connectionLabel: 'Sincronizando...',
    );

    try {
      final status = await _repository.getCurrentSupportStatus();
      HumanSupportSessionModel? activeSession;
      if (status.activeSessionId != null) {
        activeSession =
            await _repository.getUserSession(status.activeSessionId!);
      }
      state = state.copyWith(
        isSyncing: false,
        connectionLabel: 'Conectado',
        currentRequest: status.request,
        activeSession: activeSession,
        clearErrorMessage: true,
      );
      await _connectUserRealtime();
      if (activeSession != null) {
        await _connectSessionRealtime(
            sessionId: activeSession.id, actor: 'user');
      } else {
        await _disconnectSessionRealtime();
      }
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        connectionLabel: 'Reconectando ao servico inteligente...',
      );
      _scheduleReconnect(refreshUserSupport);
    }
  }

  Future<void> openUserSession(String sessionId) async {
    state = state.copyWith(
      isLoading: true,
      isSyncing: true,
      clearErrorMessage: true,
    );
    try {
      final activeSession = await _repository.getUserSession(sessionId);
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        activeSession: activeSession,
        connectionLabel: 'Conectado',
      );
      await _connectSessionRealtime(sessionId: sessionId, actor: 'user');
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: 'Nao consegui abrir a conversa humana agora.',
      );
    }
  }

  Future<void> sendUserMessage(String text) async {
    final session = state.activeSession;
    if (session == null || text.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final message = await _repository.sendUserMessage(
        sessionId: session.id,
        content: text.trim(),
      );
      state = state.copyWith(
        isSubmitting: false,
        activeSession: _sessionWithAddedMessage(session, message),
        isOtherParticipantTyping: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui enviar a mensagem agora. Tente novamente.',
      );
    }
  }

  Future<bool> closeUserSession({
    String reason = 'Encerrado pela pessoa atendida',
  }) async {
    final session = state.activeSession;
    if (session == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.closeUserSession(sessionId: session.id, reason: reason);
      await _disconnectSessionRealtime();
      state = state.copyWith(
        isSubmitting: false,
        clearActiveSession: true,
        clearCurrentRequest: true,
        isOtherParticipantTyping: false,
        statusMessage:
            'A conversa humana foi encerrada. O chat com IA continua disponivel.',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui encerrar a sessao agora.',
      );
      return false;
    }
  }

  Future<bool> reportSupporter({
    required String sessionId,
    required String reason,
    String? description,
  }) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.reportSupporter(
        sessionId: sessionId,
        reason: reason,
        description: description,
      );
      state = state.copyWith(
        isSubmitting: false,
        statusMessage:
            'A denuncia foi registrada para revisao segura da moderacao.',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui registrar a denuncia agora.',
      );
      return false;
    }
  }

  Future<bool> acknowledgeGuidelines() async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final profile = await _repository.acknowledgeGuidelines();
      state = state.copyWith(
        isSubmitting: false,
        supporterProfile: profile,
        statusMessage: 'Diretrizes aceitas. Agora voce pode ficar disponivel.',
      );
      await loadSupporterDashboard();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui registrar o aceite das diretrizes.',
      );
      return false;
    }
  }

  Future<void> loadSupporterDashboard() async {
    if (!_repository.isRemoteEnabled) {
      state = state.copyWith(
        errorMessage:
            'O painel da Rede Acolhe precisa de conexao com o backend.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isSyncing: true,
      clearErrorMessage: true,
      connectionLabel: 'Sincronizando...',
    );
    try {
      final dashboard = await _repository.getSupporterDashboard();
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        supporterDashboard: dashboard,
        supporterProfile: dashboard.profile,
        queue: dashboard.queue,
        activeSupporterSessions: dashboard.activeSessions,
        connectionLabel: 'Conectado',
      );
      await _connectDashboardRealtime(role: dashboard.profile.roleType.name);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: 'Nao consegui atualizar a fila da Rede Acolhe agora.',
      );
      _scheduleReconnect(loadSupporterDashboard);
    }
  }

  Future<void> loadAdminDashboard() async {
    if (!_repository.isRemoteEnabled) {
      state = state.copyWith(
        errorMessage:
            'O painel administrativo precisa de conexao com o backend.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isSyncing: true,
      clearErrorMessage: true,
      connectionLabel: 'Sincronizando...',
    );
    try {
      final dashboard = await _repository.getAdminDashboard();
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        adminDashboard: dashboard,
        queue: dashboard.queue,
        activeSupporterSessions: dashboard.activeSessions,
        latestModerationAlert: dashboard.moderationAlerts.isEmpty
            ? null
            : dashboard.moderationAlerts.first,
        connectionLabel: 'Conectado',
      );
      await _connectDashboardRealtime(role: 'admin');
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: 'Nao consegui atualizar o painel administrativo agora.',
      );
      _scheduleReconnect(loadAdminDashboard);
    }
  }

  Future<void> updateAvailability(bool isAvailable) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final profile = await _repository.updateSupporterStatus(
        isAvailable: isAvailable,
      );
      state = state.copyWith(
        isSubmitting: false,
        supporterProfile: profile,
        statusMessage: isAvailable
            ? 'Voce ficou disponivel na fila.'
            : 'Voce ficou offline.',
      );
      await loadSupporterDashboard();
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui atualizar sua disponibilidade agora.',
      );
    }
  }

  Future<HumanSupportSessionModel?> acceptRequest(String requestId) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final session = await _repository.acceptSupportRequest(requestId);
      state = state.copyWith(
        isSubmitting: false,
        selectedSupporterSession: session,
        statusMessage: 'Atendimento assumido com seguranca.',
      );
      await _connectSessionRealtime(sessionId: session.id, actor: 'supporter');
      await loadSupporterDashboard();
      return session;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui assumir esse atendimento agora.',
      );
      return null;
    }
  }

  Future<void> openSupporterSession(String sessionId) async {
    state = state.copyWith(
      isLoading: true,
      isSyncing: true,
      clearErrorMessage: true,
    );
    try {
      final session = await _repository.getSupporterSession(sessionId);
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        selectedSupporterSession: session,
        connectionLabel: 'Conectado',
      );
      await _connectSessionRealtime(sessionId: sessionId, actor: 'supporter');
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: 'Nao consegui abrir a sessao agora.',
      );
    }
  }

  Future<void> sendSupporterMessage(String text) async {
    final session = state.selectedSupporterSession;
    if (session == null || text.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final message = await _repository.sendSupporterMessage(
        sessionId: session.id,
        content: text.trim(),
      );
      state = state.copyWith(
        isSubmitting: false,
        selectedSupporterSession: _sessionWithAddedMessage(session, message),
        isOtherParticipantTyping: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui enviar a mensagem ao atendimento.',
      );
    }
  }

  Future<bool> transferSupporterSession({
    required String sessionId,
    required String reason,
    String? targetSpecialty,
  }) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.transferSession(
        sessionId: sessionId,
        reason: reason,
        targetSpecialty: targetSpecialty,
      );
      await _disconnectSessionRealtime();
      state = state.copyWith(
        isSubmitting: false,
        clearSelectedSupporterSession: true,
        isOtherParticipantTyping: false,
        statusMessage: 'Sessao transferida com rastreabilidade segura.',
      );
      await loadSupporterDashboard();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui transferir a sessao agora.',
      );
      return false;
    }
  }

  Future<bool> closeSupporterSession({
    required String sessionId,
    required String reason,
  }) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.closeSupporterSession(
        sessionId: sessionId,
        reason: reason,
      );
      await _disconnectSessionRealtime();
      state = state.copyWith(
        isSubmitting: false,
        clearSelectedSupporterSession: true,
        isOtherParticipantTyping: false,
        statusMessage: 'Atendimento encerrado com auditoria segura.',
      );
      await loadSupporterDashboard();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui encerrar a sessao agora.',
      );
      return false;
    }
  }

  Future<void> _connectUserRealtime({String? userId}) async {
    if (!_repository.isRealtimeEnabled) {
      return;
    }

    await _userRealtimeSubscription?.cancel();
    _userRealtimeSubscription = _repository.userEvents(userId: userId).listen(
      _handleUserRealtimeEvent,
      onError: (_) {
        state = state.copyWith(
          connectionLabel: 'Reconectando ao servico inteligente...',
        );
        _scheduleReconnect(() => _connectUserRealtime(userId: userId));
      },
    );
  }

  Future<void> _connectSessionRealtime({
    required String sessionId,
    required String actor,
    String? userId,
  }) async {
    if (!_repository.isRealtimeEnabled) {
      return;
    }

    final realtimeKey = '$actor:$sessionId:${userId ?? ''}';
    if (_sessionRealtimeKey == realtimeKey &&
        _sessionRealtimeSubscription != null) {
      return;
    }

    await _sessionRealtimeSubscription?.cancel();
    _sessionRealtimeKey = realtimeKey;
    _sessionRealtimeSubscription = _repository
        .sessionEvents(sessionId: sessionId, actor: actor, userId: userId)
        .listen(
      (event) =>
          _handleSessionRealtimeEvent(event, supporterView: actor != 'user'),
      onError: (_) {
        state = state.copyWith(
          connectionLabel: 'Reconectando ao servico inteligente...',
        );
        _scheduleReconnect(() => _connectSessionRealtime(
              sessionId: sessionId,
              actor: actor,
              userId: userId,
            ));
      },
    );
  }

  Future<void> _connectDashboardRealtime({
    required String role,
    String? userId,
  }) async {
    if (!_repository.isRealtimeEnabled) {
      return;
    }

    final realtimeKey = '$role:${userId ?? ''}';
    if (_dashboardRealtimeKey == realtimeKey &&
        _dashboardRealtimeSubscription != null) {
      return;
    }

    await _dashboardRealtimeSubscription?.cancel();
    _dashboardRealtimeKey = realtimeKey;
    _dashboardRealtimeSubscription =
        _repository.dashboardEvents(role: role, userId: userId).listen(
      (event) => _handleDashboardRealtimeEvent(event, role: role),
      onError: (_) {
        state = state.copyWith(
          connectionLabel: 'Reconectando ao servico inteligente...',
        );
        _scheduleReconnect(
          () => _connectDashboardRealtime(role: role, userId: userId),
        );
      },
    );
  }

  Future<void> _disconnectSessionRealtime() async {
    _sessionRealtimeKey = null;
    await _sessionRealtimeSubscription?.cancel();
    _sessionRealtimeSubscription = null;
  }

  void _handleUserRealtimeEvent(SupportRealtimeEventModel event) {
    switch (event.normalizedEvent) {
      case 'REQUEST_UPDATED':
        final status = SupportRequestStatusModel.fromJson(event.payload);
        state = state.copyWith(
          currentRequest: status.request,
          clearCurrentRequest: status.request == null,
          connectionLabel: 'Conectado',
          isSyncing: false,
          clearErrorMessage: true,
        );
        if (status.activeSessionId != null &&
            state.activeSession?.id != status.activeSessionId) {
          unawaited(openUserSession(status.activeSessionId!));
        }
        if (status.activeSessionId == null && state.activeSession != null) {
          state = state.copyWith(
            clearActiveSession: true,
            isOtherParticipantTyping: false,
          );
          unawaited(_disconnectSessionRealtime());
        }
        break;
      case 'SESSION_ASSIGNED':
        final session = HumanSupportSessionModel.fromJson(event.payload);
        state = state.copyWith(
          activeSession: session,
          connectionLabel: 'Conectado',
          statusMessage: 'Uma pessoa da Rede Acolhe entrou na sua conversa.',
        );
        unawaited(
            _connectSessionRealtime(sessionId: session.id, actor: 'user'));
        break;
      default:
        break;
    }
  }

  void _handleSessionRealtimeEvent(
    SupportRealtimeEventModel event, {
    required bool supporterView,
  }) {
    switch (event.normalizedEvent) {
      case 'SESSION_SNAPSHOT':
        final session = HumanSupportSessionModel.fromJson(event.payload);
        state = state.copyWith(
          connectionLabel: 'Conectado',
          isSyncing: false,
          isOtherParticipantTyping: false,
          clearErrorMessage: true,
          activeSession: supporterView ? state.activeSession : session,
          selectedSupporterSession:
              supporterView ? session : state.selectedSupporterSession,
        );
        break;
      case 'MESSAGE_RECEIVED':
        final message = HumanSupportMessageModel.fromJson(event.payload);
        if (supporterView) {
          final session = state.selectedSupporterSession;
          if (session != null) {
            state = state.copyWith(
              selectedSupporterSession:
                  _sessionWithAddedMessage(session, message),
            );
          }
        } else {
          final session = state.activeSession;
          if (session != null) {
            state = state.copyWith(
              activeSession: _sessionWithAddedMessage(session, message),
            );
          }
        }
        break;
      case 'SUPPORTER_TYPING':
        if (!supporterView) {
          state = state.copyWith(
            isOtherParticipantTyping: event.payload['is_typing'] == true,
          );
        }
        break;
      case 'USER_TYPING':
        if (supporterView) {
          state = state.copyWith(
            isOtherParticipantTyping: event.payload['is_typing'] == true,
          );
        }
        break;
      case 'SESSION_CLOSED':
        state = state.copyWith(
          isOtherParticipantTyping: false,
          statusMessage: supporterView
              ? 'A sessao foi encerrada.'
              : 'A conversa humana foi encerrada.',
          clearSelectedSupporterSession: supporterView,
          clearActiveSession: !supporterView,
        );
        unawaited(_disconnectSessionRealtime());
        if (supporterView) {
          unawaited(loadSupporterDashboard());
        } else {
          unawaited(refreshUserSupport());
        }
        break;
      case 'SESSION_TRANSFERRED':
        state = state.copyWith(
          isOtherParticipantTyping: false,
          statusMessage:
              'Esta conversa foi encaminhada para a fila apropriada da Rede Acolhe.',
          clearSelectedSupporterSession: supporterView,
        );
        unawaited(_disconnectSessionRealtime());
        if (supporterView) {
          unawaited(loadSupporterDashboard());
        } else {
          unawaited(refreshUserSupport());
        }
        break;
      default:
        break;
    }
  }

  void _handleDashboardRealtimeEvent(
    SupportRealtimeEventModel event, {
    required String role,
  }) {
    switch (event.normalizedEvent) {
      case 'DASHBOARD_SNAPSHOT':
        if (role == 'admin') {
          final dashboard = AdminDashboardModel.fromJson(event.payload);
          state = state.copyWith(
            adminDashboard: dashboard,
            queue: dashboard.queue,
            activeSupporterSessions: dashboard.activeSessions,
            latestModerationAlert: dashboard.moderationAlerts.isEmpty
                ? state.latestModerationAlert
                : dashboard.moderationAlerts.first,
            connectionLabel: 'Conectado',
            isSyncing: false,
            clearErrorMessage: true,
          );
        } else {
          final dashboard = SupporterDashboardModel.fromJson(event.payload);
          state = state.copyWith(
            supporterDashboard: dashboard,
            supporterProfile: dashboard.profile,
            queue: dashboard.queue,
            activeSupporterSessions: dashboard.activeSessions,
            connectionLabel: 'Conectado',
            isSyncing: false,
            clearErrorMessage: true,
          );
        }
        break;
      case 'MODERATION_ALERT':
        final alert = SupportModerationAlertModel.fromJson(event.payload);
        state = state.copyWith(
          latestModerationAlert: alert,
          statusMessage:
              'A moderacao recebeu um alerta para revisar um atendimento recente.',
        );
        break;
      default:
        break;
    }
  }

  HumanSupportSessionModel _sessionWithAddedMessage(
    HumanSupportSessionModel session,
    HumanSupportMessageModel message,
  ) {
    final alreadyExists = session.messages.any((item) => item.id == message.id);
    if (alreadyExists) {
      return session;
    }
    return HumanSupportSessionModel(
      id: session.id,
      supportRequestId: session.supportRequestId,
      userId: session.userId,
      supporterId: session.supporterId,
      status: session.status,
      messages: [...session.messages, message],
      copilotSuggestions: session.copilotSuggestions,
      supporterReminders: session.supporterReminders,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      closeReason: session.closeReason,
      supporterProfile: session.supporterProfile,
      safeSummary: session.safeSummary,
    );
  }

  void _scheduleReconnect(Future<void> Function() callback) {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      unawaited(callback());
    });
  }

  Future<void> _goOffline({required String message}) async {
    _retryTimer?.cancel();
    await _disconnectSessionRealtime();
    await _userRealtimeSubscription?.cancel();
    _userRealtimeSubscription = null;
    await _dashboardRealtimeSubscription?.cancel();
    _dashboardRealtimeSubscription = null;
    _dashboardRealtimeKey = null;
    state = state.copyWith(
      isLoading: false,
      isSubmitting: false,
      isSyncing: false,
      connectionLabel: 'Modo offline seguro ativado',
      isOtherParticipantTyping: false,
      statusMessage: message,
    );
  }
}
