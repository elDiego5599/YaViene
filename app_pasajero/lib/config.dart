class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String wsPath = '/ws';
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
