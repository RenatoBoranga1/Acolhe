class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const bool demoMode = apiBaseUrl == '';

  static bool get useRemoteApi => apiBaseUrl.isNotEmpty;
}
