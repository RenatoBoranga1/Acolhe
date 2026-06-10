import 'package:acolhe_mobile/core/config/env.dart';

enum BackendConnectionState { discovering, connected, offline }

enum ApiEndpointSource {
  none,
  manualOverride,
  configuredEnvironment,
  cachedDiscovery,
  androidEmulator,
  iosSimulator,
  desktopLocalhost,
  webLocalhost,
  localNetworkScan,
}

extension ApiEndpointSourceX on ApiEndpointSource {
  String get label => switch (this) {
        ApiEndpointSource.none => 'Sem endereco ativo',
        ApiEndpointSource.manualOverride => 'URL personalizada',
        ApiEndpointSource.configuredEnvironment => 'Ambiente configurado',
        ApiEndpointSource.cachedDiscovery => 'Ultima descoberta valida',
        ApiEndpointSource.androidEmulator => 'Android Emulator',
        ApiEndpointSource.iosSimulator => 'Simulador local',
        ApiEndpointSource.desktopLocalhost => 'Desktop local',
        ApiEndpointSource.webLocalhost => 'Web local',
        ApiEndpointSource.localNetworkScan => 'Rede local',
      };
}

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.environment,
    required this.source,
  });

  final String baseUrl;
  final AppEnvironmentType environment;
  final ApiEndpointSource source;

  Uri get healthUri => Uri.parse('$baseUrl/health');

  String get versionedApiBaseUrl {
    final normalized = normalizeBaseUrl(baseUrl);
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.endsWith('/api/v1')) {
      return normalized;
    }
    return '$normalized/api/v1';
  }

  String get chatBaseUrl {
    final normalized = versionedApiBaseUrl;
    if (normalized.isEmpty) {
      return '';
    }
    return '$normalized/chat';
  }

  ApiConfig copyWith({
    String? baseUrl,
    AppEnvironmentType? environment,
    ApiEndpointSource? source,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      environment: environment ?? this.environment,
      source: source ?? this.source,
    );
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
            ? trimmed
            : 'http://$trimmed';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }
}
