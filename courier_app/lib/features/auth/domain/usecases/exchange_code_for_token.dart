import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_response.dart';
import '../repositories/oauth_repository.dart';

/// [ExchangeCodeForToken] - Use case for exchanging OAuth2 authorization code for access tokens
///
/// **What it does:**
/// - Validates authorization code and state parameters
/// - Retrieves stored authorization request using state
/// - Validates CSRF protection (state parameter)
/// - Validates request expiry and usage status
/// - Exchanges authorization code for access token using PKCE
/// - Returns TokenResponse with access token and refresh token
/// - Cleans up expired authorization requests
/// - Implements OAuth 2.0 Token Exchange (RFC 6749 Section 4.1.3)
///
/// **Why it exists:**
/// - Completes OAuth2 authorization code flow
/// - Validates callback authenticity (CSRF protection)
/// - Prevents authorization code interception (PKCE verification)
/// - Securely obtains access tokens from provider
/// - Validates request lifecycle (expiry, single use)
/// - Encapsulates token exchange business logic
/// - Enables testing token exchange in isolation
/// - Follows Clean Architecture UseCase pattern
///
/// **Token Exchange Flow:**
/// ```
/// [Callback] ---> Authorization Code + State
///              |
///              v
/// Validate Code Not Empty
///              |
///              v
/// Validate State Not Empty
///              |
///              v
/// Retrieve Stored AuthorizationRequest (using state)
///              |
///              v
/// Validate State Matches (CSRF Protection)
///              |
///              v
/// Validate Request Not Expired (10 minutes)
///              |
///              v
/// Validate Request Not Already Used
///              |
///              v
/// Build Token Request:
///   - grant_type=authorization_code
///   - code (authorization code)
///   - redirect_uri (must match)
///   - client_id
///   - code_verifier (PKCE)
///              |
///              v
/// POST to provider.tokenEndpoint
///              |
///              v
/// Provider Validates:
///   - code is valid and not expired
///   - redirect_uri matches
///   - SHA256(code_verifier) == stored code_challenge (PKCE)
///              |
///              v
/// Provider Returns TokenResponse:
///   - access_token
///   - refresh_token (optional)
///   - expires_in
///   - token_type (Bearer)
///   - scope
///              |
///              v
/// Mark AuthorizationRequest as Used
///              |
///              v
/// Cleanup Expired Requests
///              |
///              v
/// Return TokenResponse
/// ```
///
/// **Clean Architecture Layer:**
/// ```
/// Presentation (OAuth BLoC)
///       ↓
/// Domain (ExchangeCodeForToken UseCase) ← YOU ARE HERE
///       ↓
/// Domain (OAuthRepository interface)
///       ↓
/// Data (OAuthRepositoryImpl)
/// ```
///
/// **OAuth2 Token Exchange Flow Diagram:**
/// ```
/// ┌─────────┐                              ┌──────────────┐
/// │   App   │                              │ Auth Server  │
/// └────┬────┘                              └──────┬───────┘
///      │                                          │
///      │ 1. Callback                              │
///      │    (code, state)                         │
///      │<─────────────────────────────────────────│
///      │                                          │
///      │ 2. Validate State                        │
///      │    (CSRF Check)                          │
///      │                                          │
///      │ 3. Retrieve PKCE                         │
///      │    code_verifier                         │
///      │                                          │
///      │ 4. Token Request                         │
///      │    POST /token                           │
///      │    - grant_type=authorization_code       │
///      │    - code                                │
///      │    - redirect_uri                        │
///      │    - client_id                           │
///      │    - code_verifier (PKCE)                │
///      │─────────────────────────────────────────>│
///      │                                          │
///      │                              5. Validate │
///      │                                 - code   │
///      │                         - redirect_uri   │
///      │                - PKCE (SHA256(verifier)) │
///      │                                          │
///      │ 6. Token Response                        │
///      │    - access_token                        │
///      │    - refresh_token                       │
///      │    - expires_in                          │
///      │    - token_type                          │
///      │<─────────────────────────────────────────│
///      │                                          │
///      │ 7. Store Tokens                          │
///      │    (Secure Storage)                      │
///      │                                          │
///      │ 8. Mark Request Used                     │
///      │    (Prevent Replay)                      │
///      │                                          │
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In OAuth BLoC or presentation layer
/// class OAuthBloc extends Bloc<OAuthEvent, OAuthState> {
///   final ExchangeCodeForToken exchangeCodeForToken;
///
///   Future<void> _onOAuthCallbackReceived(
///     OAuthCallbackReceived event,
///   ) async {
///     emit(OAuthLoading());
///
///     // Parse callback URL parameters
///     final uri = Uri.parse(event.callbackUrl);
///     final code = uri.queryParameters['code'];
///     final state = uri.queryParameters['state'];
///
///     // Validate callback parameters
///     if (code == null || state == null) {
///       emit(OAuthError('Invalid callback parameters'));
///       return;
///     }
///
///     // Exchange code for tokens
///     final params = ExchangeCodeParams(
///       code: code,
///       state: state,
///     );
///
///     final result = await exchangeCodeForToken(params);
///
///     result.fold(
///       (failure) => emit(OAuthError(failure.message)),
///       (tokenResponse) async {
///         // Store tokens securely
///         await secureStorage.saveAccessToken(tokenResponse.accessToken);
///         await secureStorage.saveRefreshToken(tokenResponse.refreshToken);
///
///         // Fetch user profile with access token
///         final userResult = await getUserProfile(tokenResponse.accessToken);
///
///         userResult.fold(
///           (failure) => emit(OAuthError(failure.message)),
///           (user) => emit(OAuthSuccess(user)),
///         );
///       },
///     );
///   }
/// }
/// ```
///
/// **Security Considerations:**
/// - Authorization code MUST be validated (not empty, valid format)
/// - State parameter MUST match stored value (CSRF protection)
/// - Authorization request MUST not be expired (10 minutes max)
/// - Authorization request MUST not be already used (single use)
/// - PKCE code_verifier MUST be sent with token request
/// - Provider validates SHA256(code_verifier) == stored code_challenge
/// - Tokens MUST be stored securely (encrypted storage)
/// - Authorization code is single-use (marked as used after exchange)
/// - Expired requests cleaned up to prevent storage bloat
///
/// **IMPROVEMENT:**
/// - [High Priority] Add token validation (JWT signature verification for OpenID Connect)
/// - [High Priority] Add automatic token refresh when access token expires
/// - [Medium Priority] Add token revocation on logout
/// - [Medium Priority] Add configurable token storage strategy
/// - [Low Priority] Add analytics tracking (token exchange success rate)
class ExchangeCodeForToken
    implements UseCase<TokenResponse, ExchangeCodeParams> {
  /// OAuth repository for token exchange
  ///
  /// **Why injected:**
  /// - Dependency inversion (depend on interface, not implementation)
  /// - Enables testing with mock repository
  /// - Supports different token exchange strategies
  final OAuthRepository repository;

  /// Creates ExchangeCodeForToken use case
  ///
  /// **Parameters:**
  /// - [repository]: OAuthRepository implementation for token exchange
  ///
  /// **Example:**
  /// ```dart
  /// final exchangeCodeForToken = ExchangeCodeForToken(oauthRepository);
  /// ```
  const ExchangeCodeForToken(this.repository);

  /// Executes token exchange with comprehensive validation
  ///
  /// **What it does:**
  /// 1. Validates authorization code (required, non-empty)
  /// 2. Validates state parameter (required, non-empty)
  /// 3. Retrieves stored authorization request using state
  /// 4. Validates request not expired (10 minutes)
  /// 5. Validates request not already used (single use)
  /// 6. Validates PKCE challenge not expired
  /// 7. Exchanges code for token with PKCE verifier
  /// 8. Marks request as used (prevents replay)
  /// 9. Cleans up expired requests
  /// 10. Returns Either<Failure, TokenResponse>
  ///
  /// **Validation Rules:**
  /// - Authorization code: Required, non-empty
  /// - State parameter: Required, non-empty, must match stored value
  /// - Request: Must exist, not expired, not used, PKCE valid
  ///
  /// **Parameters:**
  /// - [params]: ExchangeCodeParams containing code and state
  ///
  /// **Returns:**
  /// - Right(TokenResponse): Token exchange successful
  /// - Left(ValidationFailure): Invalid code or state
  /// - Left(OAuthStateFailure): State mismatch (CSRF attack) or expired request
  /// - Left(StorageFailure): Failed to retrieve authorization request
  /// - Left(NetworkFailure): Network error during token exchange
  /// - Left(ServerFailure): Provider rejected token request
  ///
  /// **Error Examples:**
  /// ```dart
  /// // Missing authorization code
  /// ExchangeCodeParams(code: '', state: 'valid-state')
  /// → Left(ValidationFailure('OAuth authorization code is required'))
  ///
  /// // Missing state
  /// ExchangeCodeParams(code: 'valid-code', state: '')
  /// → Left(ValidationFailure('OAuth state parameter is required'))
  ///
  /// // State mismatch (CSRF attack)
  /// ExchangeCodeParams(code: 'valid-code', state: 'wrong-state')
  /// → Left(StorageFailure('Authorization request not found'))
  ///
  /// // Expired request
  /// ExchangeCodeParams(code: 'valid-code', state: 'expired-state')
  /// → Left(OAuthStateFailure('Authorization request is invalid or expired'))
  ///
  /// // Already used request
  /// ExchangeCodeParams(code: 'valid-code', state: 'used-state')
  /// → Left(OAuthStateFailure('Authorization request is invalid or expired'))
  ///
  /// // Invalid authorization code
  /// ExchangeCodeParams(code: 'invalid-code', state: 'valid-state')
  /// → Left(ServerFailure('Invalid authorization code'))
  ///
  /// // PKCE verification failed
  /// ExchangeCodeParams(code: 'valid-code', state: 'valid-state')
  /// → Left(ServerFailure('PKCE verification failed'))
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// // Parse callback URL
  /// final uri = Uri.parse('com.myapp://oauth/callback?code=abc123&state=xyz789');
  /// final code = uri.queryParameters['code']!;
  /// final state = uri.queryParameters['state']!;
  ///
  /// // Exchange code for tokens
  /// final params = ExchangeCodeParams(code: code, state: state);
  /// final result = await exchangeCodeForToken(params);
  ///
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (tokenResponse) {
  ///     print('Access Token: ${tokenResponse.accessToken}');
  ///     print('Refresh Token: ${tokenResponse.refreshToken}');
  ///     print('Expires In: ${tokenResponse.expiresIn} seconds');
  ///   },
  /// );
  /// ```
  @override
  Future<Either<Failure, TokenResponse>> call(
    ExchangeCodeParams params,
  ) async {
    // Validate input parameters
    // Authorization code is returned by provider after user authorization
    if (params.code.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthCodeRequired),
      );
    }

    // State parameter is used for CSRF protection
    // Must match the state from the original authorization request
    if (params.state.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthStateRequired),
      );
    }

    // Retrieve the stored authorization request
    // The request contains:
    // 1. PKCE code_verifier (needed for token exchange)
    // 2. Provider configuration
    // 3. Request timestamp (for expiry validation)
    // 4. Usage status (prevents replay attacks)
    final requestResult = await repository.getAuthorizationRequest(
      params.state,
    );

    return requestResult.fold(
      (failure) => Left(failure),
      (request) async {
        // Validate the request
        // request.isValid checks:
        // 1. Request not expired (< 10 minutes old)
        // 2. Request not already used (single use)
        // 3. PKCE challenge not expired
        if (!request.isValid) {
          return const Left(
            OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
          );
        }

        // Exchange code for tokens
        // This makes a POST request to provider.tokenEndpoint with:
        // - grant_type: 'authorization_code'
        // - code: authorization code
        // - redirect_uri: must match original
        // - client_id: OAuth client ID
        // - code_verifier: PKCE verifier (provider validates SHA256(verifier))
        final tokenResult = await repository.exchangeCodeForToken(
          code: params.code,
          state: params.state,
          request: request,
        );

        // Clean up expired requests
        // Prevents storage bloat from old authorization attempts
        // Removes requests older than 10 minutes
        await repository.cleanupExpiredRequests();

        return tokenResult;
      },
    );
  }
}

/// [ExchangeCodeParams] - Parameters for ExchangeCodeForToken use case
///
/// **What it contains:**
/// - Authorization code returned by OAuth provider
/// - State parameter for CSRF validation
///
/// **Why Equatable:**
/// - Enables value comparison (params1 == params2)
/// - Used in BLoC state management (detect param changes)
/// - Prevents duplicate token exchange requests
///
/// **Usage Example:**
/// ```dart
/// // Parse callback URL
/// final callbackUri = Uri.parse(event.callbackUrl);
/// final code = callbackUri.queryParameters['code'];
/// final state = callbackUri.queryParameters['state'];
///
/// // Create exchange params
/// final params = ExchangeCodeParams(
///   code: code ?? '',
///   state: state ?? '',
/// );
///
/// // Exchange code for tokens
/// final result = await exchangeCodeForToken(params);
///
/// // Equatable enables comparison
/// final params2 = ExchangeCodeParams(code: code ?? '', state: state ?? '');
/// print(params == params2); // true (same values)
/// ```
class ExchangeCodeParams extends Equatable {
  /// Authorization code returned by OAuth provider
  ///
  /// **What it is:**
  /// - Short-lived code (typically 10 minutes)
  /// - Returned in callback URL query parameter
  /// - Single-use (can only be exchanged once)
  /// - Validated by provider during token exchange
  ///
  /// **Validation:**
  /// - Required (validated in ExchangeCodeForToken use case)
  /// - Must not be empty
  /// - Provider validates code is valid and not expired
  ///
  /// **Security:**
  /// - Protected by PKCE (prevents interception attacks)
  /// - Single-use (marked as used after exchange)
  /// - Short-lived (expires in minutes)
  ///
  /// **Example:** "4/0AX4XfWh..."
  final String code;

  /// State parameter for CSRF protection
  ///
  /// **What it is:**
  /// - Random string from original authorization request
  /// - Returned unchanged by provider in callback
  /// - Used to retrieve stored authorization request
  /// - Validates callback authenticity
  ///
  /// **Validation:**
  /// - Required (validated in ExchangeCodeForToken use case)
  /// - Must not be empty
  /// - Must match stored authorization request state
  ///
  /// **Security:**
  /// - CSRF protection (prevents malicious redirects)
  /// - Cryptographically random (unpredictable)
  /// - Single-use (request marked as used after token exchange)
  ///
  /// **Example:** "a7f3e9d2c1b4..."
  final String state;

  /// Creates token exchange parameters
  ///
  /// **Parameters:**
  /// - [code]: Authorization code from callback (required)
  /// - [state]: State parameter from callback (required)
  ///
  /// **Example:**
  /// ```dart
  /// // Parse callback URL
  /// final uri = Uri.parse('app://oauth/callback?code=abc&state=xyz');
  ///
  /// final params = ExchangeCodeParams(
  ///   code: uri.queryParameters['code']!,
  ///   state: uri.queryParameters['state']!,
  /// );
  /// ```
  const ExchangeCodeParams({
    required this.code,
    required this.state,
  });

  /// Equatable props for value comparison
  ///
  /// **Why both code and state:**
  /// - Two ExchangeCodeParams are equal if both code AND state match
  /// - Used by Equatable for == operator and hashCode
  @override
  List<Object?> get props => [code, state];
}