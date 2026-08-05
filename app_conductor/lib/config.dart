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
}
