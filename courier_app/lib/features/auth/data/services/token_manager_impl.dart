import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../domain/entities/jwt_token.dart';
import '../../domain/services/token_manager.dart';
import '../datasources/token_local_data_source.dart';

/// [TokenManagerImpl] - Concrete implementation of token management with automatic refresh
///
/// **What it does:**
/// - Manages JWT access and refresh tokens lifecycle
/// - Automatically refreshes tokens before expiration (5 min buffer)
/// - Prevents concurrent refresh attempts with locking mechanism
/// - Syncs tokens with ApiClient for authenticated requests
/// - Streams authentication state changes to UI
/// - Handles ephemeral CSRF token fetching from backend
///
/// **Why it exists:**
/// - Implements domain TokenManager interface with actual platform code
/// - Provides transparent token refresh (users don't see auth errors)
/// - Prevents race conditions when multiple requests need refresh
/// - Centralizes token storage/retrieval across app
/// - Separates token logic from business domain layer
///
/// **Architecture:**
/// ```
/// Presentation Layer
///        ↓
/// Domain Layer (TokenManager interface)
///        ↓
/// Data Layer (TokenManagerImpl) ← YOU ARE HERE
///        ↓
/// ├─ TokenLocalDataSource (secure storage)
/// └─ ApiClient (network requests)
/// ```
///
/// **Token Refresh Flow:**
/// ```
/// Request → getAccessToken()
///              ↓
///         Token expired?
///           ↙      ↘
///         NO       YES
///          ↓        ↓
///     Return     refreshToken()
///     token         ↓
///              _isRefreshing?
///               ↙        ↘
///             YES        NO
///              ↓          ↓
///        Wait for    Lock & refresh
///        existing       ↓
///        refresh    Store new token
///              ↓         ↓
///         Return new token
/// ```
///
/// **Concurrency Protection:**
/// ```
/// Request A ──┐
/// Request B ──┼─→ refreshToken()
/// Request C ──┘      ↓
///              _isRefreshing = true
///                     ↓
///         B & C wait (Completer queue)
///                     ↓
///              API call /users/refresh
///                     ↓
///         _notifyRefreshComplete()
///                     ↓
///         All requests get same token
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Setup (via dependency injection)
/// final tokenManager = TokenManagerImpl(
///   localDataSource: TokenLocalDataSourceImpl(),
///   apiClient: ApiClient(),
/// );
///
/// // Store token after login
/// final jwtToken = JwtToken(...);
/// await tokenManager.storeToken(jwtToken);
///
/// // Get access token (auto-refreshes if needed)
/// final result = await tokenManager.getAccessToken();
/// result.fold(
///   (failure) => print('Auth error: ${failure.message}'),
///   (token) => print('Token: $token'),
/// );
///
/// // Listen to auth state changes
/// tokenManager.authStateChanges.listen((isAuthenticated) {
///   if (!isAuthenticated) navigateToLogin();
/// });
///
/// // Cleanup
/// tokenManager.dispose();
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Remove print statement in unawaited() helper (line 336)
/// - Use proper logging service instead of console output
/// - [Medium Priority] Add token refresh retry logic with exponential backoff
/// - Currently fails immediately on network error
/// - [Medium Priority] Add metrics tracking (refresh success rate, timing)
/// - [Low Priority] Make refresh buffer time configurable (currently hardcoded 5 min)
/// - Different apps may need different buffer times
/// - [Low Priority] Add token validation before refresh (check format, signature)
/// - Currently trusts local storage token validity
class TokenManagerImpl implements TokenManager {
  /// Logger instance for token management operations
  static final _logger = AppLogger.auth();

  /// Local data source for token persistence
  ///
  /// **Why:**
  /// - Provides secure storage abstraction (FlutterSecureStorage internally)
  /// - Survives app restarts
  final TokenLocalDataSource localDataSource;

  /// API client for network requests
  ///
  /// **Why:**
  /// - Used to call token refresh endpoint
  /// - Tokens are synchronized with this client automatically
  final ApiClient apiClient;

  /// Timer for scheduled token refresh
  ///
  /// **Why:**
  /// - Proactively refreshes before expiration
  /// - Prevents users from experiencing auth errors
  Timer? _refreshTimer;

  /// Broadcast stream for authentication state changes
  ///
  /// **Why broadcast:**
  /// - Multiple UI widgets may need to listen
  /// - Login/logout events affect entire app
  final _authStateController = StreamController<bool>.broadcast();

  /// Broadcast stream for token refresh events
  ///
  /// **Why broadcast:**
  /// - Multiple components may need fresh token
  /// - Useful for debugging and monitoring
  final _tokenRefreshController = StreamController<JwtToken?>.broadcast();

  /// Lock flag to prevent concurrent refresh attempts
  ///
  /// **Why:**
  /// - Multiple API calls may trigger refresh simultaneously
  /// - Only one refresh should execute
  bool _isRefreshing = false;

  /// Queue of completers waiting for refresh to complete
  ///
  /// **Why:**
  /// - Requests during refresh need to wait
  /// - All get notified with same result
  final _refreshCompleter = <Completer<Either<Failure, JwtToken>>>[];

  TokenManagerImpl({
    required this.localDataSource,
    required this.apiClient,
  });

  /// Retrieves access token, automatically refreshing if expired or near expiration
  ///
  /// **What it does:**
  /// 1. Fetches token from local storage
  /// 2. Checks if token should be refreshed (within 5 min of expiry)
  /// 3. Triggers background refresh if needed (unawaited)
  /// 4. If fully expired, performs blocking refresh
  /// 5. Returns valid access token or failure
  ///
  /// **Why background refresh:**
  /// - Prevents blocking current request
  /// - Proactive refresh improves UX
  /// - Next request will have fresh token
  ///
  /// **Flow Diagram:**
  /// ```
  /// getAccessToken()
  ///       ↓
  /// Get from storage
  ///       ↓
  ///   Token exists?
  ///    ↙       ↘
  ///  NO        YES
  ///   ↓         ↓
  /// Return   shouldRefresh?
  /// error     ↙        ↘
  ///         YES        NO
  ///          ↓          ↓
  ///    Background    isExpired?
  ///    refresh        ↙      ↘
  ///                 YES      NO
  ///                  ↓        ↓
  ///          Blocking    Return
  ///          refresh     token
  /// ```
  ///
  /// **Returns:**
  /// - Right(String): Valid access token
  /// - Left(AuthenticationFailure): Token not found or expired without refresh token
  /// - Left(CacheFailure): Storage access failed
  ///
  /// **Edge Cases:**
  /// - No token in storage → Returns AuthenticationFailure
  /// - Expired token with no refresh token → Returns AuthenticationFailure
  /// - Expired token with refresh token → Attempts refresh, returns result
  /// - Storage exception → Returns CacheFailure
  ///
  /// **Example:**
  /// ```dart
  /// final result = await tokenManager.getAccessToken();
  /// result.fold(
  ///   (failure) {
  ///     if (failure is AuthenticationFailure) {
  ///       navigateToLogin();
  ///     }
  ///   },
  ///   (token) {
  ///     apiClient.setAuthToken(token);
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add telemetry for background vs blocking refresh ratio
  /// - [Low Priority] Make shouldRefresh threshold configurable
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

  /// Fetches ephemeral CSRF token from backend
  ///
  /// **What it does:**
  /// 1. Checks local storage for cached CSRF token (legacy behavior)
  /// 2. If not found, fetches fresh token from `/api/v1/auth/csrf`
  /// 3. Stores token in local cache
  /// 4. Returns CSRF token or failure
  ///
  /// **Why ephemeral:**
  /// - CSRF tokens should be short-lived for security
  /// - Each write operation should ideally get fresh token
  /// - Caching is minimal (this implementation has legacy caching)
  ///
  /// **Flow Diagram:**
  /// ```
  /// getCsrfToken()
  ///       ↓
  /// Check local cache
  ///       ↓
  ///   Cached token?
  ///    ↙       ↘
  ///  YES       NO
  ///   ↓         ↓
  /// Return   GET /api/v1/auth/csrf
  ///          ↓
  ///     Store & return
  /// ```
  ///
  /// **Returns:**
  /// - Right(String): Valid CSRF token
  /// - Left(ServerFailure): Backend error or invalid response
  /// - Left(AuthenticationFailure): 401 unauthorized
  /// - Left(NetworkFailure): Network connectivity issue
  /// - Left(UnexpectedFailure): Unexpected error
  ///
  /// **Edge Cases:**
  /// - 401 response → User needs to re-authenticate
  /// - Network timeout → Returns NetworkFailure
  /// - Invalid response structure → Returns ServerFailure
  ///
  /// **Example:**
  /// ```dart
  /// final result = await tokenManager.getCsrfToken();
  /// result.fold(
  ///   (failure) => print('CSRF error: ${failure.message}'),
  ///   (csrfToken) {
  ///     headers['X-CSRF-Token'] = csrfToken;
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Remove local caching entirely for true ephemeral tokens
  /// - Current caching reduces security benefit
  /// - [Medium Priority] Integrate with CsrfTokenManager instead of duplicating logic
  /// - TokenManager shouldn't handle CSRF directly
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

  /// Refreshes expired or expiring access token using refresh token
  ///
  /// **What it does:**
  /// 1. Checks if refresh is already in progress (concurrency lock)
  /// 2. If refreshing, queues request and waits for result
  /// 3. Validates refresh token exists
  /// 4. Calls `/users/refresh` endpoint with refresh token
  /// 5. Creates new JwtToken from response
  /// 6. Stores new token in local storage and ApiClient
  /// 7. Notifies all waiting requests
  /// 8. Schedules next auto-refresh
  ///
  /// **Why concurrency lock:**
  /// - Multiple API calls may trigger refresh simultaneously
  /// - Only one network request should execute
  /// - All waiting requests get the same new token
  /// - Prevents "thundering herd" problem
  ///
  /// **Flow Diagram:**
  /// ```
  /// refreshToken()
  ///       ↓
  ///  _isRefreshing?
  ///    ↙       ↘
  ///  YES       NO
  ///   ↓         ↓
  /// Add to   Set lock
  /// queue    _isRefreshing = true
  ///   ↓         ↓
  /// Wait    Get refresh token
  ///          ↓
  ///     POST /users/refresh
  ///          ↓
  ///     Parse response
  ///          ↓
  ///     Store new token
  ///          ↓
  ///     Update ApiClient
  ///          ↓
  ///     Notify queue
  ///          ↓
  ///     Schedule next refresh
  ///          ↓
  ///     Release lock
  /// ```
  ///
  /// **Returns:**
  /// - Right(JwtToken): Successfully refreshed token
  /// - Left(AuthenticationFailure): No refresh token or invalid refresh token (401)
  /// - Left(NetworkFailure): Network connectivity issue
  /// - Left(ServerFailure): Backend error
  /// - Left(UnexpectedFailure): Unexpected error
  ///
  /// **Edge Cases:**
  /// - No refresh token → Returns AuthenticationFailure immediately
  /// - 401 on refresh → Clears all tokens (forces re-login)
  /// - Network error → Keeps existing token (user may retry)
  /// - Concurrent calls → Only first call hits API, others wait
  ///
  /// **Example:**
  /// ```dart
  /// // Usually called automatically by getAccessToken()
  /// final result = await tokenManager.refreshToken();
  /// result.fold(
  ///   (failure) {
  ///     if (failure is AuthenticationFailure) {
  ///       // Refresh token invalid, force login
  ///       navigateToLogin();
  ///     }
  ///   },
  ///   (newToken) {
  ///     print('Token refreshed, expires: ${newToken.expiresAt}');
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add retry logic with exponential backoff
  /// - Single network glitch forces re-login
  /// - [Medium Priority] Add refresh token rotation support
  /// - Backend may issue new refresh token
  /// - [Low Priority] Add metrics for refresh duration and success rate
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
            Duration(
                seconds:
                    data['expires_in'] as int? ?? 900), // Default 15 minutes
          ),
          refreshToken:
              data['refresh_token'] as String? ?? currentToken.refreshToken,
          csrfToken: currentToken.csrfToken, // Keep existing CSRF token
        );

        // Store the new token
        await localDataSource.storeToken(newToken);

        // Update API client with new JWT token object
        apiClient.setAuthToken(newToken);

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

  /// Stores JWT token securely and initializes auto-refresh
  ///
  /// **What it does:**
  /// 1. Persists token to secure local storage
  /// 2. Updates ApiClient with new auth token
  /// 3. Emits authentication state change (true)
  /// 4. Schedules automatic token refresh
  ///
  /// **Why separate from login:**
  /// - Token storage logic is reusable (login, OAuth, token refresh)
  /// - Centralizes side effects (ApiClient sync, stream emit, auto-refresh)
  /// - Domain layer can call without knowing implementation details
  ///
  /// **Flow Diagram:**
  /// ```
  /// storeToken(token)
  ///       ↓
  /// Store in secure storage
  ///       ↓
  /// Update ApiClient.authToken
  ///       ↓
  /// Emit authStateChange(true)
  ///       ↓
  /// Schedule auto-refresh timer
  ///       ↓
  /// Return success
  /// ```
  ///
  /// **Returns:**
  /// - Right(Unit): Token stored successfully
  /// - Left(CacheFailure): Storage write failed
  ///
  /// **Example:**
  /// ```dart
  /// // After successful login
  /// final jwtToken = JwtToken(
  ///   token: 'eyJhbGc...',
  ///   refreshToken: 'refresh_abc123',
  ///   expiresAt: DateTime.now().add(Duration(minutes: 15)),
  /// );
  ///
  /// final result = await tokenManager.storeToken(jwtToken);
  /// result.fold(
  ///   (failure) => print('Failed to store token'),
  ///   (_) => print('Token stored, auto-refresh scheduled'),
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Low Priority] Add validation of token format before storing
  /// - Currently trusts input token structure
  @override
  Future<Either<Failure, Unit>> storeToken(JwtToken token) async {
    try {
      await localDataSource.storeToken(token);

      // Update API client with JWT token object
      // Note: CSRF tokens are now fetched automatically by CsrfInterceptor
      apiClient.setAuthToken(token);

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

  /// Clears all authentication tokens and stops auto-refresh
  ///
  /// **What it does:**
  /// 1. Deletes all tokens from secure local storage
  /// 2. Clears tokens from ApiClient
  /// 3. Cancels scheduled auto-refresh timer
  /// 4. Emits authentication state change (false)
  /// 5. Emits token refresh stream with null
  ///
  /// **Why complete cleanup:**
  /// - Ensures no stale tokens remain
  /// - Prevents unauthorized API requests
  /// - Notifies UI to update (show login screen)
  /// - Stops background refresh operations
  ///
  /// **Flow Diagram:**
  /// ```
  /// clearTokens()
  ///       ↓
  /// Delete from storage
  ///       ↓
  /// ApiClient.clearTokens()
  ///       ↓
  /// Cancel auto-refresh timer
  ///       ↓
  /// Emit authStateChange(false)
  ///       ↓
  /// Emit tokenRefresh(null)
  ///       ↓
  /// Return success
  /// ```
  ///
  /// **Returns:**
  /// - Right(Unit): Tokens cleared successfully
  /// - Left(CacheFailure): Storage deletion failed
  ///
  /// **Example:**
  /// ```dart
  /// // On logout
  /// final result = await tokenManager.clearTokens();
  /// result.fold(
  ///   (failure) => print('Warning: Failed to clear tokens'),
  ///   (_) {
  ///     print('Tokens cleared successfully');
  ///     navigateToLogin();
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add force logout to backend (revoke refresh token)
  /// - Currently only clears local tokens
  /// - [Low Priority] Add secure wipe for sensitive data
  /// - Overwrite storage before deletion for extra security
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
      _logger.error('Background token refresh failed', error: error, metadata: {
        'context': 'unawaited_future',
      });
    });
  }
}
