import 'package:equatable/equatable.dart';
import '../constants/app_strings.dart';

/// Base failure class for all application failures
abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Failure when server returns an error
class ServerFailure extends Failure {
  final String? code;
  final String? details;

  const ServerFailure({
    super.message = AppStrings.errorServerGeneral,
    this.code,
    this.details,
  });

  @override
  List<Object?> get props => [message, code, details];
}

/// Failure when there are network connectivity issues
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = AppStrings.errorNetworkGeneral,
  });
}

/// Failure when there are cache-related issues
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = AppStrings.errorCacheGeneral,
  });
}

/// Failure when validation fails
class ValidationFailure extends Failure {
  final Map<String, String> fieldErrors;

  const ValidationFailure({
    super.message = AppStrings.errorValidationFailed,
    this.fieldErrors = const {},
  });

  String? getFieldError(String field) => fieldErrors[field];
  bool hasFieldError(String field) => fieldErrors.containsKey(field);

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// Failure when authentication fails
class AuthenticationFailure extends Failure {
  final String? code;

  const AuthenticationFailure({
    super.message = AppStrings.errorAuthenticationFailed,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

/// Failure when authorization fails
class AuthorizationFailure extends Failure {
  final String? resource;

  const AuthorizationFailure({
    super.message = AppStrings.errorAuthorizationFailed,
    this.resource,
  });

  @override
  List<Object?> get props => [message, resource];
}

/// Failure when a resource is not found
class NotFoundFailure extends Failure {
  final String? resource;
  final String? id;

  const NotFoundFailure({
    super.message = AppStrings.errorResourceNotFound,
    this.resource,
    this.id,
  });

  @override
  List<Object?> get props => [message, resource, id];
}

/// Failure when a request times out
class TimeoutFailure extends Failure {
  final Duration? duration;

  const TimeoutFailure({
    super.message = AppStrings.errorRequestTimeout,
    this.duration,
  });

  @override
  List<Object?> get props => [message, duration];
}

/// Failure when an unknown error occurs
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = AppStrings.errorUnknown,
  });
}

/// Failure when action requires internet but device is offline
class OfflineFailure extends Failure {
  const OfflineFailure({
    super.message = AppStrings.errorOfflineAction,
  });
}

/// OAuth-specific failure
class OAuthFailure extends Failure {
  final String? provider;
  final String? errorCode;

  const OAuthFailure(
    String message, {
    this.provider,
    this.errorCode,
  }) : super(message: message);

  @override
  List<Object?> get props => [message, provider, errorCode];
}

/// Failure when PKCE verification fails
class PKCEFailure extends Failure {
  const PKCEFailure(String message) : super(message: message);
}

/// Failure when OAuth state validation fails
class OAuthStateFailure extends Failure {
  const OAuthStateFailure(String message) : super(message: message);
}

/// Failure when OAuth authorization code expires
class OAuthCodeExpiredFailure extends Failure {
  const OAuthCodeExpiredFailure(String message) : super(message: message);
}
