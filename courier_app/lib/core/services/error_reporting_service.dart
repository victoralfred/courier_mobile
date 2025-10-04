import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/environment.dart';
import '../config/app_config.dart';

/// Service for reporting errors to external monitoring services
class ErrorReportingService {
  final AppEnvironment _config;
  bool _isInitialized = false;

  ErrorReportingService({required AppEnvironment config}) : _config = config;

  /// Initialize the error reporting service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize in non-debug environments
    if (!AppConfig.isDebug && _config.sentryDsn.isNotEmpty) {
      await SentryFlutter.init(
        (options) {
          options.dsn = _config.sentryDsn;
          options.environment = _config.name;
          options.debug = false;
          options.tracesSampleRate = 0.1;
          options.attachScreenshot = true;
          options.attachViewHierarchy = true;
          options.enableAutoNativeBreadcrumbs = true;
          options.enableAutoPerformanceTracing = true;
          options.sendDefaultPii = false; // Don't send personally identifiable information
        },
      );
      _isInitialized = true;
    }
  }

  /// Report an error to the monitoring service
  Future<void> reportError(
    dynamic exception,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
    bool fatal = false,
  }) async {
    // Log to console in debug mode
    if (_config.isDevelopment) {
      debugPrint('Error: $exception');
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
      return;
    }

    // Report to Sentry if initialized
    if (_isInitialized) {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (extra != null) {
            extra.forEach((key, value) {
              scope.setContexts(key, value);
            });
          }
          if (fatal) {
            scope.level = SentryLevel.fatal;
          }
        },
      );
    }
  }

  /// Report a message (non-error) to the monitoring service
  Future<void> reportMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
  }) async {
    // Log to console in debug mode
    if (_config.isDevelopment) {
      debugPrint('Message [$level]: $message');
      return;
    }

    // Report to Sentry if initialized
    if (_isInitialized) {
      await Sentry.captureMessage(
        message,
        level: level,
        withScope: (scope) {
          if (extra != null) {
            extra.forEach((key, value) {
              scope.setContexts(key, value);
            });
          }
        },
      );
    }
  }

  /// Add breadcrumb for tracking user actions
  void addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
    SentryLevel? level,
  }) {
    if (!_isInitialized) return;

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Set user context for error reports
  void setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? extra,
  }) {
    if (!_isInitialized) return;

    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: extra,
      ));
    });
  }

  /// Clear user context
  void clearUser() {
    if (!_isInitialized) return;

    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Start a transaction for performance monitoring
  ISentrySpan? startTransaction(
    String name,
    String operation, {
    String? description,
  }) {
    if (!_isInitialized) return null;

    return Sentry.startTransaction(
      name,
      operation,
      description: description,
    );
  }

  /// Capture performance metrics
  Future<void> captureMetric(
    String key,
    double value, {
    SentryMeasurementUnit? unit,
    Map<String, String>? tags,
  }) async {
    if (!_isInitialized) return;

    final transaction = Sentry.getSpan();
    transaction?.setMeasurement(key, value, unit: unit);
  }
}