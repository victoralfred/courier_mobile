import 'environment.dart';

class AppConfig {
  static late EnvironmentConfig _config;

  static void setEnvironment(Environment env) {
    switch (env) {
      case Environment.development:
        _config = const EnvironmentConfig(
          environment: Environment.development,
          apiBaseUrl: 'http://localhost:8080/api/v1',
          wsBaseUrl: 'ws://localhost:8080/ws',
          connectTimeout: 30000,
          receiveTimeout: 30000,
          enableLogging: true,
          enableCrashlytics: false,
          sentryDsn: '',
          googleMapsApiKey: '', // Add your dev API key
          firebaseProjectId: 'courier-dev',
        );
        break;
      case Environment.staging:
        _config = const EnvironmentConfig(
          environment: Environment.staging,
          apiBaseUrl: 'https://staging.courier-api.com/api/v1',
          wsBaseUrl: 'wss://staging.courier-api.com/ws',
          connectTimeout: 30000,
          receiveTimeout: 30000,
          enableLogging: true,
          enableCrashlytics: true,
          sentryDsn: '', // Add your staging Sentry DSN
          googleMapsApiKey: '', // Add your staging API key
          firebaseProjectId: 'courier-staging',
        );
        break;
      case Environment.production:
        _config = const EnvironmentConfig(
          environment: Environment.production,
          apiBaseUrl: 'https://api.courier.com/api/v1',
          wsBaseUrl: 'wss://api.courier.com/ws',
          connectTimeout: 30000,
          receiveTimeout: 30000,
          enableLogging: false,
          enableCrashlytics: true,
          sentryDsn: '', // Add your production Sentry DSN
          googleMapsApiKey: '', // Add your production API key
          firebaseProjectId: 'courier-prod',
        );
        break;
    }
  }

  static EnvironmentConfig get config => _config;

  static String get apiBaseUrl => _config.apiBaseUrl;
  static String get wsBaseUrl => _config.wsBaseUrl;
  static bool get isDebug => _config.isDevelopment;
  static bool get isProduction => _config.isProduction;
  static String get environment => _config.environmentName;
}
