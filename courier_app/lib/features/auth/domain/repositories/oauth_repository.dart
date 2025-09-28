import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/authorization_request.dart';
import '../entities/oauth_provider.dart';
import '../entities/token_response.dart';
import '../entities/user.dart';

/// Repository interface for OAuth2 authentication operations.
abstract class OAuthRepository {
  /// Generates an OAuth2 authorization URL with PKCE.
  /// Returns an [AuthorizationRequest] containing the URL and associated data.
  Future<Either<Failure, AuthorizationRequest>> generateAuthorizationRequest(
    OAuthProvider provider,
  );

  /// Exchanges an authorization code for tokens.
  /// Validates the state parameter and uses the PKCE verifier.
  Future<Either<Failure, TokenResponse>> exchangeCodeForToken({
    required String code,
    required String state,
    required AuthorizationRequest request,
  });

  /// Refreshes an access token using a refresh token.
  Future<Either<Failure, TokenResponse>> refreshToken(
    String refreshToken,
    OAuthProvider provider,
  );

  /// Revokes an access or refresh token.
  Future<Either<Failure, Unit>> revokeToken(
    String token,
    OAuthProvider provider,
  );

  /// Fetches user information from the OAuth provider.
  Future<Either<Failure, User>> fetchUserInfo(
    String accessToken,
    OAuthProvider provider,
  );

  /// Links an OAuth account to an existing user account.
  Future<Either<Failure, User>> linkOAuthAccount(
    String userId,
    OAuthProvider provider,
    String accessToken,
  );

  /// Unlinks an OAuth account from a user account.
  Future<Either<Failure, Unit>> unlinkOAuthAccount(
    String userId,
    OAuthProviderType providerType,
  );

  /// Gets the list of linked OAuth providers for a user.
  Future<Either<Failure, List<OAuthProviderType>>> getLinkedProviders(
    String userId,
  );

  /// Stores the authorization request for later validation.
  Future<Either<Failure, Unit>> storeAuthorizationRequest(
    AuthorizationRequest request,
  );

  /// Retrieves a stored authorization request by state.
  Future<Either<Failure, AuthorizationRequest>> getAuthorizationRequest(
    String state,
  );

  /// Cleans up expired authorization requests.
  Future<Either<Failure, Unit>> cleanupExpiredRequests();
}