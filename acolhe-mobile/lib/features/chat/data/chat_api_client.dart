import 'dart:async';
import 'dart:convert';

import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/core/config/backend_config.dart';
import 'package:acolhe_mobile/features/chat/data/chat_dtos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final chatHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final chatApiClientProvider = Provider<ChatApiClient>((ref) {
  final effectiveBaseUrl = ref
      .watch(backendConfigProvider.select((state) => state.effectiveBaseUrl));
  return ChatApiClient(
    ref.read(chatHttpClientProvider),
    apiBaseUrl: effectiveBaseUrl,
  );
});

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ChatApiException($statusCode): $message';
}

class ChatApiClient {
  ChatApiClient(
    this._client, {
    String? apiBaseUrl,
    this.timeout = const Duration(seconds: 24),
  }) : _chatBaseUrl =
            _resolveChatBaseUrl(apiBaseUrl ?? AppEnvironment.apiBaseUrl);

  final http.Client _client;
  final Duration timeout;
  final String _chatBaseUrl;

  bool get isEnabled => _chatBaseUrl.isNotEmpty;

  Future<List<ConversationDto>> listConversations() async {
    final response = await _send(
      () => _client.get(_uri('/conversations'), headers: _headers),
    );
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) =>
            ConversationDto.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<ConversationDto> createConversation({
    required String title,
    required bool discreetMode,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/conversations'),
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'discreet_mode': discreetMode,
        }),
      ),
    );
    return ConversationDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ChatMessageResponseDto> sendMessage({
    required String? conversationId,
    required String message,
    required bool discreetMode,
    required List<ContextMessageDto> history,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/message'),
        headers: _headers,
        body: jsonEncode({
          'conversation_id': conversationId,
          'message': message,
          'discreet_mode': discreetMode,
          'history':
              history.map((item) => item.toJson()).toList(growable: false),
        }),
      ),
    );
    return ChatMessageResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    if (!isEnabled) {
      throw const ChatApiException('API remota nao configurada.');
    }

    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ChatApiException('Tempo limite ao conectar com o backend.');
    } on Object catch (error) {
      throw ChatApiException('Falha de conexao com o backend: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatApiException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  Uri _uri(String path) => Uri.parse('$_chatBaseUrl$path');

  static Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on Object {
      // Preserve a safe generic error below; response bodies can be inconsistent.
    }
    return 'Backend retornou status ${response.statusCode}.';
  }

  static String _resolveChatBaseUrl(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/api/v1/chat')) {
      return normalized;
    }
    if (normalized.endsWith('/api/v1')) {
      return '$normalized/chat';
    }
    if (normalized.endsWith('/chat')) {
      return normalized;
    }
    return '$normalized/api/v1/chat';
  }
}
