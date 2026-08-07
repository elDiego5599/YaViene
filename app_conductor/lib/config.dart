class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const int mqttPort = 8883;
  static const bool mqttSecure = bool.fromEnvironment(
    'MQTT_USE_TLS',
    defaultValue: false,
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
