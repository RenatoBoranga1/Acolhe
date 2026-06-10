import 'dart:async';
import 'dart:convert';

import 'package:acolhe_mobile/core/config/api_config.dart';
import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/core/config/env.dart';
import 'package:acolhe_mobile/core/config/network_interfaces_stub.dart'
    if (dart.library.io) 'package:acolhe_mobile/core/config/network_interfaces_io.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final backendHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

class BackendConfigState {
  const BackendConfigState({
    required this.environment,
    required this.isLoading,
    required this.isDiscovering,
    required this.hasCompletedDiscovery,
    required this.overrideUrl,
    required this.discoveredUrl,
    required this.effectiveBaseUrl,
    required this.source,
    required this.connectionState,
    this.lastValidatedAt,
    this.lastSubnetPrefix,
  });

  final AppEnvironmentType environment;
  final bool isLoading;
  final bool isDiscovering;
  final bool hasCompletedDiscovery;
  final String overrideUrl;
  final String discoveredUrl;
  final String effectiveBaseUrl;
  final ApiEndpointSource source;
  final BackendConnectionState connectionState;
  final DateTime? lastValidatedAt;
  final String? lastSubnetPrefix;

  String get customBaseUrl => overrideUrl.trim();
  String get cachedBaseUrl => discoveredUrl.trim();

  bool get usesCustomUrl => customBaseUrl.isNotEmpty;
  bool get usesBundledUrl =>
      !usesCustomUrl && AppEnvironment.configuredBaseUrl.isNotEmpty;
  bool get usesRemoteApi =>
      effectiveBaseUrl.isNotEmpty &&
      connectionState == BackendConnectionState.connected;

  String get preferredBaseUrl {
    if (effectiveBaseUrl.isNotEmpty) {
      return effectiveBaseUrl;
    }
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    if (cachedBaseUrl.isNotEmpty) {
      return cachedBaseUrl;
    }
    return AppEnvironment.configuredBaseUrl;
  }

  bool get pointsToLoopbackHost {
    final candidate = preferredBaseUrl;
    if (candidate.isEmpty) {
      return false;
    }
    final host = Uri.tryParse(candidate)?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  String get statusHeadline => switch (connectionState) {
        BackendConnectionState.connected => 'Conectado',
        BackendConnectionState.discovering =>
          'Reconectando ao servico inteligente...',
        BackendConnectionState.offline => 'Modo offline seguro ativado',
      };

  String get statusMessage => switch (connectionState) {
        BackendConnectionState.connected => preferredBaseUrl.isEmpty
            ? 'O servico inteligente foi validado e esta pronto para uso.'
            : 'O app validou $preferredBaseUrl e vai reutilizar essa conexao automaticamente.',
        BackendConnectionState.discovering =>
          'O app esta procurando e validando a melhor conexao disponivel sem interromper o uso local seguro.',
        BackendConnectionState.offline =>
          'O chat continua funcionando com fallback local seguro enquanto uma nova tentativa de conexao acontece em segundo plano.',
      };

  String get sourceLabel => source.label;

  BackendConfigState copyWith({
    AppEnvironmentType? environment,
    bool? isLoading,
    bool? isDiscovering,
    bool? hasCompletedDiscovery,
    String? overrideUrl,
    String? discoveredUrl,
    String? effectiveBaseUrl,
    ApiEndpointSource? source,
    BackendConnectionState? connectionState,
    DateTime? lastValidatedAt,
    String? lastSubnetPrefix,
    bool clearLastValidatedAt = false,
    bool clearLastSubnetPrefix = false,
  }) {
    return BackendConfigState(
      environment: environment ?? this.environment,
      isLoading: isLoading ?? this.isLoading,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      hasCompletedDiscovery:
          hasCompletedDiscovery ?? this.hasCompletedDiscovery,
      overrideUrl: overrideUrl ?? this.overrideUrl,
      discoveredUrl: discoveredUrl ?? this.discoveredUrl,
      effectiveBaseUrl: effectiveBaseUrl ?? this.effectiveBaseUrl,
      source: source ?? this.source,
      connectionState: connectionState ?? this.connectionState,
      lastValidatedAt:
          clearLastValidatedAt ? null : lastValidatedAt ?? this.lastValidatedAt,
      lastSubnetPrefix: clearLastSubnetPrefix
          ? null
          : lastSubnetPrefix ?? this.lastSubnetPrefix,
    );
  }

  factory BackendConfigState.initial() {
    return BackendConfigState(
      environment: AppEnvironment.current,
      isLoading: true,
      isDiscovering: false,
      hasCompletedDiscovery: false,
      overrideUrl: '',
      discoveredUrl: '',
      effectiveBaseUrl: '',
      source: ApiEndpointSource.none,
      connectionState: BackendConnectionState.discovering,
    );
  }
}

final backendConfigProvider =
    StateNotifierProvider<BackendConfigController, BackendConfigState>((ref) {
  return BackendConfigController(
    ref.read(secureStorageProvider),
    ref.read(backendHttpClientProvider),
  );
});

class BackendConfigController extends StateNotifier<BackendConfigState> {
  BackendConfigController(
    this._storage,
    this._client, {
    bool allowLocalNetworkScan = true,
  })  : _allowLocalNetworkScan = allowLocalNetworkScan,
        super(BackendConfigState.initial()) {
    unawaited(load());
  }

  static const Duration _healthTimeout = Duration(milliseconds: 900);
  static const Duration _retryInterval = Duration(seconds: 45);
  static const List<int> _priorityHosts = [
    1,
    2,
    10,
    15,
    20,
    50,
    100,
    101,
    120,
    150,
    200,
  ];

  final SecureStorageService _storage;
  final http.Client _client;
  final bool _allowLocalNetworkScan;

  Timer? _retryTimer;
  bool _isResolving = false;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final storedOverride = ApiConfig.normalizeBaseUrl(
      await _storage.readString(StorageKeys.apiBaseUrl) ?? '',
    );
    final storedDiscovered = ApiConfig.normalizeBaseUrl(
      await _storage.readString(StorageKeys.apiDiscoveredBaseUrl) ?? '',
    );
    final lastSubnetPrefix =
        await _storage.readString(StorageKeys.apiLastSubnetPrefix);
    state = state.copyWith(
      isLoading: false,
      overrideUrl: storedOverride,
      discoveredUrl: storedDiscovered,
      lastSubnetPrefix: lastSubnetPrefix,
    );
    unawaited(_resolveBackend(forceRefresh: false));
  }

  Future<void> saveOverride(String value) async {
    final normalized = ApiConfig.normalizeBaseUrl(value);
    if (normalized.isEmpty) {
      await _storage.delete(StorageKeys.apiBaseUrl);
    } else {
      await _storage.writeString(StorageKeys.apiBaseUrl, normalized);
    }
    state = state.copyWith(
      overrideUrl: normalized,
      effectiveBaseUrl: '',
      source: ApiEndpointSource.none,
      connectionState: BackendConnectionState.discovering,
      clearLastValidatedAt: true,
    );
    await _resolveBackend(forceRefresh: true, userInitiated: true);
  }

  Future<void> clearOverride() => saveOverride('');

  Future<void> clearDiscoveryCache() async {
    await _storage.delete(StorageKeys.apiDiscoveredBaseUrl);
    await _storage.delete(StorageKeys.apiLastSubnetPrefix);
    state = state.copyWith(
      discoveredUrl: '',
      effectiveBaseUrl: '',
      source: ApiEndpointSource.none,
      connectionState: BackendConnectionState.discovering,
      clearLastValidatedAt: true,
      clearLastSubnetPrefix: true,
    );
    await _resolveBackend(forceRefresh: true, userInitiated: true);
  }

  Future<void> retryDiscovery() async {
    await _resolveBackend(forceRefresh: true, userInitiated: true);
  }

  Future<void> _resolveBackend({
    required bool forceRefresh,
    bool userInitiated = false,
  }) async {
    if (_isResolving) {
      return;
    }
    _isResolving = true;
    state = state.copyWith(
      isLoading: false,
      isDiscovering: true,
      connectionState: BackendConnectionState.discovering,
    );

    try {
      final config = await _findHealthyBackend(
        forceRefresh: forceRefresh,
        userInitiated: userInitiated,
      );
      if (config != null) {
        final subnet = _subnetPrefixForBaseUrl(config.baseUrl);
        if (_shouldPersistDiscovery(config.source)) {
          await _storage.writeString(
            StorageKeys.apiDiscoveredBaseUrl,
            config.baseUrl,
          );
          if (subnet != null) {
            await _storage.writeString(StorageKeys.apiLastSubnetPrefix, subnet);
          }
        }
        state = state.copyWith(
          isDiscovering: false,
          hasCompletedDiscovery: true,
          discoveredUrl: _shouldPersistDiscovery(config.source)
              ? config.baseUrl
              : state.discoveredUrl,
          effectiveBaseUrl: config.baseUrl,
          source: config.source,
          connectionState: BackendConnectionState.connected,
          lastValidatedAt: DateTime.now(),
          lastSubnetPrefix: subnet ?? state.lastSubnetPrefix,
        );
        _retryTimer?.cancel();
        return;
      }

      state = state.copyWith(
        isDiscovering: false,
        hasCompletedDiscovery: true,
        effectiveBaseUrl: '',
        source: ApiEndpointSource.none,
        connectionState: BackendConnectionState.offline,
        clearLastValidatedAt: true,
      );
      _scheduleRetryIfNeeded();
    } finally {
      _isResolving = false;
    }
  }

  Future<ApiConfig?> _findHealthyBackend({
    required bool forceRefresh,
    required bool userInitiated,
  }) async {
    final seen = <String>{};
    final candidates = <ApiConfig>[];

    void addCandidate(String rawUrl, ApiEndpointSource source) {
      final normalized = ApiConfig.normalizeBaseUrl(rawUrl);
      if (normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      candidates.add(
        ApiConfig(
          baseUrl: normalized,
          environment: state.environment,
          source: source,
        ),
      );
    }

    if (state.customBaseUrl.isNotEmpty) {
      addCandidate(state.customBaseUrl, ApiEndpointSource.manualOverride);
    }

    final bundledUrl = AppEnvironment.configuredBaseUrl;
    if (bundledUrl.isNotEmpty) {
      addCandidate(bundledUrl, ApiEndpointSource.configuredEnvironment);
    }

    if (state.cachedBaseUrl.isNotEmpty) {
      addCandidate(
        state.cachedBaseUrl,
        forceRefresh
            ? ApiEndpointSource.cachedDiscovery
            : ApiEndpointSource.cachedDiscovery,
      );
    }

    for (final candidate in _platformLocalCandidates()) {
      addCandidate(candidate.baseUrl, candidate.source);
    }

    for (final candidate in candidates) {
      if (await _isHealthy(candidate)) {
        return candidate;
      }
    }

    if (!AppEnvironment.isDevelopment || !_allowLocalNetworkScan) {
      return null;
    }

    return _scanLocalNetwork(aggressive: userInitiated);
  }

  Iterable<ApiConfig> _platformLocalCandidates() sync* {
    if (kIsWeb) {
      yield ApiConfig(
        baseUrl: 'http://localhost:8000',
        environment: state.environment,
        source: ApiEndpointSource.webLocalhost,
      );
      yield ApiConfig(
        baseUrl: 'http://127.0.0.1:8000',
        environment: state.environment,
        source: ApiEndpointSource.webLocalhost,
      );
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        yield ApiConfig(
          baseUrl: 'http://10.0.2.2:8000',
          environment: state.environment,
          source: ApiEndpointSource.androidEmulator,
        );
        yield ApiConfig(
          baseUrl: 'http://localhost:8000',
          environment: state.environment,
          source: ApiEndpointSource.desktopLocalhost,
        );
        yield ApiConfig(
          baseUrl: 'http://127.0.0.1:8000',
          environment: state.environment,
          source: ApiEndpointSource.desktopLocalhost,
        );
        break;
      case TargetPlatform.iOS:
        yield ApiConfig(
          baseUrl: 'http://localhost:8000',
          environment: state.environment,
          source: ApiEndpointSource.iosSimulator,
        );
        yield ApiConfig(
          baseUrl: 'http://127.0.0.1:8000',
          environment: state.environment,
          source: ApiEndpointSource.iosSimulator,
        );
        break;
      case TargetPlatform.macOS ||
            TargetPlatform.windows ||
            TargetPlatform.linux:
        yield ApiConfig(
          baseUrl: 'http://localhost:8000',
          environment: state.environment,
          source: ApiEndpointSource.desktopLocalhost,
        );
        yield ApiConfig(
          baseUrl: 'http://127.0.0.1:8000',
          environment: state.environment,
          source: ApiEndpointSource.desktopLocalhost,
        );
        break;
      case TargetPlatform.fuchsia:
        yield ApiConfig(
          baseUrl: 'http://localhost:8000',
          environment: state.environment,
          source: ApiEndpointSource.desktopLocalhost,
        );
        break;
    }
  }

  Future<ApiConfig?> _scanLocalNetwork({required bool aggressive}) async {
    if (kIsWeb) {
      return null;
    }

    final candidatePrefixes = <String>{
      if ((state.lastSubnetPrefix ?? '').isNotEmpty) state.lastSubnetPrefix!,
      ..._fallbackSubnetPrefixes,
      ...await _readLocalSubnets(),
    }.toList(growable: false);

    for (final prefix in candidatePrefixes) {
      final priorityMatch = await _probePrefix(
        prefix,
        hosts: _priorityHosts,
      );
      if (priorityMatch != null) {
        return priorityMatch;
      }
    }

    if (defaultTargetPlatform != TargetPlatform.android && !aggressive) {
      return null;
    }

    for (final prefix in candidatePrefixes) {
      final broadMatch = await _probePrefix(
        prefix,
        hosts: List<int>.generate(254, (index) => index + 1),
      );
      if (broadMatch != null) {
        return broadMatch;
      }
    }

    return null;
  }

  Future<ApiConfig?> _probePrefix(
    String prefix, {
    required Iterable<int> hosts,
  }) async {
    final candidateHosts = hosts.toList(growable: false);
    if (candidateHosts.isEmpty) {
      return null;
    }

    const batchSize = 24;
    for (var start = 0; start < candidateHosts.length; start += batchSize) {
      final end = (start + batchSize < candidateHosts.length)
          ? start + batchSize
          : candidateHosts.length;
      final batch = candidateHosts.sublist(start, end);
      final results = await Future.wait(
        batch.map((host) async {
          final candidate = ApiConfig(
            baseUrl: 'http://$prefix.$host:8000',
            environment: state.environment,
            source: ApiEndpointSource.localNetworkScan,
          );
          if (await _isHealthy(candidate)) {
            return candidate;
          }
          return null;
        }),
      );
      for (final result in results) {
        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  Future<List<String>> _readLocalSubnets() async {
    final addresses = await readLocalIpv4Addresses();
    final prefixes = <String>{};
    for (final address in addresses) {
      final prefix = _subnetPrefixForIp(address);
      if (prefix != null) {
        prefixes.add(prefix);
      }
    }
    return prefixes.toList(growable: false);
  }

  Future<bool> _isHealthy(ApiConfig config) async {
    try {
      final response = await _client.get(
        config.healthUri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_healthTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['status'] == 'ok';
    } on TimeoutException {
      return false;
    } on FormatException {
      return false;
    } on Object {
      return false;
    }
  }

  void _scheduleRetryIfNeeded() {
    _retryTimer?.cancel();
    if (!AppEnvironment.isDevelopment) {
      return;
    }
    _retryTimer = Timer(_retryInterval, () {
      unawaited(_resolveBackend(forceRefresh: false));
    });
  }

  bool _shouldPersistDiscovery(ApiEndpointSource source) {
    return switch (source) {
      ApiEndpointSource.manualOverride => false,
      ApiEndpointSource.configuredEnvironment => false,
      ApiEndpointSource.none => false,
      _ => true,
    };
  }

  static const List<String> _fallbackSubnetPrefixes = [
    '192.168.0',
    '192.168.1',
    '192.168.15',
    '10.0.0',
    '10.0.1',
    '172.20.10',
  ];

  String? _subnetPrefixForBaseUrl(String rawUrl) {
    final host = Uri.tryParse(rawUrl)?.host ?? '';
    return _subnetPrefixForIp(host);
  }

  String? _subnetPrefixForIp(String rawIp) {
    final parts = rawIp.split('.');
    if (parts.length != 4) {
      return null;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
