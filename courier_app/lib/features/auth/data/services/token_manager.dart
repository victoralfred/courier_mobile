import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';

/// Interface for managing authentication tokens
abstract class TokenManager {
  /// Get the current access token
  Future<String?> getAccessToken();

  /// Get the current refresh token
  Future<String?> getRefreshToken();

  /// Get the current CSRF token
  Future<String?> getCsrfToken();

  /// Save authentication tokens
  Future<Either<Failure, bool>> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? csrfToken,
  });

  /// Clear all tokens
  Future<Either<Failure, bool>> clearTokens();

  /// Refresh the access token using the refresh token
  Future<Either<Failure, bool>> refreshAccessToken();

  /// Check if tokens are valid
  Future<bool> hasValidTokens();

  /// Get the token expiry time
  Future<DateTime?> getTokenExpiry();

  /// Set up automatic token refresh
  void setupAutoRefresh();

  /// Cancel automatic token refresh
  void cancelAutoRefresh();
}