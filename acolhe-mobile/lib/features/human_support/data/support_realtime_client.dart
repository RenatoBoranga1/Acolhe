import 'dart:async';
import 'dart:convert';

import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/core/config/backend_config.dart';
import 'package:acolhe_mobile/features/human_support/data/realtime/platform_web_socket.dart';
import 'package:acolhe_mobile/features/human_support/data/realtime/platform_web_socket_interface.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportRealtimeClientProvider = Provider<SupportRealtimeClient>((ref) {
  final effectiveBaseUrl = ref
      .watch(backendConfigProvider.select((state) => state.effectiveBaseUrl));
  final apiBaseUrl = ApiConfig(
    baseUrl: ApiConfig.normalizeBaseUrl(effectiveBaseUrl),
    environment: AppEnvironment.current,
    source: ApiEndpointSource.none,
  ).versionedApiBaseUrl;
  return SupportRealtimeClient(apiBaseUrl: apiBaseUrl);
});

class SupportRealtimeException implements Exception {
  const SupportRealtimeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupportRealtimeClient {
  SupportRealtimeClient({
    required String apiBaseUrl,
  }) : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  final String _apiBaseUrl;

  bool get isEnabled => _apiBaseUrl.isNotEmpty;

  Stream<SupportRealtimeEventModel> connectUser({String? userId}) {
    return _connect(
      '/ws/support/user',
      queryParameters: {
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
      },
    );
  }

  Stream<SupportRealtimeEventModel> connectSession({
    required String sessionId,
    required String actor,
    String? userId,
  }) {
    return _connect(
      '/ws/support/session/$sessionId',
      queryParameters: {
        'actor': actor,
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
      },
    );
  }

  Stream<SupportRealtimeEventModel> connectDashboard({
    required String role,
    String? userId,
  }) {
    return _connect(
      '/ws/support/dashboard',
      queryParameters: {
        'role': role,
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
      },
    );
  }

  Stream<SupportRealtimeEventModel> _connect(
    String path, {
    Map<String, String> queryParameters = const {},
  }) {
    if (!isEnabled) {
      return Stream<SupportRealtimeEventModel>.error(
        const SupportRealtimeException(
          'Realtime indisponivel para a Rede Acolhe nesta conexao.',
        ),
      );
    }

    final controller = StreamController<SupportRealtimeEventModel>();
    PlatformWebSocketConnection? socket;
    StreamSubscription<String>? messageSubscription;

    controller.onListen = () async {
      try {
        socket = await connectPlatformWebSocket(
          _webSocketUri(path, queryParameters: queryParameters),
        );
        messageSubscription = socket!.messages.listen(
          (rawMessage) {
            try {
              final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
              controller.add(SupportRealtimeEventModel.fromJson(decoded));
            } on Object catch (error) {
              controller.addError(
                SupportRealtimeException(
                  'Nao foi possivel interpretar uma atualizacao da Rede Acolhe: $error',
                ),
              );
            }
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: false,
        );
      } on Object catch (error) {
        controller.addError(
          SupportRealtimeException(
            'Nao foi possivel conectar ao canal da Rede Acolhe: $error',
          ),
        );
        await controller.close();
      }
    };

    controller.onCancel = () async {
      await messageSubscription?.cancel();
      await socket?.close();
    };

    return controller.stream;
  }

  Uri _webSocketUri(
    String path, {
    Map<String, String> queryParameters = const {},
  }) {
    final baseUri = Uri.parse('$_apiBaseUrl$path');
    return baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
}
