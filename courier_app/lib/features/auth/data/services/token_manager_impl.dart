import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/jwt_token.dart';
import '../../domain/services/token_manager.dart';
import '../datasources/token_local_data_source.dart';

/// Implementation of token manager with automatic refresh
class TokenManagerImpl implements TokenManager {
  final TokenLocalDataSource localDataSource;
  final ApiClient apiClient;

  Timer? _refreshTimer;
  final _authStateController = StreamController<bool>.broadcast();
  final _tokenRefreshController = StreamController<JwtToken?>.broadcast();

  // Lock to prevent concurrent refresh attempts
  bool _isRefreshing = false;
  final _refreshCompleter = <Completer<Either<Failure, JwtToken>>>[];

  TokenManagerImpl({
    required this.localDataSource,
    required this.apiClient,
  });

  @override
  Future<Either<Failure, String>> getAccessToken() async {
    try {
      final token = await localDataSource.getToken();

      if (token == null) {
        return const Left(AuthenticationFailure(
          message: AppStrings.errorTokenNotFound,
          code: AppStrings.errorCodeNoToken,
        ));
      }

      // Check if token needs refresh
      if (token.shouldRefresh && !_isRefreshing) {
        // Trigger refresh in background
        unawaited(refreshToken());
      }

      if (token.isExpired) {
        // Try to refresh if we have a refresh token
        if (token.refreshToken != null) {
          final refreshResult = await refreshToken();
          return refreshResult.fold(
            (failure) => Left(failure),
            (newToken) => Right(newToken.token),
          );
        }

        return const Left(AuthenticationFailure(
          message: AppStrings.errorTokenExpired,
          code: AppStrings.errorCodeSessionExpired,
        ));
      }

      return Right(token.token);
    } catch (e) {
      return const Left(CacheFailure(
        message: AppStrings.errorCacheFailed,
      ));
    }
  }

  @override
  Future<Either<Failure, String>> getCsrfToken() async {
    try {
      // First check local storage
      var csrfToken = await localDataSource.getCsrfToken();

      if (csrfToken != null) {
        return Right(csrfToken);
      }

      // Fetch new CSRF token from server
      final response = await apiClient.get('/api/v1/auth/csrf');

      if (response.statusCode == 200 && response.data != null) {
        csrfToken = response.data['csrf_token'] as String;
        await localDataSource.storeCsrfToken(csrfToken);
        return Right(csrfToken);
      }

      return const Left(ServerFailure(
        message: AppStrings.errorCsrfTokenFailed,
      ));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const Left(AuthenticationFailure(
          message: AppStrings.errorUnauthorized,
          code: AppStrings.errorCodeSessionExpired,
        ));
      }
      return const Left(NetworkFailure(
        message: AppStrings.errorNetworkGeneral,
      ));
    } catch (e) {
      return const Left(UnexpectedFailure(
        message: AppStrings.errorUnexpected,
      ));
    }
  }

  @override
  Future<Either<Failure, JwtToken>> refreshToken() async {
    try {
      // If already refreshing, wait for the result
      if (_isRefreshing) {
        final completer = Completer<Either<Failure, JwtToken>>();
        _refreshCompleter.add(completer);
        return completer.future;
      }

      _isRefreshing = true;

      final currentToken = await localDataSource.getToken();

      if (currentToken == null || currentToken.refreshToken == null) {
        _notifyRefreshComplete(const Left(AuthenticationFailure(
          message: AppStrings.errorNoRefreshToken,
          code: AppStrings.errorCodeNoToken,
        )));
        return const Left(AuthenticationFailure(
          message: AppStrings.errorNoRefreshToken,
          code: AppStrings.errorCodeNoToken,
        ));
      }

      // Call refresh endpoint
      final response = await apiClient.post(
        '/api/v1/auth/refresh',
        data: {
          'refresh_token': currentToken.refreshToken,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // Create new token from response
        final newToken = JwtToken(
          token: data['access_token'] as String,
          type: data['token_type'] as String? ?? 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(
            Duration(seconds: data['expires_in'] as int? ?? 900), // Default 15 minutes
          ),
          refreshToken: data['refresh_token'] as String? ?? currentToken.refreshToken,
          csrfToken: currentToken.csrfToken, // Keep existing CSRF token
        );

        // Store the new token
        await localDataSource.storeToken(newToken);

        // Update API client with new token
        apiClient.setAuthToken(newToken.token);

        // Notify listeners
        _tokenRefreshController.add(newToken);

        // Schedule next refresh
        _scheduleTokenRefresh(newToken);

        _notifyRefreshComplete(Right(newToken));
        return Right(newToken);
      }

      _notifyRefreshComplete(const Left(ServerFailure(
        message: AppStrings.errorOAuthRefreshTokenFailed,
      )));
      return const Left(ServerFailure(
        message: AppStrings.errorOAuthRefreshTokenFailed,
      ));
    } on DioException catch (e) {
      final failure = e.response?.statusCode == 401
          ? const AuthenticationFailure(
              message: AppStrings.errorInvalidRefreshToken,
              code: AppStrings.errorCodeInvalidToken,
            )
          : const NetworkFailure(
              message: AppStrings.errorNetworkGeneral,
            );

      _notifyRefreshComplete(Left(failure));

      // Clear tokens if refresh token is invalid
      if (e.response?.statusCode == 401) {
        await clearTokens();
      }

      return Left(failure);
    } catch (e) {
      _notifyRefreshComplete(const Left(UnexpectedFailure(
        message: AppStrings.errorUnexpected,
      )));
      return const Left(UnexpectedFailure(
        message: AppStrings.errorUnexpected,
      ));
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Future<Either<Failure, Unit>> storeToken(JwtToken token) async {
    try {
      await localDataSource.storeToken(token);

      // Update API client
      apiClient.setAuthToken(token.authorizationHeader);
      if (token.csrfToken != null) {
        apiClient.setCsrfToken(token.csrfToken);
      }

      // Notify auth state change
      _authStateController.add(true);

      // Start auto refresh
      _scheduleTokenRefresh(token);

      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure(
        message: AppStrings.errorCacheFailed,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearTokens() async {
    try {
      await localDataSource.clearAll();

      // Clear tokens from API client
      apiClient.clearTokens();

      // Stop auto refresh
      stopAutoRefresh();

      // Notify auth state change
      _authStateController.add(false);
      _tokenRefreshController.add(null);

      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure(
        message: AppStrings.errorCacheFailed,
      ));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final token = await localDataSource.getToken();
      if (token == null) return false;

      // If token is expired but we have a refresh token, try to refresh
      if (token.isExpired && token.refreshToken != null) {
        final refreshResult = await refreshToken();
        return refreshResult.isRight();
      }

      return !token.isExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  void startAutoRefresh() {
    _scheduleNextRefresh();
  }

  @override
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  Stream<JwtToken?> get tokenRefreshStream => _tokenRefreshController.stream;

  void dispose() {
    stopAutoRefresh();
    _authStateController.close();
    _tokenRefreshController.close();
  }

  // Private helper methods

  void _scheduleTokenRefresh(JwtToken token) {
    stopAutoRefresh();

    // Calculate when to refresh (5 minutes before expiry)
    final refreshTime = token.expiresAt.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    if (refreshTime.isAfter(now)) {
      final duration = refreshTime.difference(now);
      _refreshTimer = Timer(duration, () async {
        await refreshToken();
      });
    }
  }

  void _scheduleNextRefresh() async {
    final token = await localDataSource.getToken();
    if (token != null && !token.isExpired) {
      _scheduleTokenRefresh(token);
    }
  }

  void _notifyRefreshComplete(Either<Failure, JwtToken> result) {
    for (final completer in _refreshCompleter) {
      completer.complete(result);
    }
    _refreshCompleter.clear();
  }

  // Helper extension for unawaited futures
  void unawaited(Future<void> future) {
    future.catchError((error) {
      // Log error but don't throw
      print('Background refresh error: $error');
    });
  }
}