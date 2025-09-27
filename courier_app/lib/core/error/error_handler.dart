import 'package:dio/dio.dart';
import '../constants/app_strings.dart';
import '../services/error_reporting_service.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Global error handler that converts exceptions to failures
class ErrorHandler {
  final ErrorReportingService? reportingService;

  const ErrorHandler({this.reportingService});

  /// Handle any error and convert it to a Failure
  Failure handleError(dynamic error, [StackTrace? stackTrace]) {
    // Report critical errors if service is available
    if (_shouldReportError(error)) {
      reportingService?.reportError(error, stackTrace);
    }

    // Convert exception to failure
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is AppException) {
      return _handleAppException(error);
    } else {
      return UnknownFailure(
        message: error?.toString() ?? AppStrings.errorUnknown,
      );
    }
  }

  /// Get user-friendly error message for a failure
  String getUserFriendlyMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return AppStrings.errorCheckInternet;
    } else if (failure is ValidationFailure) {
      return AppStrings.errorCheckInput;
    } else if (failure is AuthenticationFailure) {
      return AppStrings.errorPleaseLogin;
    } else if (failure is AuthorizationFailure) {
      return AppStrings.errorAccessDenied;
    } else if (failure is NotFoundFailure) {
      return AppStrings.errorDataNotFound;
    } else if (failure is TimeoutFailure) {
      return AppStrings.errorOperationTimeout;
    } else if (failure is OfflineFailure) {
      return failure.message;
    } else if (failure is ServerFailure) {
      return AppStrings.errorSomethingWentWrong;
    } else {
      return AppStrings.errorUnexpected;
    }
  }

  /// Handle DioException and convert to Failure
  Failure _handleDioError(DioException error) {
    // Check if error contains our custom exception
    if (error.error is AppException) {
      return _handleAppException(error.error as AppException);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(
          duration: error.requestOptions.connectTimeout,
        );

      case DioExceptionType.connectionError:
        return const NetworkFailure(message: AppStrings.errorNoInternet);

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return const NetworkFailure(message: AppStrings.requestWasCancelled);

      case DioExceptionType.unknown:
      default:
        return UnknownFailure(
          message: error.message ?? AppStrings.errorUnknown,
        );
    }
  }

  /// Handle AppException and convert to Failure
  Failure _handleAppException(AppException exception) {
    if (exception is ServerException) {
      return ServerFailure(
        message: exception.message,
        code: exception.code,
        details: exception.details?.toString(),
      );
    } else if (exception is NetworkException) {
      return NetworkFailure(message: exception.message);
    } else if (exception is CacheException) {
      return CacheFailure(message: exception.message);
    } else if (exception is ValidationException) {
      return ValidationFailure(
        message: exception.message,
        fieldErrors: exception.fieldErrors,
      );
    } else if (exception is AuthenticationException) {
      return AuthenticationFailure(
        message: exception.message,
        code: exception.code,
      );
    } else {
      return UnknownFailure(message: exception.message);
    }
  }

  /// Handle bad response from server
  Failure _handleBadResponse(Response? response) {
    if (response == null) {
      return const ServerFailure();
    }

    switch (response.statusCode) {
      case 400:
        return const ValidationFailure();
      case 401:
        return const AuthenticationFailure();
      case 403:
        return const AuthorizationFailure();
      case 404:
        return const NotFoundFailure();
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerFailure(
          code: response.statusCode.toString(),
          message: AppStrings.errorServiceUnavailable,
        );
      default:
        return ServerFailure(
          code: response.statusCode.toString(),
          message: response.statusMessage ?? AppStrings.errorServerGeneral,
        );
    }
  }

  /// Determine if error should be reported to error reporting service
  bool _shouldReportError(dynamic error) {
    // Don't report client errors (4xx)
    if (error is DioException && error.response != null) {
      final statusCode = error.response!.statusCode;
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        return false;
      }
    }

    // Don't report known exceptions that are expected
    if (error is NetworkException ||
        error is CacheException ||
        error is ValidationException) {
      return false;
    }

    // Report server errors and unknown errors
    return true;
  }
}
