import 'environment.dart';

class AppConfig {
  static late AppEnvironment _config;

  static void setEnvironment(String env) {
    _config = AppEnvironment.fromString(env);
  }

  static AppEnvironment get config => _config;

  static String get apiBaseUrl => _config.apiBaseUrl;
  static String get wsBaseUrl => _config.wsBaseUrl;
  static bool get isDebug => _config.isDevelopment;
  static bool get isProduction => _config.isProduction;
  static String get environment => _config.name;
}
