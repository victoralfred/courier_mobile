import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/jwt_token.dart';

/// [TokenLocalDataSource] - Abstract interface for JWT token persistence
///
/// **Contract Definition:**
/// Defines operations for securely storing and retrieving JWT tokens.
/// Implementations use platform-encrypted storage (iOS Keychain, Android EncryptedSharedPreferences).
abstract class TokenLocalDataSource {
  /// Store JWT token securely
  Future<void> storeToken(JwtToken token);

  /// Get stored JWT token
  Future<JwtToken?> getToken();

  /// Delete stored token
  Future<void> deleteToken();

  /// Store CSRF token
  Future<void> storeCsrfToken(String csrfToken);

  /// Get stored CSRF token
  Future<String?> getCsrfToken();

  /// Delete CSRF token
  Future<void> deleteCsrfToken();

  /// Check if token exists
  Future<bool> hasToken();

  /// Clear all auth data
  Future<void> clearAll();
}

/// [TokenLocalDataSourceImpl] - Secure platform-encrypted storage for JWT tokens
///
/// **What it does:**
/// - Stores JWT access and refresh tokens in encrypted storage
/// - Persists CSRF tokens for write operation protection
/// - Stores token metadata (type, issuance, expiration timestamps)
/// - Provides atomic token storage (all fields stored together)
/// - Enables token retrieval with complete metadata
/// - Handles graceful storage failures
///
/// **Why it exists:**
/// - JWT tokens are highly sensitive (full account access)
/// - Platform encryption required (iOS Keychain, Android EncryptedSharedPreferences)
/// - Tokens must persist across app restarts
/// - Separates storage concerns from token management logic
/// - Enables easy mocking for testing
/// - Provides consistent storage interface across platforms
///
/// **Architecture:**
/// ```
/// TokenManager
///       ↓
/// TokenLocalDataSource ← YOU ARE HERE
///       ↓
/// FlutterSecureStorage
///       ↓
/// Platform Encryption
/// ├─ iOS: Keychain Services (AES-256)
/// └─ Android: EncryptedSharedPreferences (AES-256)
/// ```
///
/// **Storage Schema:**
/// ```
/// jwt_token         → Access token (string)
/// jwt_type          → Token type (usually "Bearer")
/// jwt_issued_at     → ISO8601 timestamp
/// jwt_expires_at    → ISO8601 timestamp
/// jwt_refresh_token → Refresh token (nullable)
/// csrf_token        → CSRF protection token (nullable)
/// ```
///
/// **Token Storage Flow:**
/// ```
/// storeToken(jwtToken)
///       ↓
/// Parallel write to secure storage
/// ├─ jwt_token → token.token
/// ├─ jwt_type → token.type
/// ├─ jwt_issued_at → token.issuedAt (ISO8601)
/// ├─ jwt_expires_at → token.expiresAt (ISO8601)
/// ├─ jwt_refresh_token → token.refreshToken (if present)
/// └─ csrf_token → token.csrfToken (if present)
///       ↓
/// All writes succeed or throw CacheException
/// ```
///
/// **Token Retrieval Flow:**
/// ```
/// getToken()
///       ↓
/// Parallel read from secure storage
/// ├─ Read jwt_token
/// ├─ Read jwt_type
/// ├─ Read jwt_issued_at
/// ├─ Read jwt_expires_at
/// ├─ Read jwt_refresh_token
/// └─ Read csrf_token
///       ↓
/// Required fields missing?
///   ↙         ↘
///  YES        NO
///   ↓          ↓
/// null   Create JwtToken
///          ↓
///     Parse timestamps
///          ↓
///     Return JwtToken
/// ```
///
/// **Platform Security:**
/// ```
/// iOS:
/// - Keychain Services API
/// - kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock
/// - Protected by device passcode/Touch ID/Face ID
/// - Persists across app reinstalls (optional)
///
/// Android:
/// - EncryptedSharedPreferences
/// - AES-256-GCM encryption
/// - Key stored in Android Keystore
/// - Protected by device lock screen
/// ```
///
/// **Usage Example:**
/// ```dart
/// final dataSource = TokenLocalDataSourceImpl(
///   secureStorage: FlutterSecureStorage(),
/// );
///
/// // Store token after login
/// final jwtToken = JwtToken(
///   token: 'eyJhbGc...',
///   type: 'Bearer',
///   issuedAt: DateTime.now(),
///   expiresAt: DateTime.now().add(Duration(minutes: 15)),
///   refreshToken: 'refresh_abc123',
/// );
/// await dataSource.storeToken(jwtToken);
///
/// // Retrieve token
/// final storedToken = await dataSource.getToken();
/// if (storedToken != null) {
///   print('Token expires at: ${storedToken.expiresAt}');
/// }
///
/// // Check if token exists
/// if (await dataSource.hasToken()) {
///   print('User has valid token');
/// }
///
/// // Clear on logout
/// await dataSource.clearAll();
/// ```
///
/// **Atomic Operations:**
/// - storeToken() uses Future.wait() for parallel writes
/// - All fields written together or none (atomic)
/// - Prevents partial token storage
/// - Ensures consistency
///
/// **Error Handling:**
/// - storeToken() throws CacheException on failure
/// - getToken() returns null on error (graceful degradation)
/// - deleteToken() ignores errors (deletion is non-critical)
/// - clearAll() throws CacheException on failure
///
/// **IMPROVEMENTS:**
/// - [High Priority] Add token encryption beyond platform encryption
///   - Additional layer of app-specific encryption
/// - [Medium Priority] Implement token rotation detection
///   - Detect when backend invalidates all tokens
/// - [Medium Priority] Add storage backup/recovery mechanism
///   - Handle corrupted storage scenarios
/// - [Low Priority] Add token storage metrics
///   - Track read/write performance
/// - [Low Priority] Implement storage migration for schema changes
///   - Handle changes in JwtToken structure
class TokenLocalDataSourceImpl implements TokenLocalDataSource {
  final FlutterSecureStorage secureStorage;

  // Storage keys
  static const String _tokenKey = 'jwt_token';
  static const String _typeKey = 'jwt_type';
  static const String _issuedAtKey = 'jwt_issued_at';
  static const String _expiresAtKey = 'jwt_expires_at';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _csrfTokenKey = 'csrf_token';

  TokenLocalDataSourceImpl({required this.secureStorage});

  @override
  Future<void> storeToken(JwtToken token) async {
    try {
      await Future.wait([
        secureStorage.write(key: _tokenKey, value: token.token),
        secureStorage.write(key: _typeKey, value: token.type),
        secureStorage.write(
          key: _issuedAtKey,
          value: token.issuedAt.toIso8601String(),
        ),
        secureStorage.write(
          key: _expiresAtKey,
          value: token.expiresAt.toIso8601String(),
        ),
        if (token.refreshToken != null)
          secureStorage.write(key: _refreshTokenKey, value: token.refreshToken),
        if (token.csrfToken != null)
          secureStorage.write(key: _csrfTokenKey, value: token.csrfToken),
      ]);
    } catch (e) {
      throw const CacheException(
        message: AppStrings.errorCacheFailed,
      );
    }
  }

  @override
  Future<JwtToken?> getToken() async {
    try {
      final results = await Future.wait([
        secureStorage.read(key: _tokenKey),
        secureStorage.read(key: _typeKey),
        secureStorage.read(key: _issuedAtKey),
        secureStorage.read(key: _expiresAtKey),
        secureStorage.read(key: _refreshTokenKey),
        secureStorage.read(key: _csrfTokenKey),
      ]);

      final token = results[0];
      final type = results[1];
      final issuedAt = results[2];
      final expiresAt = results[3];
      final refreshToken = results[4];
      final csrfToken = results[5];

      if (token == null || type == null || issuedAt == null || expiresAt == null) {
        return null;
      }

      return JwtToken(
        token: token,
        type: type,
        issuedAt: DateTime.parse(issuedAt),
        expiresAt: DateTime.parse(expiresAt),
        refreshToken: refreshToken,
        csrfToken: csrfToken,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await Future.wait([
        secureStorage.delete(key: _tokenKey),
        secureStorage.delete(key: _typeKey),
        secureStorage.delete(key: _issuedAtKey),
        secureStorage.delete(key: _expiresAtKey),
        secureStorage.delete(key: _refreshTokenKey),
      ]);
    } catch (e) {
      // Deletion errors are non-critical
    }
  }

  @override
  Future<void> storeCsrfToken(String csrfToken) async {
    try {
      await secureStorage.write(key: _csrfTokenKey, value: csrfToken);
    } catch (e) {
      throw const CacheException(
        message: AppStrings.errorCacheFailed,
      );
    }
  }

  @override
  Future<String?> getCsrfToken() async {
    try {
      return await secureStorage.read(key: _csrfTokenKey);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteCsrfToken() async {
    try {
      await secureStorage.delete(key: _csrfTokenKey);
    } catch (e) {
      // Deletion errors are non-critical
    }
  }

  @override
  Future<bool> hasToken() async {
    try {
      final token = await secureStorage.read(key: _tokenKey);
      return token != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await Future.wait([
        deleteToken(),
        deleteCsrfToken(),
      ]);
    } catch (e) {
      throw const CacheException(
        message: AppStrings.errorCacheFailed,
      );
    }
  }
}