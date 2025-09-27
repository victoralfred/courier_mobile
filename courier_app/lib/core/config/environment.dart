enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final int connectTimeout;
  final int receiveTimeout;
  final bool enableLogging;
  final bool enableCrashlytics;
  final String sentryDsn;
  final String googleMapsApiKey;
  final String firebaseProjectId;

  const EnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.connectTimeout = 30000,
    this.receiveTimeout = 30000,
    this.enableLogging = true,
    this.enableCrashlytics = false,
    this.sentryDsn = '',
    this.googleMapsApiKey = '',
    this.firebaseProjectId = '',
  });

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;

  String get environmentName {
    switch (environment) {
      case Environment.development:
        return 'Development';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Production';
    }
  }
}