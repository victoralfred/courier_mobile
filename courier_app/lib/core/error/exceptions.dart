import 'package:equatable/equatable.dart';
import '../constants/app_strings.dart';

/// Base exception class for all application exceptions
abstract class AppException extends Equatable implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  List<Object?> get props => [message, code, details];

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when server returns an error response
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.details,
  });

  factory ServerException.fromJson(Map<String, dynamic> json) =>
      ServerException(
        code: json['code'] as String?,
        message: json['message'] as String? ?? AppStrings.errorServerGeneral,
        details: json['details'],
      );
}

/// Exception thrown when there are network connectivity issues
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code = AppStrings.errorCodeNetworkError,
  });

  factory NetworkException.noConnection() => const NetworkException(
        message: AppStrings.errorNoInternet,
        code: AppStrings.errorCodeNoConnection,
      );

  factory NetworkException.timeout() => const NetworkException(
        message: AppStrings.errorConnectionTimeout,
        code: AppStrings.errorCodeTimeout,
      );
}

/// Exception thrown when there are cache-related issues
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code = AppStrings.errorCodeCacheError,
  });

  factory CacheException.notFound(String key) => CacheException(
        message: AppStrings.format(AppStrings.errorCacheNotFound, {'key': key}),
        code: AppStrings.errorCodeNotFound,
      );

  factory CacheException.expired() => const CacheException(
        message: AppStrings.errorCacheExpired,
        code: AppStrings.errorCodeExpired,
      );
}

/// Exception thrown when validation fails
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;

  const ValidationException({
    super.message = AppStrings.errorValidationFailed,
    super.code = AppStrings.errorCodeValidation,
    this.fieldErrors = const {},
    super.details,
  });

  factory ValidationException.fromJson(Map<String, dynamic> json) {
    final details = json['details'];
    Map<String, String> fieldErrors = {};

    if (details is Map<String, dynamic>) {
      fieldErrors = details.map(
        (key, value) => MapEntry(key, value.toString()),
      );
    }

    return ValidationException(
      message: json['message'] as String? ?? AppStrings.errorInvalidInput,
      code: json['code'] as String? ?? AppStrings.errorCodeValidation,
      fieldErrors: fieldErrors,
      details: details,
    );
  }

  String? getFieldError(String field) => fieldErrors[field];
  bool hasFieldError(String field) => fieldErrors.containsKey(field);

  @override
  List<Object?> get props => [message, code, fieldErrors, details];
}

/// Exception thrown when authentication fails
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.message,
    required super.code,
  });

  factory AuthenticationException.unauthorized() => const AuthenticationException(
        message: AppStrings.errorUnauthorized,
        code: AppStrings.errorCodeUnauthorized,
      );

  factory AuthenticationException.sessionExpired() => const AuthenticationException(
        message: AppStrings.errorSessionExpired,
        code: AppStrings.errorCodeSessionExpired,
      );

  factory AuthenticationException.invalidCredentials() => const AuthenticationException(
        message: AppStrings.errorInvalidCredentials,
        code: AppStrings.errorCodeInvalidCredentials,
      );
}

/// Exception thrown when an unknown error occurs
class UnknownException extends AppException {
  const UnknownException({
    super.message = AppStrings.errorUnknown,
    super.code = AppStrings.errorCodeUnknown,
    super.details,
  });
}

/// Exception thrown when configuration is missing or invalid
class ConfigurationException extends AppException {
  const ConfigurationException({
    required super.message,
    super.code = 'CONFIG_ERROR',
    super.details,
  });
}