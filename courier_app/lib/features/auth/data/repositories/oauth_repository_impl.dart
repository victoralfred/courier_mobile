import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/authorization_request.dart';
import '../../domain/entities/oauth_provider.dart';
import '../../domain/entities/token_response.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/oauth_repository.dart';
import '../datasources/oauth_local_data_source.dart';
import '../datasources/oauth_remote_data_source.dart';

/// [OAuthRepositoryImpl] - OAuth 2.0 / OIDC authentication implementation
///
/// **What it does:**
/// - Implements OAuth 2.0 Authorization Code Flow with PKCE
/// - Supports multiple providers (Google, GitHub, Microsoft, Apple)
/// - Generates secure authorization URLs with state validation
/// - Exchanges authorization codes for access tokens
/// - Manages refresh token lifecycle
/// - Links/unlinks OAuth accounts to user profiles
/// - Validates state parameter to prevent CSRF attacks
/// - Cleans up expired authorization requests
///
/// **Why it exists:**
/// - Implements domain OAuthRepository interface with actual OAuth logic
/// - Enables social login (Google, GitHub, etc.)
/// - Provides more secure auth than password-based login
/// - Reduces friction (users don't need to remember password)
/// - Separates OAuth complexity from business logic
/// - Standardizes multi-provider authentication
///
/// **Architecture:**
/// ```
/// Presentation Layer (Login Screen)
///          ↓
/// Domain Layer (OAuth Use Cases)
///          ↓
/// Domain Repository Interface
///          ↓
/// Data Repository Implementation ← YOU ARE HERE
///          ↓
/// ├─ OAuthRemoteDataSource (API calls)
/// └─ OAuthLocalDataSource (state storage)
/// ```
///
/// **OAuth 2.0 Flow (with PKCE):**
/// ```
/// generateAuthorizationRequest()
///       ↓
/// Create PKCE challenge
///       ↓
/// Generate state token
///       ↓
/// Build authorization URL
///   ├─ client_id
///   ├─ redirect_uri
///   ├─ scope
///   ├─ state (CSRF protection)
///   └─ code_challenge (PKCE)
///       ↓
/// Store request locally
///       ↓
/// Return authorization URL
///       ↓
/// User authenticates with provider
///       ↓
/// Provider redirects with code & state
///       ↓
/// exchangeCodeForToken(code, state)
///       ↓
/// Validate state matches
///       ↓
/// POST /oauth/token
///   ├─ code
///   ├─ code_verifier (PKCE)
///   └─ client_id
///       ↓
/// Receive access_token & refresh_token
///       ↓
/// Delete authorization request
///       ↓
/// Return TokenResponse
/// ```
///
/// **PKCE (Proof Key for Code Exchange):**
/// ```
/// Client generates random verifier
///       ↓
/// Hash verifier → code_challenge
///       ↓
/// Send code_challenge to provider
///       ↓
/// Provider stores challenge
///       ↓
/// User authenticates
///       ↓
/// Client sends code + verifier
///       ↓
/// Provider verifies: hash(verifier) == challenge
///       ↓
/// If valid, issue tokens
/// ```
///
/// **State Validation (CSRF Protection):**
/// ```
/// 1. Generate random state
/// 2. Store state locally
/// 3. Include state in auth URL
/// 4. Provider includes state in callback
/// 5. Validate callback state matches stored state
/// 6. If mismatch → Reject (CSRF attack)
/// ```
///
/// **Supported Providers:**
/// - Google: OAuth 2.0 + OpenID Connect
/// - GitHub: OAuth 2.0
/// - Microsoft: OAuth 2.0 + OIDC
/// - Apple: Sign in with Apple (OIDC)
///
/// **Usage Example:**
/// ```dart
/// // 1. Generate authorization URL
/// final provider = OAuthProvider.google();
/// final result = await oauthRepository.generateAuthorizationRequest(provider);
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (request) {
///     // Open browser with authorization URL
///     launchUrl(request.authorizationUrl);
///   },
/// );
///
/// // 2. Handle callback (from deep link)
/// void handleCallback(String code, String state) async {
///   // Get stored request
///   final requestResult = await oauthRepository.getAuthorizationRequest(state);
///
///   requestResult.fold(
///     (failure) => showError('Invalid state'),
///     (request) async {
///       // Exchange code for tokens
///       final tokenResult = await oauthRepository.exchangeCodeForToken(
///         code: code,
///         state: state,
///         request: request,
///       );
///
///       tokenResult.fold(
///         (failure) => showError(failure.message),
///         (tokenResponse) {
///           // Fetch user info
///           final userResult = await oauthRepository.fetchUserInfo(
///             tokenResponse.accessToken,
///             provider,
///           );
///           // Handle user...
///         },
///       );
///     },
///   );
/// }
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Add token validation before use (verify signature, expiry)
/// - Currently trusts provider tokens without verification
/// - [High Priority] Implement authorization request TTL enforcement
/// - Expired requests should be auto-rejected
/// - [Medium Priority] Add provider-specific error handling
/// - Different providers return different error formats
/// - [Medium Priority] Implement token introspection endpoint
/// - Validate tokens with provider in real-time
/// - [Low Priority] Add OAuth 2.1 support when finalized
/// - PKCE will be mandatory in OAuth 2.1
/// - [Low Priority] Add metrics for OAuth flow completion rate
/// - Track where users drop off in flow
class OAuthRepositoryImpl implements OAuthRepository {
  /// Remote data source for OAuth API calls
  final OAuthRemoteDataSource remoteDataSource;

  /// Local data source for authorization state storage
  final OAuthLocalDataSource localDataSource;

  OAuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Generates OAuth authorization request with PKCE and state validation
  ///
  /// **What it does:**
  /// 1. Calls remote data source to generate auth URL
  /// 2. Remote source creates PKCE code challenge
  /// 3. Remote source generates random state token
  /// 4. Builds provider-specific authorization URL
  /// 5. Stores authorization request locally for validation
  /// 6. Returns AuthorizationRequest with URL and metadata
  ///
  /// **Why store request:**
  /// - State validation on callback (prevent CSRF)
  /// - PKCE code verifier needed for token exchange
  /// - Request expiration validation
  ///
  /// **Flow Diagram:**
  /// ```
  /// generateAuthorizationRequest(provider)
  ///       ↓
  /// Remote: Generate PKCE challenge
  ///       ↓
  /// Remote: Generate state token
  ///       ↓
  /// Remote: Build authorization URL
  ///       ↓
  /// Local: Store AuthorizationRequest
  ///       ↓
  /// Return request with URL
  /// ```
  ///
  /// **Returns:**
  /// - Right(AuthorizationRequest): Auth URL and metadata
  /// - Left(ServerFailure): Backend configuration error
  /// - Left(OAuthFailure): Provider-specific error
  ///
  /// **Edge Cases:**
  /// - Provider not configured → ServerException
  /// - Storage write fails → Still returns request (validation may fail later)
  ///
  /// **Example:**
  /// ```dart
  /// final provider = OAuthProvider.google();
  /// final result = await oauthRepository.generateAuthorizationRequest(provider);
  ///
  /// result.fold(
  ///   (failure) => showError('OAuth setup failed: ${failure.message}'),
  ///   (request) {
  ///     // Open browser/webview with authorization URL
  ///     launchUrl(request.authorizationUrl);
  ///     print('State: ${request.state}');
  ///     print('Expires: ${request.expiresAt}');
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add custom scope support per provider
  /// - Currently uses default scopes
  /// - [Low Priority] Add authorization URL preview/debugging
  @override
  Future<Either<Failure, AuthorizationRequest>> generateAuthorizationRequest(
    OAuthProvider provider,
  ) async {
    try {
      final request = await remoteDataSource.generateAuthorizationUrl(provider);

      // Store the request for later validation
      await localDataSource.storeAuthorizationRequest(request);

      return Right(request);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthProviderError,
            {
              'provider': provider.displayName,
              'error': e.toString(),
            },
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  /// Exchanges authorization code for access and refresh tokens
  ///
  /// **What it does:**
  /// 1. Validates state parameter matches stored request (CSRF protection)
  /// 2. Validates authorization request is still valid (not expired)
  /// 3. Calls token endpoint with code and PKCE verifier
  /// 4. Receives access_token, refresh_token, and metadata
  /// 5. Deletes used authorization request (one-time use)
  /// 6. Returns TokenResponse
  ///
  /// **Why state validation is critical:**
  /// - Prevents CSRF attacks (malicious callback injection)
  /// - Ensures callback matches original request
  /// - Required by OAuth 2.0 security best practices
  ///
  /// **Why PKCE verifier:**
  /// - Proves client initiated the request
  /// - Prevents authorization code interception attacks
  /// - Required for public clients (mobile apps)
  ///
  /// **Flow Diagram:**
  /// ```
  /// exchangeCodeForToken(code, state, request)
  ///       ↓
  /// Validate state == request.state
  ///   ↙              ↘
  /// FAIL            PASS
  ///  ↓               ↓
  /// OAuthStateFailure  Validate request.isValid
  ///                     ↙              ↘
  ///                   FAIL            PASS
  ///                    ↓               ↓
  ///         OAuthStateFailure  POST /oauth/token
  ///                                    ↓
  ///                             Receive tokens
  ///                                    ↓
  ///                             Delete request
  ///                                    ↓
  ///                             Return TokenResponse
  /// ```
  ///
  /// **Returns:**
  /// - Right(TokenResponse): Access and refresh tokens
  /// - Left(OAuthStateFailure): State mismatch or expired request
  /// - Left(ServerFailure): Backend token exchange error
  /// - Left(AuthenticationFailure): Invalid code or credentials
  ///
  /// **Edge Cases:**
  /// - State mismatch → OAuthStateFailure (possible attack)
  /// - Request expired → OAuthStateFailure
  /// - Invalid code → AuthenticationException → AuthenticationFailure
  /// - Network error → ServerException → ServerFailure
  ///
  /// **Example:**
  /// ```dart
  /// // After receiving callback from OAuth provider
  /// void handleOAuthCallback(Uri uri) async {
  ///   final code = uri.queryParameters['code'];
  ///   final state = uri.queryParameters['state'];
  ///
  ///   if (code == null || state == null) {
  ///     showError('Invalid OAuth callback');
  ///     return;
  ///   }
  ///
  ///   // Get stored authorization request
  ///   final requestResult = await oauthRepository.getAuthorizationRequest(state);
  ///
  ///   requestResult.fold(
  ///     (failure) => showError('Invalid state'),
  ///     (request) async {
  ///       final tokenResult = await oauthRepository.exchangeCodeForToken(
  ///         code: code,
  ///         state: state,
  ///         request: request,
  ///       );
  ///
  ///       tokenResult.fold(
  ///         (failure) => showError('Token exchange failed'),
  ///         (tokenResponse) {
  ///           print('Access token: ${tokenResponse.accessToken}');
  ///           print('Expires in: ${tokenResponse.expiresIn}s');
  ///           // Proceed with user info fetch...
  ///         },
  ///       );
  ///     },
  ///   );
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add authorization code replay protection
  /// - Code should only be exchangeable once
  /// - [Medium Priority] Add token response validation (check required fields)
  /// - Currently trusts provider response structure
  /// - [Low Priority] Add timing attack protection on state comparison
  @override
  Future<Either<Failure, TokenResponse>> exchangeCodeForToken({
    required String code,
    required String state,
    required AuthorizationRequest request,
  }) async {
    try {
      // Validate state matches
      if (request.state != state) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthStateValidationFailed),
        );
      }

      // Validate request is still valid
      if (!request.isValid) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
        );
      }

      final tokenResponse = await remoteDataSource.exchangeCodeForToken(
        code: code,
        codeVerifier: request.pkceChallenge.codeVerifier,
        provider: request.provider,
      );

      // Mark request as used and delete it
      await localDataSource.deleteAuthorizationRequest(request.state);

      return Right(tokenResponse);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.errorOAuthTokenExchangeFailed,
          provider: request.provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TokenResponse>> refreshToken(
    String refreshToken,
    OAuthProvider provider,
  ) async {
    try {
      final tokenResponse = await remoteDataSource.refreshToken(
        refreshToken: refreshToken,
        provider: provider,
      );
      return Right(tokenResponse);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.errorOAuthRefreshTokenFailed,
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> revokeToken(
    String token,
    OAuthProvider provider,
  ) async {
    try {
      await remoteDataSource.revokeToken(
        token: token,
        provider: provider,
      );
      return const Right(unit);
    } catch (e) {
      // Revocation errors are often non-critical
      // Log but return success
      print('Token revocation warning: $e');
      return const Right(unit);
    }
  }

  @override
  Future<Either<Failure, User>> fetchUserInfo(
    String accessToken,
    OAuthProvider provider,
  ) async {
    try {
      final user = await remoteDataSource.fetchUserInfo(
        accessToken: accessToken,
        provider: provider,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthUserInfoFailed,
            {'provider': provider.displayName},
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, User>> linkOAuthAccount(
    String userId,
    OAuthProvider provider,
    String accessToken,
  ) async {
    try {
      // This would call a backend endpoint to link the OAuth account
      // TODO For now, we'll fetch the user info and update linked providers
      final user = await remoteDataSource.fetchUserInfo(
        accessToken: accessToken,
        provider: provider,
      );

      // Add provider to linked list
      final providers = await localDataSource.getLinkedProviders(userId);
      if (!providers.contains(provider.type)) {
        providers.add(provider.type);
        await localDataSource.storeLinkedProviders(userId, providers);
      }

      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthLinkAccountFailed,
            {'provider': provider.displayName},
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> unlinkOAuthAccount(
    String userId,
    OAuthProviderType providerType,
  ) async {
    try {
      // This would call a backend endpoint to unlink the OAuth account
      // TODO For now, we'll just remove from linked providers list
      final providers = await localDataSource.getLinkedProviders(userId);
      providers.remove(providerType);
      await localDataSource.storeLinkedProviders(userId, providers);
      return const Right(unit);
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthUnlinkAccountFailed,
            {'provider': _getProviderName(providerType)},
          ),
          provider: providerType.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<OAuthProviderType>>> getLinkedProviders(
    String userId,
  ) async {
    try {
      final providers = await localDataSource.getLinkedProviders(userId);
      return Right(providers);
    } catch (e) {
      return Left(
        UnknownFailure(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> storeAuthorizationRequest(
    AuthorizationRequest request,
  ) async {
    try {
      await localDataSource.storeAuthorizationRequest(request);
      return const Right(unit);
    } catch (e) {
      return Left(
        CacheFailure(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, AuthorizationRequest>> getAuthorizationRequest(
    String state,
  ) async {
    try {
      final request = await localDataSource.getAuthorizationRequest(state);

      if (request == null) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
        );
      }

      return Right(request);
    } catch (e) {
      return const Left(
        OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> cleanupExpiredRequests() async {
    try {
      await localDataSource.cleanupExpiredRequests();
      return const Right(unit);
    } catch (e) {
      // Cleanup errors are non-critical
      print('Cleanup warning: $e');
      return const Right(unit);
    }
  }

  // Helper method
  String _getProviderName(OAuthProviderType type) {
    switch (type) {
      case OAuthProviderType.google:
        return AppStrings.oauthProviderGoogle;
      case OAuthProviderType.github:
        return AppStrings.oauthProviderGithub;
      case OAuthProviderType.microsoft:
        return AppStrings.oauthProviderMicrosoft;
      case OAuthProviderType.apple:
        return AppStrings.oauthProviderApple;
    }
  }
}
