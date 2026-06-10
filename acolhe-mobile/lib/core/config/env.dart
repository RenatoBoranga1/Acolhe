enum AppEnvironmentType { dev, staging, production }

extension AppEnvironmentTypeX on AppEnvironmentType {
  static AppEnvironmentType parse(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'production' || 'prod' => AppEnvironmentType.production,
      'staging' || 'stage' => AppEnvironmentType.staging,
      _ => AppEnvironmentType.dev,
    };
  }

  String get wireName => switch (this) {
        AppEnvironmentType.dev => 'dev',
        AppEnvironmentType.staging => 'staging',
        AppEnvironmentType.production => 'production',
      };

  String get label => switch (this) {
        AppEnvironmentType.dev => 'Desenvolvimento',
        AppEnvironmentType.staging => 'Homologacao',
        AppEnvironmentType.production => 'Producao',
      };
}
