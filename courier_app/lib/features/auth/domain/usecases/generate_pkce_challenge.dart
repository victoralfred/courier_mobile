import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/utils/pkce_utils.dart';
import '../entities/pkce_challenge.dart';

/// [GeneratePKCEChallenge] - Use case for generating PKCE challenge for OAuth2 flows
///
/// **What it does:**
/// - Generates cryptographically random code verifier (43-128 chars)
/// - Creates SHA256 hash of verifier as code challenge
/// - Returns PKCEChallenge entity with verifier and challenge
/// - Implements RFC 7636 (PKCE for OAuth2)
/// - Timestamps challenge creation for expiry tracking
/// - Uses 'S256' challenge method (SHA256)
///
/// **Why it exists:**
/// - Security: Prevents authorization code interception attacks
/// - Required for public OAuth2 clients (mobile apps, SPAs)
/// - Eliminates need for client secret in mobile apps
/// - Protects against malicious apps intercepting auth codes
/// - Recommended by OAuth 2.0 Security Best Practices (RFC 8252)
/// - Mitigates authorization code injection attacks
/// - Follows Clean Architecture UseCase pattern
///
/// **PKCE Flow Overview:**
/// ```
/// [App] ---> Generate PKCE Challenge
///              |
///              v
/// code_verifier: random 43-128 char string
///              |
///              v
/// code_challenge: BASE64URL(SHA256(code_verifier))
///              |
///              v
/// [App] ---> Authorization Request (with code_challenge)
///              |
///              v
/// [Provider] ---> Stores code_challenge
///              |
///              v
/// [User Authorizes] --> [Authorization Code]
///              |
///              v
/// [App] ---> Token Request (with code_verifier)
///              |
///              v
/// [Provider] ---> Validates: SHA256(code_verifier) == stored code_challenge
///              |
///              v
/// [Access Token] (if validation succeeds)
/// ```
///
/// **Security Benefits:**
/// - Prevents man-in-the-middle (MITM) attacks
/// - Prevents malicious apps from using intercepted auth codes
/// - No client secret needed (safe for mobile/public clients)
/// - Cryptographically secure random verifier
/// - One-way hash function (challenge can't reveal verifier)
///
/// **Clean Architecture Layer:**
/// ```
/// Presentation (OAuth BLoC)
///       ↓
/// Domain (GeneratePKCEChallenge UseCase) ← YOU ARE HERE
///       ↓
/// Data (PKCEUtils - crypto utilities)
/// ```
///
/// **OAuth2 with PKCE Flow Diagram:**
/// ```
/// ┌─────────┐                  ┌──────────┐                 ┌──────────────┐
/// │   App   │                  │ Browser  │                 │ Auth Server  │
/// └────┬────┘                  └────┬─────┘                 └──────┬───────┘
///      │                            │                               │
///      │ 1. Generate PKCE           │                               │
///      │    verifier + challenge    │                               │
///      │───────────────────────────>│                               │
///      │                            │                               │
///      │ 2. Build Auth URL          │                               │
///      │    (with code_challenge)   │                               │
///      │───────────────────────────>│                               │
///      │                            │                               │
///      │                            │ 3. Authorization Request      │
///      │                            │      (code_challenge)         │
///      │                            │──────────────────────────────>│
///      │                            │                               │
///      │                            │                      4. Store │
///      │                            │                   code_challenge
///      │                            │                               │
///      │                            │ 5. User Login & Consent       │
///      │                            │<──────────────────────────────│
///      │                            │                               │
///      │                            │ 6. Authorization Code         │
///      │                            │<──────────────────────────────│
///      │                            │                               │
///      │ 7. Callback with code      │                               │
///      │<───────────────────────────│                               │
///      │                            │                               │
///      │ 8. Token Request                                           │
///      │    (code + code_verifier)                                  │
///      │────────────────────────────────────────────────────────────>│
///      │                            │                               │
///      │                            │                   9. Validate │
///      │                            │         SHA256(verifier) ==   │
///      │                            │              stored challenge │
///      │                            │                               │
///      │ 10. Access Token (if valid)                                │
///      │<────────────────────────────────────────────────────────────│
///      │                            │                               │
/// ```
///
/// **RFC 7636 Compliance:**
/// - Code Verifier: 43-128 characters, [A-Z][a-z][0-9]-._~ (unreserved)
/// - Code Challenge: BASE64URL(SHA256(code_verifier))
/// - Challenge Method: 'S256' (SHA256, more secure than 'plain')
///
/// **Usage Example:**
/// ```dart
/// // In OAuth BLoC or presentation layer
/// class OAuthBloc extends Bloc<OAuthEvent, OAuthState> {
///   final GeneratePKCEChallenge generatePKCEChallenge;
///
///   Future<void> _onOAuthInitiated(OAuthInitiated event) async {
///     // Step 1: Generate PKCE challenge
///     final challengeResult = await generatePKCEChallenge(NoParams());
///
///     challengeResult.fold(
///       (failure) => emit(OAuthError(failure.message)),
///       (pkceChallenge) async {
///         // Step 2: Build authorization URL with challenge
///         final authUrl = provider.buildAuthorizationUrl(
///           state: generateRandomState(),
///           codeChallenge: pkceChallenge.codeChallenge,
///           codeChallengeMethod: pkceChallenge.method, // 'S256'
///         );
///
///         // Step 3: Store PKCE challenge for later token exchange
///         await storePKCEChallenge(pkceChallenge);
///
///         // Step 4: Open authorization URL in browser
///         emit(OAuthRedirect(authUrl));
///       },
///     );
///   }
/// }
/// ```
///
/// **Security Considerations:**
/// - Code verifier MUST be cryptographically random
/// - Code verifier MUST be kept secret until token exchange
/// - Code challenge is public (sent in authorization URL)
/// - Challenge method SHOULD be 'S256' (not 'plain')
/// - PKCE challenge expires after 10 minutes
/// - Each authorization flow MUST use a new PKCE challenge
///
/// **IMPROVEMENT:**
/// - [High Priority] Add configurable code verifier length (currently fixed at 128)
/// - [Medium Priority] Add support for 'plain' method (for legacy providers, not recommended)
/// - [Medium Priority] Add verifier/challenge validation before returning
/// - [Low Priority] Add configurable expiry duration (currently 10 minutes)
/// - [Low Priority] Support for custom hash algorithms (if future RFC updates)
class GeneratePKCEChallenge implements UseCase<PKCEChallenge, NoParams> {
  /// Executes PKCE challenge generation
  ///
  /// **What it does:**
  /// 1. Generates cryptographically random code verifier
  /// 2. Computes SHA256 hash of verifier
  /// 3. Base64URL-encodes the hash (code challenge)
  /// 4. Creates PKCEChallenge entity with timestamp
  /// 5. Returns Either<Failure, PKCEChallenge>
  ///
  /// **Parameters:**
  /// - [params]: NoParams (no input required)
  ///
  /// **Returns:**
  /// - Right(PKCEChallenge): Successfully generated challenge
  /// - Left(PKCEFailure): Failed to generate challenge (crypto error)
  ///
  /// **Error Examples:**
  /// ```dart
  /// // Crypto library failure (extremely rare)
  /// await generatePKCEChallenge(NoParams())
  /// → Left(PKCEFailure('Failed to generate random bytes'))
  ///
  /// // Hash generation failure (extremely rare)
  /// await generatePKCEChallenge(NoParams())
  /// → Left(PKCEFailure('SHA256 hashing failed'))
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// final result = await generatePKCEChallenge(NoParams());
  ///
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (pkce) {
  ///     print('Verifier: ${pkce.codeVerifier}');
  ///     print('Challenge: ${pkce.codeChallenge}');
  ///     print('Method: ${pkce.method}'); // 'S256'
  ///   },
  /// );
  /// ```
  @override
  Future<Either<Failure, PKCEChallenge>> call(NoParams params) async {
    try {
      // Generate code verifier (43-128 characters)
      // This is a cryptographically random string that will be
      // kept secret until token exchange
      final codeVerifier = PKCEUtils.generateCodeVerifier();

      // Generate code challenge using SHA256
      // This is BASE64URL(SHA256(codeVerifier))
      // The challenge is sent to the provider during authorization
      final codeChallenge = PKCEUtils.generateCodeChallenge(codeVerifier);

      // Create PKCEChallenge entity with timestamp
      // The timestamp is used for expiry validation (10 minutes)
      return Right(PKCEChallenge(
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        method: 'S256',
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      // Handle crypto errors (extremely rare)
      // Possible causes: platform crypto failure, memory issues
      return Left(
        PKCEFailure(
          AppStrings.format(
            AppStrings.errorOAuthGeneratePKCE,
            {'error': e.toString()},
          ),
        ),
      );
    }
  }
}