/// Environment configurations for different deployment stages
abstract class Environment {
  static const String development = 'development';
  static const String staging = 'staging';
  static const String production = 'production';
}

/// Application environment configuration
class AppEnvironment {
  final String name;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final bool enableLogging;
  final bool enableCertificatePinning;
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final int maxRetryAttempts;
  final Duration retryDelay;
  final bool enableCrashlytics;
  final String sentryDsn;
  final String googleMapsApiKey;
  final String firebaseProjectId;

  const AppEnvironment({
    required this.name,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.enableLogging,
    required this.enableCertificatePinning,
    required this.connectionTimeout,
    required this.receiveTimeout,
    required this.maxRetryAttempts,
    required this.retryDelay,
    this.enableCrashlytics = false,
    this.sentryDsn = '',
    this.googleMapsApiKey = '',
    this.firebaseProjectId = '',
  });

  bool get isDevelopment => name == Environment.development;
  bool get isStaging => name == Environment.staging;
  bool get isProduction => name == Environment.production;

  /// Development environment configuration
  factory AppEnvironment.development() => const AppEnvironment(
        name: Environment.development,
        apiBaseUrl: 'http://10.0.2.2:8080/api/v1',  // Use 10.0.2.2 for Android emulator
        wsBaseUrl: 'ws://10.0.2.2:8080/ws',
        enableLogging: true,
        enableCertificatePinning: false,
        connectionTimeout: Duration(seconds: 30),
        receiveTimeout: Duration(seconds: 30),
        maxRetryAttempts: 3,
        retryDelay: Duration(seconds: 1),
        enableCrashlytics: false,
        sentryDsn: '',
        googleMapsApiKey: 'YOUR_DEV_GOOGLE_MAPS_KEY',
        firebaseProjectId: 'courier-app-dev',
      );

  /// Staging environment configuration
  factory AppEnvironment.staging() => const AppEnvironment(
        name: Environment.staging,
        apiBaseUrl: 'https://staging-api.courier-app.com/api/v1',
        wsBaseUrl: 'wss://staging-api.courier-app.com/ws',
        enableLogging: true,
        enableCertificatePinning: true,
        connectionTimeout: Duration(seconds: 20),
        receiveTimeout: Duration(seconds: 20),
        maxRetryAttempts: 3,
        retryDelay: Duration(seconds: 2),
        enableCrashlytics: true,
        sentryDsn: 'YOUR_STAGING_SENTRY_DSN',
        googleMapsApiKey: 'YOUR_STAGING_GOOGLE_MAPS_KEY',
        firebaseProjectId: 'courier-app-staging',
      );

  /// Production environment configuration
  factory AppEnvironment.production() => const AppEnvironment(
        name: Environment.production,
        apiBaseUrl: 'https://api.courier-app.com/api/v1',
        wsBaseUrl: 'wss://api.courier-app.com/ws',
        enableLogging: false,
        enableCertificatePinning: true,
        connectionTimeout: Duration(seconds: 15),
        receiveTimeout: Duration(seconds: 15),
        maxRetryAttempts: 3,
        retryDelay: Duration(seconds: 3),
        enableCrashlytics: true,
        sentryDsn: 'YOUR_PRODUCTION_SENTRY_DSN',
        googleMapsApiKey: 'YOUR_PRODUCTION_GOOGLE_MAPS_KEY',
        firebaseProjectId: 'courier-app-prod',
      );

  /// Factory method to get environment based on string
  factory AppEnvironment.fromString(String environment) {
    switch (environment) {
      case Environment.development:
        return AppEnvironment.development();
      case Environment.staging:
        return AppEnvironment.staging();
      case Environment.production:
        return AppEnvironment.production();
      default:
        return AppEnvironment.development();
    }
  }
}
