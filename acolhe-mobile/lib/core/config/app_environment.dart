import 'package:acolhe_mobile/core/config/env.dart';

class AppEnvironment {
  const AppEnvironment._();

  static const String envName =
      String.fromEnvironment('ACOLHE_ENV', defaultValue: 'dev');
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String stagingApiBaseUrl =
      String.fromEnvironment('STAGING_API_BASE_URL', defaultValue: '');
  static const String productionApiBaseUrl =
      String.fromEnvironment('PRODUCTION_API_BASE_URL', defaultValue: '');

  static AppEnvironmentType get current => AppEnvironmentTypeX.parse(envName);

  static bool get isDevelopment => current == AppEnvironmentType.dev;
  static bool get isStaging => current == AppEnvironmentType.staging;
  static bool get isProduction => current == AppEnvironmentType.production;

  static String get configuredBaseUrl {
    return switch (current) {
      AppEnvironmentType.dev => apiBaseUrl.trim(),
      AppEnvironmentType.staging => _firstNonEmpty([
          stagingApiBaseUrl,
          apiBaseUrl,
        ]),
      AppEnvironmentType.production => _firstNonEmpty([
          productionApiBaseUrl,
          apiBaseUrl,
        ]),
    };
  }

  static bool get hasBundledApi => configuredBaseUrl.isNotEmpty;

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }
}
