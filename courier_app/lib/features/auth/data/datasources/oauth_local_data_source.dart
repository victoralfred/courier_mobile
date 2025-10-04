import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/authorization_request.dart';
import '../../domain/entities/oauth_provider.dart';
import '../../domain/entities/pkce_challenge.dart';
import '../../domain/entities/token_response.dart';
import '../config/oauth_config.dart';

/// Local data source for OAuth operations
abstract class OAuthLocalDataSource {
  /// Store an authorization request locally
  Future<void> storeAuthorizationRequest(AuthorizationRequest request);

  /// Get a stored authorization request by state
  Future<AuthorizationRequest?> getAuthorizationRequest(String state);

  /// Delete an authorization request
  Future<void> deleteAuthorizationRequest(String state);

  /// Clean up expired authorization requests
  Future<void> cleanupExpiredRequests();

  /// Store linked OAuth providers for a user
  Future<void> storeLinkedProviders(String userId, List<OAuthProviderType> providers);

  /// Get linked OAuth providers for a user
  Future<List<OAuthProviderType>> getLinkedProviders(String userId);

  /// Cache OAuth tokens securely
  Future<void> cacheTokens(String key, TokenResponse tokens);

  /// Get cached OAuth tokens
  Future<TokenResponse?> getCachedTokens(String key);

  /// Clear all OAuth data
  Future<void> clearAll();
}

/// Implementation of OAuth local data source using secure storage
class OAuthLocalDataSourceImpl implements OAuthLocalDataSource {
  final FlutterSecureStorage secureStorage;

  // Storage key prefixes
  static const String _authRequestPrefix = AppStrings.oauthStoragePrefixAuthRequest;
  static const String _linkedProvidersPrefix = AppStrings.oauthStoragePrefixLinkedProviders;
  static const String _tokenCachePrefix = AppStrings.oauthStoragePrefixTokenCache;
  static const String _requestIndexKey = AppStrings.oauthStorageKeyRequestIndex;

  OAuthLocalDataSourceImpl({
    required this.secureStorage,
  });

  @override
  Future<void> storeAuthorizationRequest(AuthorizationRequest request) async {
    try {
      final key = '$_authRequestPrefix${request.state}';
      final json = _encodeAuthorizationRequest(request);
      await secureStorage.write(key: key, value: json);

      // Update the index of all requests for cleanup
      await _updateRequestIndex(request.state, add: true);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpStoreAuthRequest, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  @override
  Future<AuthorizationRequest?> getAuthorizationRequest(String state) async {
    try {
      final key = '$_authRequestPrefix$state';
      final json = await secureStorage.read(key: key);

      if (json == null) {
        return null;
      }

      return _decodeAuthorizationRequest(json);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpGetAuthRequest, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> deleteAuthorizationRequest(String state) async {
    try {
      final key = '$_authRequestPrefix$state';
      await secureStorage.delete(key: key);

      // Update the index
      await _updateRequestIndex(state, add: false);
    } catch (e) {
      // Deletion errors are non-critical
      print('${AppStrings.warningOAuthDeleteAuthRequest}$e');
    }
  }

  @override
  Future<void> cleanupExpiredRequests() async {
    try {
      // Get the index of all stored requests
      final indexJson = await secureStorage.read(key: _requestIndexKey);
      if (indexJson == null) return;

      final List<dynamic> index = json.decode(indexJson);
      final List<String> expiredStates = [];

      // Check each request
      for (final state in index) {
        final request = await getAuthorizationRequest(state as String);
        if (request != null && request.isExpired) {
          expiredStates.add(state);
        }
      }

      // Delete expired requests
      for (final state in expiredStates) {
        await deleteAuthorizationRequest(state);
      }
    } catch (e) {
      // Cleanup errors are non-critical
      print('${AppStrings.warningOAuthCleanupExpired}$e');
    }
  }

  @override
  Future<void> storeLinkedProviders(
    String userId,
    List<OAuthProviderType> providers,
  ) async {
    try {
      final key = '$_linkedProvidersPrefix$userId';
      final providersJson = providers.map((p) => p.name).join(',');
      await secureStorage.write(key: key, value: providersJson);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpStoreLinkedProviders, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  @override
  Future<List<OAuthProviderType>> getLinkedProviders(String userId) async {
    try {
      final key = '$_linkedProvidersPrefix$userId';
      final providersJson = await secureStorage.read(key: key);

      if (providersJson == null || providersJson.isEmpty) {
        return [];
      }

      return providersJson
          .split(',')
          .map((name) => _providerTypeFromString(name))
          .where((provider) => provider != null)
          .cast<OAuthProviderType>()
          .toList();
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpGetLinkedProviders, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> cacheTokens(String key, TokenResponse tokens) async {
    try {
      final cacheKey = '$_tokenCachePrefix$key';
      final json = jsonEncode(tokens.toJson());
      await secureStorage.write(key: cacheKey, value: json);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpCacheTokens, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  @override
  Future<TokenResponse?> getCachedTokens(String key) async {
    try {
      final cacheKey = '$_tokenCachePrefix$key';
      final json = await secureStorage.read(key: cacheKey);

      if (json == null) {
        return null;
      }

      final tokenData = jsonDecode(json) as Map<String, dynamic>;
      final tokens = TokenResponse.fromJson(tokenData);

      // Check if tokens are expired
      if (tokens.isExpired) {
        await secureStorage.delete(key: cacheKey);
        return null;
      }

      return tokens;
    } catch (e) {
      // Return null on any error
      return null;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      // Get all keys
      final allData = await secureStorage.readAll();

      // Filter OAuth-related keys
      final oauthKeys = allData.keys.where(
        (key) =>
            key.startsWith(_authRequestPrefix) ||
            key.startsWith(_linkedProvidersPrefix) ||
            key.startsWith(_tokenCachePrefix) ||
            key == _requestIndexKey,
      );

      // Delete all OAuth keys
      for (final key in oauthKeys) {
        await secureStorage.delete(key: key);
      }
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {AppStrings.oauthFieldOperation: AppStrings.oauthOpClearAllData, AppStrings.oauthFieldError: e.toString()},
        ),
      );
    }
  }

  // Helper methods

  Future<void> _updateRequestIndex(String state, {required bool add}) async {
    try {
      final indexJson = await secureStorage.read(key: _requestIndexKey);
      List<String> index = [];

      if (indexJson != null) {
        index = List<String>.from(json.decode(indexJson));
      }

      if (add) {
        if (!index.contains(state)) {
          index.add(state);
        }
      } else {
        index.remove(state);
      }

      await secureStorage.write(
        key: _requestIndexKey,
        value: json.encode(index),
      );
    } catch (e) {
      // Index update errors are non-critical
      print('${AppStrings.warningOAuthUpdateIndex}$e');
    }
  }

  String _encodeAuthorizationRequest(AuthorizationRequest request) {
    final data = {
      'id': request.id,
      'provider_type': request.provider.type.name,
      'state': request.state,
      'authorization_url': request.authorizationUrl,
      'created_at': request.createdAt.toIso8601String(),
      'nonce': request.nonce,
      'is_used': request.isUsed,
      'pkce': {
        'code_verifier': request.pkceChallenge.codeVerifier,
        'code_challenge': request.pkceChallenge.codeChallenge,
        'method': request.pkceChallenge.method,
        'created_at': request.pkceChallenge.createdAt.toIso8601String(),
      },
    };

    return json.encode(data);
  }

  AuthorizationRequest _decodeAuthorizationRequest(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final pkceData = data['pkce'] as Map<String, dynamic>;

    final providerType = _providerTypeFromString(data['provider_type'])!;
    final provider = OAuthConfig.getProvider(providerType);

    final pkceChallenge = PKCEChallenge(
      codeVerifier: pkceData['code_verifier'] as String,
      codeChallenge: pkceData['code_challenge'] as String,
      method: pkceData['method'] as String,
      createdAt: DateTime.parse(pkceData['created_at'] as String),
    );

    return AuthorizationRequest(
      id: data['id'] as String,
      provider: provider,
      pkceChallenge: pkceChallenge,
      state: data['state'] as String,
      authorizationUrl: data['authorization_url'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      nonce: data['nonce'] as String?,
      isUsed: data['is_used'] as bool? ?? false,
    );
  }

  OAuthProviderType? _providerTypeFromString(String value) {
    try {
      return OAuthProviderType.values.firstWhere(
        (e) => e.name == value,
      );
    } catch (e) {
      return null;
    }
  }
}