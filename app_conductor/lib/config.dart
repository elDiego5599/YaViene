class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const bool demoMode = String.fromEnvironment(
    'DEMO_MODE',
    defaultValue: 'true',
  ) == 'true';
  static const String demoCompanyId = String.fromEnvironment(
    'DEMO_COMPANY',
    defaultValue: 'EMP-01',
  );
}
