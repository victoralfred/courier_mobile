import 'package:dio/dio.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/entities/authorization_request.dart';
import '../../domain/entities/oauth_provider.dart';
import '../../domain/entities/pkce_challenge.dart';
import '../../domain/entities/token_response.dart';
import '../../domain/entities/user.dart';
import '../utils/pkce_utils.dart';

/// Abstract interface for OAuth remote data source operations.
abstract class OAuthRemoteDataSource {
  /// Generates an OAuth2 authorization URL with PKCE.
  Future<AuthorizationRequest> generateAuthorizationUrl(
    OAuthProvider provider,
  );

  /// Exchanges an authorization code for tokens.
  Future<TokenResponse> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
    required OAuthProvider provider,
  });

  /// Refreshes an access token using a refresh token.
  Future<TokenResponse> refreshToken({
    required String refreshToken,
    required OAuthProvider provider,
  });

  /// Revokes a token (access or refresh).
  Future<void> revokeToken({
    required String token,
    required OAuthProvider provider,
  });

  /// Fetches user information from the OAuth provider.
  Future<User> fetchUserInfo({
    required String accessToken,
    required OAuthProvider provider,
  });
}

/// Implementation of OAuth remote data source.
class OAuthRemoteDataSourceImpl implements OAuthRemoteDataSource {
  final ApiClient apiClient;
  final Dio oauthDio; // Separate Dio instance for OAuth providers

  OAuthRemoteDataSourceImpl({
    required this.apiClient,
    Dio? oauthDio,
  }) : oauthDio = oauthDio ?? Dio();

  @override
  Future<AuthorizationRequest> generateAuthorizationUrl(
    OAuthProvider provider,
  ) async {
    try {
      // Generate PKCE challenge
      final codeVerifier = PKCEUtils.generateCodeVerifier();
      final codeChallenge = PKCEUtils.generateCodeChallenge(codeVerifier);
      final state = PKCEUtils.generateState();
      final nonce = provider.type == OAuthProviderType.google
          ? PKCEUtils.generateNonce()
          : null;

      // Create PKCE challenge entity
      final pkceChallenge = PKCEChallenge(
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        method: AppStrings.oauthValueS256,
        createdAt: DateTime.now(),
      );

      // Build authorization URL
      final authorizationUrl = provider.buildAuthorizationUrl(
        state: state,
        codeChallenge: codeChallenge,
        codeChallengeMethod: AppStrings.oauthValueS256,
      );

      // Create authorization request
      final request = AuthorizationRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: provider,
        pkceChallenge: pkceChallenge,
        state: state,
        authorizationUrl: authorizationUrl,
        createdAt: DateTime.now(),
        nonce: nonce,
      );

      return request;
    } catch (e) {
      throw ServerException(
        message: AppStrings.format(
          AppStrings.errorOAuthProviderError,
          {
            AppStrings.oauthFieldProvider: provider.displayName,
            AppStrings.oauthFieldError: e.toString(),
          },
        ),
      );
    }
  }

  @override
  Future<TokenResponse> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
    required OAuthProvider provider,
  }) async {
    try {
      // First, exchange the code with our backend
      // The backend will validate with the OAuth provider
      final response = await apiClient.post(
        AppStrings.oauthApiCallback,
        data: {
          AppStrings.oauthFieldProvider: provider.type.name,
          AppStrings.oauthFieldCode: code,
          AppStrings.oauthFieldCodeVerifier: codeVerifier,
          AppStrings.oauthParamRedirectUri: provider.redirectUri,
        },
      );

      // Parse the token response
      if (response.statusCode == 200 && response.data != null) {
        return TokenResponse.fromJson(response.data);
      } else {
        throw const ServerException(
          message: AppStrings.errorOAuthTokenExchangeFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthenticationException(
          message: AppStrings.errorOAuthTokenExchangeFailed,
          code: AppStrings.oauthErrorCodeTokenExchangeFailed,
        );
      }
      throw ServerException(
        message: AppStrings.format(
          AppStrings.errorOAuthProviderError,
          {
            AppStrings.oauthFieldProvider: provider.displayName,
            AppStrings.oauthFieldError: e.message ?? AppStrings.errorUnknown,
          },
        ),
      );
    } catch (e) {
      throw ServerException(
        message: AppStrings.format(
          AppStrings.errorOAuthProviderError,
          {
            AppStrings.oauthFieldProvider: provider.displayName,
            AppStrings.oauthFieldError: e.toString(),
          },
        ),
      );
    }
  }

  @override
  Future<TokenResponse> refreshToken({
    required String refreshToken,
    required OAuthProvider provider,
  }) async {
    try {
      final response = await apiClient.post(
        AppStrings.oauthApiRefresh,
        data: {
          AppStrings.oauthFieldRefreshToken: refreshToken,
          AppStrings.oauthFieldProvider: provider.type.name,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return TokenResponse.fromJson(response.data);
      } else {
        throw const ServerException(
          message: AppStrings.errorOAuthRefreshTokenFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthenticationException(
          message: AppStrings.errorTokenExpired,
          code: AppStrings.errorCodeSessionExpired,
        );
      }
      throw const ServerException(
        message: AppStrings.errorOAuthRefreshTokenFailed,
      );
    }
  }

  @override
  Future<void> revokeToken({
    required String token,
    required OAuthProvider provider,
  }) async {
    try {
      // Revoke with our backend first
      await apiClient.post(
        AppStrings.oauthApiRevoke,
        data: {
          AppStrings.oauthFieldToken: token,
          AppStrings.oauthFieldProvider: provider.type.name,
        },
      );

      // If provider has revocation endpoint, revoke there too
      if (provider.revocationEndpoint != null) {
        await oauthDio.post(
          provider.revocationEndpoint!,
          data: {
            AppStrings.oauthFieldToken: token,
            AppStrings.oauthParamClientId: provider.clientId,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
      }
    } catch (e) {
      // Revocation errors are often non-critical
      // Log but don't throw
      print('${AppStrings.warningOAuthTokenRevocation}$e');
    }
  }

  @override
  Future<User> fetchUserInfo({
    required String accessToken,
    required OAuthProvider provider,
  }) async {
    try {
      // Fetch from our backend which will merge OAuth provider data
      final response = await apiClient.get(
        AppStrings.oauthApiUsersMe,
        options: Options(
          headers: {
            'Authorization': '${AppStrings.authorizationBearer}$accessToken',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return UserModel.fromJson(response.data);
      } else {
        throw ServerException(
          message: AppStrings.format(
            AppStrings.errorOAuthUserInfoFailed,
            {AppStrings.oauthFieldProvider: provider.displayName},
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthenticationException(
          message: AppStrings.errorTokenExpired,
          code: AppStrings.errorCodeSessionExpired,
        );
      }
      throw ServerException(
        message: AppStrings.format(
          AppStrings.errorOAuthUserInfoFailed,
          {'provider': provider.displayName},
        ),
      );
    }
  }
}

// AuthenticationException is imported from core/error/exceptions.dart
