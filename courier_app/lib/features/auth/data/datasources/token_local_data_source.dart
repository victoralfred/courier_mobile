import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/jwt_token.dart';

/// Local data source for JWT token management
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

/// Implementation using Flutter Secure Storage
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