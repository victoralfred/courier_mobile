import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/authorization_request.dart';
import '../entities/oauth_provider.dart';
import '../repositories/oauth_repository.dart';

/// [AuthorizeOAuth] - Use case for initiating OAuth2 authorization flow with PKCE
///
/// **What it does:**
/// - Validates OAuth provider configuration (client ID, redirect URI)
/// - Generates PKCE challenge for secure authorization
/// - Creates cryptographically random state parameter (CSRF protection)
/// - Builds authorization URL with all OAuth2 parameters
/// - Stores authorization request for later validation
/// - Returns AuthorizationRequest for browser redirect
/// - Implements OAuth 2.0 Authorization Code Flow (RFC 6749)
///
/// **Why it exists:**
/// - Initiates secure OAuth2 authentication flow
/// - Prevents CSRF attacks via state parameter
/// - Prevents authorization code interception via PKCE
/// - Validates provider configuration before authorization
/// - Encapsulates authorization request creation logic
/// - Enables testing authorization flow in isolation
/// - Follows Clean Architecture UseCase pattern
///
/// **OAuth 2.0 Authorization Flow:**
/// ```
/// [App] ---> AuthorizeOAuth UseCase
///              |
///              v
/// Validate Provider Config (client ID, redirect URI)
///              |
///              v
/// Generate PKCE Challenge (code_verifier, code_challenge)
///              |
///              v
/// Generate State Parameter (random CSRF token)
///              |
///              v
/// Build Authorization URL
///   - provider.authorizationEndpoint
///   - client_id
///   - redirect_uri
///   - response_type=code
///   - scope (permissions requested)
///   - state (CSRF protection)
///   - code_challenge (PKCE)
///   - code_challenge_method=S256
///              |
///              v
/// Store AuthorizationRequest (for callback validation)
///              |
///              v
/// Return AuthorizationRequest
///              |
///              v
/// [App] ---> Open authorization URL in browser
///              |
///              v
/// [User] ---> Login & Grant Permissions
///              |
///              v
/// [Provider] ---> Redirect to redirect_uri with code & state
///              |
///              v
/// [App] ---> Validate state & exchange code for token
/// ```
///
/// **Clean Architecture Layer:**
/// ```
/// Presentation (OAuth BLoC)
///       ↓
/// Domain (AuthorizeOAuth UseCase) ← YOU ARE HERE
///       ↓
/// Domain (OAuthRepository interface)
///       ↓
/// Data (OAuthRepositoryImpl)
/// ```
///
/// **OAuth2 Authorization Flow Diagram:**
/// ```
/// ┌─────────┐         ┌──────────┐         ┌──────────────┐
/// │   App   │         │ Browser  │         │ Auth Server  │
/// └────┬────┘         └────┬─────┘         └──────┬───────┘
///      │                   │                       │
///      │ 1. Authorize      │                       │
///      │    OAuth          │                       │
///      │────────────>      │                       │
///      │                   │                       │
///      │ 2. Auth URL       │                       │
///      │<────────────      │                       │
///      │                   │                       │
///      │ 3. Open URL       │                       │
///      │───────────────────>                       │
///      │                   │                       │
///      │                   │ 4. Authorization      │
///      │                   │    Request            │
///      │                   │──────────────────────>│
///      │                   │                       │
///      │                   │ 5. Login Page         │
///      │                   │<──────────────────────│
///      │                   │                       │
///      │                   │ 6. User Credentials   │
///      │                   │──────────────────────>│
///      │                   │                       │
///      │                   │ 7. Consent Screen     │
///      │                   │<──────────────────────│
///      │                   │                       │
///      │                   │ 8. User Grants        │
///      │                   │    Permission         │
///      │                   │──────────────────────>│
///      │                   │                       │
///      │                   │ 9. Redirect           │
///      │                   │    (code + state)     │
///      │                   │<──────────────────────│
///      │                   │                       │
///      │ 10. Callback      │                       │
///      │<───────────────────                       │
///      │    (code, state)  │                       │
///      │                   │                       │
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In OAuth BLoC or presentation layer
/// class OAuthBloc extends Bloc<OAuthEvent, OAuthState> {
///   final AuthorizeOAuth authorizeOAuth;
///
///   Future<void> _onOAuthSignInRequested(
///     OAuthSignInRequested event,
///   ) async {
///     emit(OAuthLoading());
///
///     // Create OAuth provider (Google, GitHub, etc.)
///     final provider = OAuthProvider.google(
///       clientId: 'your-client-id.apps.googleusercontent.com',
///       redirectUri: 'com.yourapp://oauth/callback',
///     );
///
///     // Initiate authorization flow
///     final params = AuthorizeOAuthParams(provider: provider);
///     final result = await authorizeOAuth(params);
///
///     result.fold(
///       (failure) => emit(OAuthError(failure.message)),
///       (authRequest) {
///         // Open authorization URL in browser
///         emit(OAuthRedirectRequired(authRequest.authorizationUrl));
///
///         // Store request ID for callback validation
///         _pendingAuthRequestId = authRequest.id;
///       },
///     );
///   }
/// }
/// ```
///
/// **Security Considerations:**
/// - Provider client ID MUST be validated (not empty)
/// - Redirect URI MUST match registered URI exactly
/// - State parameter MUST be cryptographically random (CSRF protection)
/// - PKCE challenge MUST be generated for each request
/// - Authorization request MUST be stored for callback validation
/// - Request expires after 10 minutes
/// - Each authorization MUST use unique state and PKCE challenge
///
/// **IMPROVEMENT:**
/// - [High Priority] Add nonce support for OpenID Connect flows
/// - [Medium Priority] Add custom scope validation
/// - [Medium Priority] Add provider availability check (network)
/// - [Low Priority] Add analytics tracking (provider usage, success rate)
/// - [Low Priority] Add configurable request expiry duration
class AuthorizeOAuth
    implements UseCase<AuthorizationRequest, AuthorizeOAuthParams> {
  /// OAuth repository for authorization request management
  ///
  /// **Why injected:**
  /// - Dependency inversion (depend on interface, not implementation)
  /// - Enables testing with mock repository
  /// - Supports different storage mechanisms (secure storage, database)
  final OAuthRepository repository;

  /// Creates AuthorizeOAuth use case
  ///
  /// **Parameters:**
  /// - [repository]: OAuthRepository implementation for authorization
  ///
  /// **Example:**
  /// ```dart
  /// final authorizeOAuth = AuthorizeOAuth(oauthRepository);
  /// ```
  const AuthorizeOAuth(this.repository);

  /// Executes OAuth2 authorization flow initiation with validation
  ///
  /// **What it does:**
  /// 1. Validates provider client ID (required, non-empty)
  /// 2. Validates provider redirect URI (required, non-empty)
  /// 3. Generates PKCE challenge via repository
  /// 4. Generates random state parameter via repository
  /// 5. Builds authorization URL with all parameters
  /// 6. Creates AuthorizationRequest entity
  /// 7. Stores request for callback validation
  /// 8. Returns Either<Failure, AuthorizationRequest>
  ///
  /// **Validation Rules:**
  /// - Client ID: Required, non-empty string
  /// - Redirect URI: Required, non-empty string, must match registered URI
  ///
  /// **Parameters:**
  /// - [params]: AuthorizeOAuthParams containing OAuth provider
  ///
  /// **Returns:**
  /// - Right(AuthorizationRequest): Authorization request created successfully
  /// - Left(ValidationFailure): Invalid provider configuration
  /// - Left(PKCEFailure): Failed to generate PKCE challenge
  /// - Left(StorageFailure): Failed to store authorization request
  ///
  /// **Error Examples:**
  /// ```dart
  /// // Missing client ID
  /// AuthorizeOAuthParams(provider: OAuthProvider(..., clientId: ''))
  /// → Left(ValidationFailure('OAuth client ID is required'))
  ///
  /// // Missing redirect URI
  /// AuthorizeOAuthParams(provider: OAuthProvider(..., redirectUri: ''))
  /// → Left(ValidationFailure('OAuth redirect URI is required'))
  ///
  /// // PKCE generation failure (extremely rare)
  /// AuthorizeOAuthParams(provider: validProvider)
  /// → Left(PKCEFailure('Failed to generate PKCE challenge'))
  ///
  /// // Storage failure
  /// AuthorizeOAuthParams(provider: validProvider)
  /// → Left(StorageFailure('Failed to store authorization request'))
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// // Create Google OAuth provider
  /// final provider = OAuthProvider.google(
  ///   clientId: '123456.apps.googleusercontent.com',
  ///   redirectUri: 'com.myapp://oauth/callback',
  /// );
  ///
  /// // Initiate authorization
  /// final params = AuthorizeOAuthParams(provider: provider);
  /// final result = await authorizeOAuth(params);
  ///
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (authRequest) {
  ///     // Open browser with authorization URL
  ///     launchUrl(Uri.parse(authRequest.authorizationUrl));
  ///
  ///     // Wait for callback with authorization code
  ///   },
  /// );
  /// ```
  @override
  Future<Either<Failure, AuthorizationRequest>> call(
    AuthorizeOAuthParams params,
  ) async {
    // Validate provider configuration
    // Client ID is required for OAuth2 authorization
    if (params.provider.clientId.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthClientIdRequired),
      );
    }

    // Redirect URI must be registered with provider
    // Must match exactly for security
    if (params.provider.redirectUri.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthRedirectUriRequired),
      );
    }

    // Generate authorization request with PKCE
    // Repository handles:
    // 1. PKCE challenge generation
    // 2. State parameter generation
    // 3. Authorization URL building
    final result = await repository.generateAuthorizationRequest(
      params.provider,
    );

    return result.fold(
      (failure) => Left(failure),
      (request) async {
        // Store the request for later validation
        // This is critical for:
        // 1. CSRF protection (state validation)
        // 2. PKCE verification (code_verifier retrieval)
        // 3. Request expiry tracking
        final storeResult = await repository.storeAuthorizationRequest(request);

        return storeResult.fold(
          (failure) => Left(failure),
          (_) => Right(request),
        );
      },
    );
  }
}

/// [AuthorizeOAuthParams] - Parameters for AuthorizeOAuth use case
///
/// **What it contains:**
/// - OAuth provider configuration (endpoints, credentials, scopes)
///
/// **Why Equatable:**
/// - Enables value comparison (params1 == params2)
/// - Used in BLoC state management (detect param changes)
/// - Prevents unnecessary authorization requests
///
/// **Usage Example:**
/// ```dart
/// // Create Google OAuth params
/// final params = AuthorizeOAuthParams(
///   provider: OAuthProvider.google(
///     clientId: 'your-client-id',
///     redirectUri: 'com.yourapp://oauth/callback',
///   ),
/// );
///
/// // Create GitHub OAuth params
/// final githubParams = AuthorizeOAuthParams(
///   provider: OAuthProvider.github(
///     clientId: 'your-github-client-id',
///     redirectUri: 'com.yourapp://oauth/callback',
///   ),
/// );
///
/// // Equatable enables comparison
/// print(params == githubParams); // false (different providers)
/// ```
class AuthorizeOAuthParams extends Equatable {
  /// OAuth provider configuration
  ///
  /// **Contains:**
  /// - Provider type (Google, GitHub, Microsoft, Apple)
  /// - OAuth endpoints (authorization, token, userInfo)
  /// - Client credentials (client ID)
  /// - Redirect URI
  /// - Scopes (permissions requested)
  ///
  /// **Validation:**
  /// - Client ID must not be empty
  /// - Redirect URI must not be empty
  /// - Redirect URI must match registered URI
  final OAuthProvider provider;

  /// Creates authorization parameters
  ///
  /// **Parameters:**
  /// - [provider]: OAuth provider configuration (required)
  ///
  /// **Example:**
  /// ```dart
  /// final params = AuthorizeOAuthParams(
  ///   provider: OAuthProvider.microsoft(
  ///     clientId: 'your-microsoft-client-id',
  ///     redirectUri: 'com.yourapp://oauth/callback',
  ///     tenant: 'common',
  ///   ),
  /// );
  /// ```
  const AuthorizeOAuthParams({required this.provider});

  /// Equatable props for value comparison
  ///
  /// **Why provider:**
  /// - Two AuthorizeOAuthParams are equal if providers are equal
  /// - Used by Equatable for == operator and hashCode
  @override
  List<Object?> get props => [provider];
}
