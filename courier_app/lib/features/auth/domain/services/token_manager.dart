import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/jwt_token.dart';

/// [TokenManager] - Service interface for managing JWT and CSRF tokens
///
/// **What it does:**
/// - Manages JWT access and refresh tokens
/// - Handles CSRF token for write operations
/// - Provides automatic token refresh before expiration
/// - Stores tokens in secure storage
/// - Exposes authentication state as reactive streams
/// - Prevents concurrent refresh attempts (single flight)
///
/// **Why it exists:**
/// - Centralizes all token management logic
/// - Prevents token expiration errors (auto-refresh)
/// - Separates token concerns from business logic
/// - Enables reactive authentication state (Stream-based)
/// - Secure token storage (encrypted at rest)
/// - Makes authentication testable (mock interface)
///
/// **Token Types:**
/// - **Access Token (JWT)**: Short-lived (15 minutes), used for API authentication
/// - **Refresh Token (JWT)**: Long-lived (7 days), used to get new access tokens
/// - **CSRF Token**: Ephemeral (per-request or short TTL), protects write operations
///
/// **Auto-Refresh Flow:**
/// ```
/// Access Token Expires in 2 minutes
///        ↓
/// Auto-refresh timer triggers
///        ↓
/// POST /auth/refresh {refresh_token}
///        ↓
/// Receive new access + refresh tokens
///        ↓
/// Store new tokens securely
///        ↓
/// Emit new tokens to tokenRefreshStream
///        ↓
/// Update ApiClient with new access token
/// ```
///
/// **Architecture:**
/// ```
/// TokenManager (Interface)
///      ↑
///      │ implements
///      │
/// TokenManagerImpl
///      ↓
/// SecureStorage (flutter_secure_storage)
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Initialize token manager
/// final tokenManager = GetIt.I<TokenManager>();
///
/// // Start auto-refresh on login
/// tokenManager.startAutoRefresh();
///
/// // Get access token for API calls
/// final result = await tokenManager.getAccessToken();
/// result.fold(
///   (failure) => print('No access token'),
///   (token) => apiClient.setAuthToken(token),
/// );
///
/// // Listen to auth state changes
/// tokenManager.authStateChanges.listen((isAuthenticated) {
///   if (!isAuthenticated) {
///     navigateToLogin();
///   }
/// });
///
/// // Logout - clear all tokens
/// await tokenManager.clearTokens();
/// tokenManager.stopAutoRefresh();
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add token refresh mutex (prevent concurrent refreshes)
/// - [High Priority] Add refresh retry with exponential backoff
/// - [Medium Priority] Add token expiry notification (warn before expiration)
/// - [Medium Priority] Support multiple token types (OAuth, API keys)
/// - [Low Priority] Add token metrics (refresh count, failure rate)
abstract class TokenManager {
  /// Gets current JWT access token
  ///
  /// **What it does:**
  /// - Retrieves access token from secure storage
  /// - Returns raw JWT string
  /// - Does NOT validate expiration (use isAuthenticated for validation)
  ///
  /// **Returns:**
  /// - Right(String): Access token found
  /// - Left(CacheFailure): No access token (not authenticated)
  /// - Left(StorageFailure): Secure storage error
  ///
  /// **Use cases:**
  /// - Injecting into API client Authorization header
  /// - Manual API calls outside repository pattern
  /// - WebSocket authentication
  ///
  /// **Example:**
  /// ```dart
  /// final result = await tokenManager.getAccessToken();
  /// result.fold(
  ///   (failure) => print('Not authenticated'),
  ///   (token) => print('Token: $token'),
  /// );
  /// ```
  Future<Either<Failure, String>> getAccessToken();

  /// Gets current CSRF token for write operations
  ///
  /// **What it does:**
  /// - Fetches fresh CSRF token from backend
  /// - Returns ephemeral token (single-use or short TTL)
  /// - Used for POST, PUT, DELETE, PATCH requests
  ///
  /// **Returns:**
  /// - Right(String): CSRF token retrieved
  /// - Left(NetworkFailure): Network error
  /// - Left(AuthFailure): Not authenticated (need login)
  ///
  /// **Use cases:**
  /// - Injecting into X-CSRF-Token header (via CsrfInterceptor)
  /// - Protecting state-changing operations
  ///
  /// **Example:**
  /// ```dart
  /// final result = await tokenManager.getCsrfToken();
  /// result.fold(
  ///   (failure) => print('Failed to get CSRF token'),
  ///   (token) => headers['X-CSRF-Token'] = token,
  /// );
  /// ```
  Future<Either<Failure, String>> getCsrfToken();

  /// Refreshes access token using refresh token
  ///
  /// **What it does:**
  /// 1. Gets current refresh token from storage
  /// 2. Calls backend /auth/refresh endpoint
  /// 3. Receives new access + refresh tokens
  /// 4. Stores new tokens in secure storage
  /// 5. Emits new token to tokenRefreshStream
  /// 6. Returns new JwtToken entity
  ///
  /// **When called:**
  /// - Automatically by auto-refresh timer (before expiration)
  /// - Manually on 401 Unauthorized response
  /// - On app startup (if access token expired)
  ///
  /// **Flow:**
  /// ```
  /// POST /auth/refresh
  /// Body: {refresh_token: "..."}
  ///   ↓
  /// Response: {access_token: "...", refresh_token: "..."}
  ///   ↓
  /// Store new tokens
  ///   ↓
  /// Emit to tokenRefreshStream
  /// ```
  ///
  /// **Returns:**
  /// - Right(JwtToken): Refresh successful, new tokens stored
  /// - Left(AuthFailure): Refresh token expired or invalid (need re-login)
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await tokenManager.refreshToken();
  /// result.fold(
  ///   (failure) => logout(), // Refresh failed, force re-login
  ///   (newToken) => print('Token refreshed successfully'),
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add mutex to prevent concurrent refresh attempts
  /// - [High Priority] Add retry logic with exponential backoff
  Future<Either<Failure, JwtToken>> refreshToken();

  /// Stores JWT token (access + refresh) in secure storage
  ///
  /// **What it does:**
  /// - Saves access token to secure storage
  /// - Saves refresh token to secure storage
  /// - Encrypts tokens at rest (flutter_secure_storage)
  /// - Emits authentication state change
  ///
  /// **When called:**
  /// - After successful login
  /// - After successful registration
  /// - After token refresh
  ///
  /// **Parameters:**
  /// - [token]: JwtToken entity containing access and refresh tokens
  ///
  /// **Returns:**
  /// - Right(Unit): Tokens stored successfully
  /// - Left(StorageFailure): Secure storage error
  ///
  /// **Example:**
  /// ```dart
  /// final jwtToken = JwtToken(
  ///   accessToken: 'eyJhbGc...',
  ///   refreshToken: 'eyJhbGc...',
  ///   expiresIn: 900,
  /// );
  /// await tokenManager.storeToken(jwtToken);
  /// ```
  Future<Either<Failure, Unit>> storeToken(JwtToken token);

  /// Clears all stored tokens (logout)
  ///
  /// **What it does:**
  /// - Deletes access token from secure storage
  /// - Deletes refresh token from secure storage
  /// - Deletes CSRF token cache (if applicable)
  /// - Emits authentication state change (false)
  /// - Does NOT call backend logout endpoint (handled by repository)
  ///
  /// **When called:**
  /// - During logout
  /// - On authentication failure (refresh token expired)
  /// - On session timeout
  ///
  /// **Returns:**
  /// - Right(Unit): Tokens cleared successfully
  /// - Left(StorageFailure): Secure storage error (still clears tokens)
  ///
  /// **Example:**
  /// ```dart
  /// await tokenManager.clearTokens();
  /// tokenManager.stopAutoRefresh();
  /// navigateToLogin();
  /// ```
  Future<Either<Failure, Unit>> clearTokens();

  /// Checks if user is currently authenticated
  ///
  /// **What it does:**
  /// - Checks if access token exists in storage
  /// - Validates token expiration (decodes JWT)
  /// - Returns false if token expired
  /// - Does NOT make network request
  ///
  /// **Returns:** true if valid access token exists, false otherwise
  ///
  /// **Use cases:**
  /// - Route guarding (redirect to login if false)
  /// - App initialization (determine initial route)
  /// - Conditional UI rendering
  ///
  /// **Example:**
  /// ```dart
  /// final isAuth = await tokenManager.isAuthenticated();
  /// if (isAuth) {
  ///   navigateToHome();
  /// } else {
  ///   navigateToLogin();
  /// }
  /// ```
  Future<bool> isAuthenticated();

  /// Starts automatic token refresh timer
  ///
  /// **What it does:**
  /// - Calculates time until token expiration
  /// - Schedules refresh 2 minutes before expiration
  /// - Refreshes token automatically
  /// - Reschedules after each refresh
  ///
  /// **When to call:**
  /// - After successful login
  /// - After successful registration
  /// - On app startup (if already authenticated)
  ///
  /// **Example:**
  /// ```dart
  /// // After login
  /// await tokenManager.storeToken(jwtToken);
  /// tokenManager.startAutoRefresh(); // Start auto-refresh timer
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add configurable refresh window (currently 2 minutes before expiry)
  void startAutoRefresh();

  /// Stops automatic token refresh timer
  ///
  /// **What it does:**
  /// - Cancels scheduled refresh timer
  /// - Stops automatic token refresh
  ///
  /// **When to call:**
  /// - During logout
  /// - On authentication failure
  /// - On app disposal
  ///
  /// **Example:**
  /// ```dart
  /// // During logout
  /// await tokenManager.clearTokens();
  /// tokenManager.stopAutoRefresh(); // Stop refresh timer
  /// ```
  void stopAutoRefresh();

  /// Stream of authentication state changes
  ///
  /// **What it emits:**
  /// - true: User authenticated (has valid token)
  /// - false: User not authenticated (no token or expired)
  ///
  /// **When emitted:**
  /// - After login (true)
  /// - After logout (false)
  /// - After token refresh failure (false)
  /// - After token expiration (false)
  ///
  /// **Use cases:**
  /// - Reactive navigation (auto-navigate to login on logout)
  /// - Update UI based on auth state
  /// - Trigger side effects on auth changes
  ///
  /// **Example:**
  /// ```dart
  /// tokenManager.authStateChanges.listen((isAuthenticated) {
  ///   if (!isAuthenticated) {
  ///     navigateToLogin();
  ///   } else {
  ///     loadUserData();
  ///   }
  /// });
  /// ```
  Stream<bool> get authStateChanges;

  /// Stream of token refresh events
  ///
  /// **What it emits:**
  /// - JwtToken: New token after successful refresh
  /// - null: Token refresh failed or cleared
  ///
  /// **When emitted:**
  /// - After successful token refresh
  /// - After login (initial token)
  /// - After logout (null)
  ///
  /// **Use cases:**
  /// - Update ApiClient with new access token
  /// - Retry failed requests with new token
  /// - Log token refresh events
  ///
  /// **Example:**
  /// ```dart
  /// tokenManager.tokenRefreshStream.listen((token) {
  ///   if (token != null) {
  ///     apiClient.setAuthToken(token.accessToken);
  ///     print('Token refreshed at ${DateTime.now()}');
  ///   }
  /// });
  /// ```
  Stream<JwtToken?> get tokenRefreshStream;
}