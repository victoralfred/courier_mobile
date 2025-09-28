import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/jwt_token.dart';

/// Abstract token manager service
abstract class TokenManager {
  /// Get the current access token
  Future<Either<Failure, String>> getAccessToken();

  /// Get the CSRF token for write operations
  Future<Either<Failure, String>> getCsrfToken();

  /// Refresh the access token
  Future<Either<Failure, JwtToken>> refreshToken();

  /// Store a new token
  Future<Either<Failure, Unit>> storeToken(JwtToken token);

  /// Clear all tokens
  Future<Either<Failure, Unit>> clearTokens();

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Start automatic token refresh
  void startAutoRefresh();

  /// Stop automatic token refresh
  void stopAutoRefresh();

  /// Stream of authentication state changes
  Stream<bool> get authStateChanges;

  /// Stream of token refresh events
  Stream<JwtToken?> get tokenRefreshStream;
}