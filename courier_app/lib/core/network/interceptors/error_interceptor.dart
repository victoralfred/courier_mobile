import 'package:dio/dio.dart';
import '../../error/exceptions.dart';
import '../../constants/app_strings.dart';

/// Interceptor to handle API errors and convert them to app exceptions
class ErrorInterceptor extends Interceptor {
  final Future<void> Function()? onTokenExpired;

  ErrorInterceptor({this.onTokenExpired});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final exception = _handleError(err);

    // Handle token expiration
    if (exception is AuthenticationException &&
        exception.code == AppStrings.errorCodeSessionExpired &&
        onTokenExpired != null) {
      await onTokenExpired!();
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();

      case DioExceptionType.connectionError:
        return NetworkException.noConnection();

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return const NetworkException(
          message: AppStrings.requestWasCancelled,
          code: 'REQUEST_CANCELLED',
        );

      case DioExceptionType.unknown:
      default:
        return UnknownException(
          message: error.message ?? AppStrings.errorUnknown,
          details: error.error,
        );
    }
  }

  AppException _handleResponseError(Response? response) {
    if (response == null) {
      return const UnknownException();
    }

    // Try to parse standard error response format
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        final error = data['error'] as Map<String, dynamic>;

        // Check for validation errors
        if (error['code'] == AppStrings.errorCodeValidation) {
          return ValidationException.fromJson(error);
        }

        // Create appropriate exception based on status code
        switch (response.statusCode) {
          case 400:
            return ValidationException.fromJson(error);
          case 401:
            if (error['code'] == AppStrings.errorCodeSessionExpired) {
              return AuthenticationException.sessionExpired();
            }
            return AuthenticationException.unauthorized();
          case 403:
            return ServerException(
              code: AppStrings.errorCodeForbidden,
              message: error['message'] ?? AppStrings.errorForbidden,
              details: error['details'],
            );
          case 404:
            return ServerException(
              code: AppStrings.errorCodeNotFound,
              message: error['message'] ?? AppStrings.errorResourceNotFound,
              details: error['details'],
            );
          default:
            return ServerException.fromJson(error);
        }
      }
    }

    // Fallback to status code based exception
    switch (response.statusCode) {
      case 400:
        return const ValidationException();
      case 401:
        return AuthenticationException.unauthorized();
      case 403:
        return const ServerException(
          code: AppStrings.errorCodeForbidden,
          message: AppStrings.errorAccessDenied,
        );
      case 404:
        return const ServerException(
          code: AppStrings.errorCodeNotFound,
          message: AppStrings.errorResourceNotFound,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return const ServerException(
          code: AppStrings.errorCodeServerError,
          message: AppStrings.errorInternalServer,
        );
      default:
        return ServerException(
          code: response.statusCode.toString(),
          message: response.statusMessage ?? AppStrings.errorServerGeneral,
        );
    }
  }
}
