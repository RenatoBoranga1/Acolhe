import 'dart:async';

import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/human_support/data/support_repository.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportState {
  const SupportState({
    required this.isLoading,
    required this.isSubmitting,
    required this.isPolling,
    required this.connectionLabel,
    required this.queue,
    required this.activeSupporterSessions,
    this.currentRequest,
    this.activeSession,
    this.supporterProfile,
    this.selectedSupporterSession,
    this.statusMessage,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isPolling;
  final String connectionLabel;
  final SupportRequestModel? currentRequest;
  final HumanSupportSessionModel? activeSession;
  final SupporterProfileModel? supporterProfile;
  final List<QueueSnapshotModel> queue;
  final List<HumanSupportSessionModel> activeSupporterSessions;
  final HumanSupportSessionModel? selectedSupporterSession;
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
    bool? isPolling,
    String? connectionLabel,
    SupportRequestModel? currentRequest,
    HumanSupportSessionModel? activeSession,
    SupporterProfileModel? supporterProfile,
    List<QueueSnapshotModel>? queue,
    List<HumanSupportSessionModel>? activeSupporterSessions,
    HumanSupportSessionModel? selectedSupporterSession,
    String? statusMessage,
    String? errorMessage,
    bool clearCurrentRequest = false,
    bool clearActiveSession = false,
    bool clearSelectedSupporterSession = false,
    bool clearStatusMessage = false,
    bool clearErrorMessage = false,
  }) {
    return SupportState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isPolling: isPolling ?? this.isPolling,
      connectionLabel: connectionLabel ?? this.connectionLabel,
      currentRequest:
          clearCurrentRequest ? null : currentRequest ?? this.currentRequest,
      activeSession:
          clearActiveSession ? null : activeSession ?? this.activeSession,
      supporterProfile: supporterProfile ?? this.supporterProfile,
      queue: queue ?? this.queue,
      activeSupporterSessions:
          activeSupporterSessions ?? this.activeSupporterSessions,
      selectedSupporterSession: clearSelectedSupporterSession
          ? null
          : selectedSupporterSession ?? this.selectedSupporterSession,
      statusMessage:
          clearStatusMessage ? null : statusMessage ?? this.statusMessage,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  factory SupportState.initial() => const SupportState(
        isLoading: false,
        isSubmitting: false,
        isPolling: false,
        connectionLabel: 'Modo offline seguro ativado',
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
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool startPolling = true}) async {
    if (!_repository.isRemoteEnabled) {
      _pollingTimer?.cancel();
      state = state.copyWith(
        connectionLabel: 'Modo offline seguro ativado',
        statusMessage:
            'A Rede Acolhe precisa de conexao com o backend para colocar voce na fila de acolhimento humano.',
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      connectionLabel: 'Conectado',
      clearErrorMessage: true,
    );
    try {
      final currentRequest = await _repository.getCurrentSupportRequest();
      HumanSupportSessionModel? activeSession;
      if (currentRequest?.sessionId != null) {
        activeSession =
            await _repository.getUserSession(currentRequest!.sessionId!);
      }
      state = state.copyWith(
        isLoading: false,
        currentRequest: currentRequest,
        activeSession: activeSession,
        clearStatusMessage: true,
      );
      if (startPolling) {
        _ensurePollingActive();
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        connectionLabel: 'Modo offline seguro ativado',
        errorMessage:
            'Nao consegui atualizar a Rede Acolhe agora. Voce pode continuar no chat com IA enquanto tentamos novamente.',
      );
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
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
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
        statusMessage:
            'Sua solicitacao entrou na fila da Rede Acolhe. Enquanto isso, o chat com IA continua disponivel.',
      );
      _ensurePollingActive();
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
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
      _pollingTimer?.cancel();
      state = state.copyWith(
        isSubmitting: false,
        clearCurrentRequest: true,
        clearActiveSession: true,
        statusMessage: 'A solicitacao foi retirada da fila com seguranca.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> refreshUserSupport() async {
    if (!_repository.isRemoteEnabled) {
      return;
    }
    try {
      final currentRequest = await _repository.getCurrentSupportRequest();
      HumanSupportSessionModel? activeSession;
      if (currentRequest?.sessionId != null) {
        activeSession =
            await _repository.getUserSession(currentRequest!.sessionId!);
      }
      state = state.copyWith(
        currentRequest: currentRequest,
        activeSession: activeSession,
        isPolling: false,
        connectionLabel: 'Conectado',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isPolling: false,
        connectionLabel: 'Reconectando ao servico inteligente...',
      );
    }
  }

  Future<void> openUserSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final activeSession = await _repository.getUserSession(sessionId);
      state = state.copyWith(
        isLoading: false,
        activeSession: activeSession,
        connectionLabel: 'Conectado',
      );
      _ensurePollingActive();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
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
      await _repository.sendUserMessage(
          sessionId: session.id, content: text.trim());
      final refreshed = await _repository.getUserSession(session.id);
      state = state.copyWith(
        isSubmitting: false,
        activeSession: refreshed,
        clearStatusMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui enviar a mensagem agora. Tente novamente.',
      );
    }
  }

  Future<bool> closeUserSession(
      {String reason = 'Encerrado pela pessoa atendida'}) async {
    final session = state.activeSession;
    if (session == null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _repository.closeUserSession(sessionId: session.id, reason: reason);
      _pollingTimer?.cancel();
      state = state.copyWith(
        isSubmitting: false,
        clearActiveSession: true,
        clearCurrentRequest: true,
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
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Nao consegui registrar o aceite das diretrizes.',
      );
      return false;
    }
  }

  Future<void> loadSupporterDashboard({bool startPolling = true}) async {
    if (!_repository.isRemoteEnabled) {
      state = state.copyWith(
        errorMessage:
            'O painel da Rede Acolhe precisa de conexao com o backend.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final profile = await _repository.getSupporterProfile();
      final queue = await _repository.getSupporterQueue();
      final sessions = await _repository.getActiveSupporterSessions();
      state = state.copyWith(
        isLoading: false,
        supporterProfile: profile,
        queue: queue,
        activeSupporterSessions: sessions,
        connectionLabel: 'Conectado',
      );
      if (startPolling) {
        _ensurePollingActive();
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nao consegui atualizar a fila da Rede Acolhe agora.',
      );
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
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
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
      await loadSupporterDashboard();
      return session;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<void> openSupporterSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final session = await _repository.getSupporterSession(sessionId);
      state = state.copyWith(
        isLoading: false,
        selectedSupporterSession: session,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
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
      await _repository.sendSupporterMessage(
        sessionId: session.id,
        content: text.trim(),
      );
      final refreshed = await _repository.getSupporterSession(session.id);
      state = state.copyWith(
        isSubmitting: false,
        selectedSupporterSession: refreshed,
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
      state = state.copyWith(
        isSubmitting: false,
        clearSelectedSupporterSession: true,
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
      state = state.copyWith(
        isSubmitting: false,
        clearSelectedSupporterSession: true,
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

  void _ensurePollingActive() {
    if (_pollingTimer?.isActive ?? false) {
      return;
    }
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      state = state.copyWith(isPolling: true);
      if (state.selectedSupporterSession != null) {
        await openSupporterSession(state.selectedSupporterSession!.id);
        return;
      }
      if (state.currentRequest != null || state.activeSession != null) {
        await refreshUserSupport();
        return;
      }
      if (state.queue.isNotEmpty || state.activeSupporterSessions.isNotEmpty) {
        await loadSupporterDashboard(startPolling: false);
      } else {
        state = state.copyWith(isPolling: false);
      }
    });
  }
}
