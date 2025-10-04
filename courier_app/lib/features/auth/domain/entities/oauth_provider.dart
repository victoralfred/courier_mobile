import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';

/// [OAuthProviderType] - Enum representing supported OAuth2 authentication providers
///
/// **What it does:**
/// - Defines supported OAuth2/OpenID Connect providers
/// - Type-safe provider identification
/// - Enables provider-specific configuration
/// - Supports multiple authentication methods
///
/// **Why it exists:**
/// - Centralized provider enumeration
/// - Type safety (prevents invalid provider names)
/// - Extensible for new providers
/// - Clean provider switching logic
/// - Consistent provider identification
///
/// **Supported Providers:**
/// - **Google**: OAuth 2.0 with OpenID Connect
/// - **GitHub**: OAuth 2.0
/// - **Microsoft**: OAuth 2.0 with OpenID Connect
/// - **Apple**: OAuth 2.0 with OpenID Connect (Sign in with Apple)
///
/// **Usage Example:**
/// ```dart
/// // Create provider-specific configuration
/// final provider = OAuthProvider.google(
///   clientId: 'your-client-id',
///   redirectUri: 'app://callback',
/// );
///
/// // Switch on provider type
/// switch (provider.type) {
///   case OAuthProviderType.google:
///     // Google-specific handling
///     break;
///   case OAuthProviderType.github:
///     // GitHub-specific handling
///     break;
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add Facebook provider
/// - [Low Priority] Add Twitter/X provider
/// - [Low Priority] Add custom OAuth2 provider support
enum OAuthProviderType {
  /// Google OAuth 2.0 with OpenID Connect
  google,

  /// GitHub OAuth 2.0
  github,

  /// Microsoft OAuth 2.0 with OpenID Connect (Azure AD)
  microsoft,

  /// Apple Sign In (OAuth 2.0 with OpenID Connect)
  apple,
}

/// [OAuthProvider] - Domain entity representing OAuth2 provider configuration
///
/// **What it does:**
/// - Encapsulates OAuth2 provider endpoints and configuration
/// - Provides factory methods for common providers (Google, GitHub, Microsoft)
/// - Builds authorization URLs with PKCE support
/// - Manages OAuth2 scopes and client credentials
/// - Supports provider-specific parameters
/// - Immutable entity following Clean Architecture
///
/// **Why it exists:**
/// - Centralized OAuth2 configuration management
/// - Type-safe provider setup
/// - Prevents configuration errors (wrong endpoints, missing scopes)
/// - Supports multiple OAuth2 providers
/// - Enables easy addition of new providers
/// - Separates provider config from auth flow logic
/// - Standards-compliant OAuth2 implementation
///
/// **OAuth2 Flow:**
/// ```
/// [App] ---> buildAuthorizationUrl() ---> [User's Browser]
///                                              |
///                                              v
///                                        [Provider Login]
///                                              |
///                                              v
///                                    [User Grants Permission]
///                                              |
///                                              v
///            [Authorization Code] <--- [Redirect to redirectUri]
///                     |
///                     v
///      [App] ---> tokenEndpoint ---> [Access Token]
///                     |
///                     v
///      [App] ---> userInfoEndpoint ---> [User Profile]
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Create Google provider
/// final google = OAuthProvider.google(
///   clientId: 'your-google-client-id.apps.googleusercontent.com',
///   redirectUri: 'com.yourapp://oauth/callback',
/// );
///
/// // Build authorization URL
/// final pkce = PKCEChallenge.generate();
/// final authUrl = google.buildAuthorizationUrl(
///   state: 'random-state-token',
///   codeChallenge: pkce.codeChallenge,
/// );
///
/// // Open URL in browser
/// await launchUrl(authUrl);
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add endpoint URL validation
/// - [Medium Priority] Add provider discovery (OpenID Connect .well-known)
/// - [Medium Priority] Add JWT token validation helpers
/// - [Low Priority] Add provider-specific error handling
/// - [Low Priority] Add automatic scope validation
class OAuthProvider extends Equatable {
  /// The type of OAuth provider (Google, GitHub, Microsoft, Apple)
  final OAuthProviderType type;

  /// The display name of the provider for UI
  ///
  /// **Examples:**
  /// - "Google"
  /// - "GitHub"
  /// - "Microsoft"
  ///
  /// **Use cases:**
  /// - Login button labels
  /// - Provider selection UI
  /// - User-facing messages
  final String displayName;

  /// The authorization endpoint URL
  ///
  /// **What it does:**
  /// - User redirected here to grant permissions
  /// - Provider displays login and consent screens
  ///
  /// **Examples:**
  /// - Google: https://accounts.google.com/o/oauth2/v2/auth
  /// - GitHub: https://github.com/login/oauth/authorize
  final String authorizationEndpoint;

  /// The token exchange endpoint URL
  ///
  /// **What it does:**
  /// - Exchange authorization code for access token
  /// - Refresh access tokens
  ///
  /// **Examples:**
  /// - Google: https://oauth2.googleapis.com/token
  /// - GitHub: https://github.com/login/oauth/access_token
  final String tokenEndpoint;

  /// The user info endpoint URL for fetching profile data
  ///
  /// **What it does:**
  /// - Fetch user profile after authentication
  /// - Get email, name, avatar, etc.
  ///
  /// **Examples:**
  /// - Google: https://www.googleapis.com/oauth2/v2/userinfo
  /// - GitHub: https://api.github.com/user
  final String userInfoEndpoint;

  /// The OAuth2 client ID for this provider
  ///
  /// **What it is:**
  /// - Public identifier for your app
  /// - Registered with OAuth provider
  /// - Included in authorization requests
  ///
  /// **Security:** Public value, safe to expose in client code
  final String clientId;

  /// The redirect URI registered with the provider
  ///
  /// **What it is:**
  /// - Where provider redirects after authorization
  /// - Must exactly match registered URI
  /// - Typically custom URL scheme or deep link
  ///
  /// **Examples:**
  /// - com.yourapp://oauth/callback
  /// - https://yourapp.com/auth/callback
  ///
  /// **Security:** Must be pre-registered with provider
  final String redirectUri;

  /// The requested OAuth2 scopes
  ///
  /// **What they are:**
  /// - Permissions requested from user
  /// - Space-separated in authorization URL
  /// - Determine what data/actions allowed
  ///
  /// **Examples:**
  /// - Google: ['openid', 'profile', 'email']
  /// - GitHub: ['read:user', 'user:email']
  ///
  /// **Best practice:** Request minimal necessary scopes
  final List<String> scopes;

  /// Optional revocation endpoint for token revocation
  ///
  /// **Optional:** Not all providers support revocation
  ///
  /// **What it does:**
  /// - Revoke access tokens
  /// - Revoke refresh tokens
  /// - Called during logout
  ///
  /// **Example:** Google: https://oauth2.googleapis.com/revoke
  final String? revocationEndpoint;

  /// Additional provider-specific parameters
  ///
  /// **What it contains:**
  /// - Provider-specific OAuth2 parameters
  /// - Added to authorization URL
  ///
  /// **Examples:**
  /// - Google: {access_type: 'offline', prompt: 'consent'}
  /// - Microsoft: {tenant: 'common'}
  ///
  /// **Use cases:**
  /// - Request offline access (refresh tokens)
  /// - Force consent screen
  /// - Tenant-specific authentication
  final Map<String, String> additionalParams;

  /// Creates an OAuthProvider with specified configuration
  ///
  /// **Parameters:**
  /// - [type]: Provider type (required)
  /// - [displayName]: UI display name (required)
  /// - [authorizationEndpoint]: Authorization URL (required)
  /// - [tokenEndpoint]: Token exchange URL (required)
  /// - [userInfoEndpoint]: User profile URL (required)
  /// - [clientId]: OAuth client ID (required)
  /// - [redirectUri]: Callback URI (required)
  /// - [scopes]: Requested scopes (required)
  /// - [revocationEndpoint]: Token revocation URL (optional)
  /// - [additionalParams]: Provider-specific params (optional)
  ///
  /// **Note:** Prefer using factory methods (google(), github(), etc.) for standard providers
  const OAuthProvider({
    required this.type,
    required this.displayName,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.revocationEndpoint,
    this.additionalParams = const {},
  });

  /// Creates a Google OAuth provider configuration
  ///
  /// **What it does:**
  /// - Configures Google OAuth 2.0 with OpenID Connect
  /// - Sets up standard Google endpoints
  /// - Includes default scopes (openid, profile, email)
  /// - Enables offline access (refresh tokens)
  /// - Forces consent screen
  ///
  /// **Parameters:**
  /// - [clientId]: Your Google OAuth client ID (required)
  /// - [redirectUri]: Your registered redirect URI (required)
  /// - [scopes]: Custom scopes (optional, defaults to openid/profile/email)
  ///
  /// **Returns:** Configured OAuthProvider for Google
  ///
  /// **Example:**
  /// ```dart
  /// final google = OAuthProvider.google(
  ///   clientId: '123456789.apps.googleusercontent.com',
  ///   redirectUri: 'com.myapp://oauth/callback',
  /// );
  /// ```
  factory OAuthProvider.google({
    required String clientId,
    required String redirectUri,
    List<String>? scopes,
  }) =>
      OAuthProvider(
        type: OAuthProviderType.google,
        displayName: AppStrings.oauthProviderDisplayGoogle,
        authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
        tokenEndpoint: 'https://oauth2.googleapis.com/token',
        userInfoEndpoint: 'https://www.googleapis.com/oauth2/v2/userinfo',
        revocationEndpoint: 'https://oauth2.googleapis.com/revoke',
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: scopes ??
            [
              AppStrings.oauthScopeOpenId,
              AppStrings.oauthScopeProfile,
              AppStrings.oauthScopeEmail,
            ],
        additionalParams: {
          AppStrings.oauthParamAccessType: AppStrings.oauthValueOffline,
          AppStrings.oauthParamPrompt: AppStrings.oauthValueConsent,
        },
      );

  /// Creates a GitHub OAuth provider configuration
  ///
  /// **What it does:**
  /// - Configures GitHub OAuth 2.0
  /// - Sets up standard GitHub endpoints
  /// - Includes default scopes (read:user, user:email)
  ///
  /// **Parameters:**
  /// - [clientId]: Your GitHub OAuth app client ID (required)
  /// - [redirectUri]: Your registered redirect URI (required)
  /// - [scopes]: Custom scopes (optional, defaults to read:user, user:email)
  ///
  /// **Returns:** Configured OAuthProvider for GitHub
  ///
  /// **Example:**
  /// ```dart
  /// final github = OAuthProvider.github(
  ///   clientId: 'your-github-client-id',
  ///   redirectUri: 'com.myapp://oauth/callback',
  /// );
  /// ```
  factory OAuthProvider.github({
    required String clientId,
    required String redirectUri,
    List<String>? scopes,
  }) =>
      OAuthProvider(
        type: OAuthProviderType.github,
        displayName: AppStrings.oauthProviderDisplayGithub,
        authorizationEndpoint: 'https://github.com/login/oauth/authorize',
        tokenEndpoint: 'https://github.com/login/oauth/access_token',
        userInfoEndpoint: 'https://api.github.com/user',
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: scopes ?? [AppStrings.oauthScopeGithubReadUser, AppStrings.oauthScopeGithubUserEmail],
      );

  /// Creates a Microsoft OAuth provider configuration
  ///
  /// **What it does:**
  /// - Configures Microsoft OAuth 2.0 with OpenID Connect
  /// - Sets up Azure AD endpoints
  /// - Supports multi-tenant or single-tenant apps
  /// - Includes default scopes (openid, profile, email, offline_access)
  ///
  /// **Parameters:**
  /// - [clientId]: Your Microsoft app client ID (required)
  /// - [redirectUri]: Your registered redirect URI (required)
  /// - [tenant]: Azure AD tenant ID (optional, defaults to 'common' for multi-tenant)
  /// - [scopes]: Custom scopes (optional, defaults to openid/profile/email/offline_access)
  ///
  /// **Returns:** Configured OAuthProvider for Microsoft
  ///
  /// **Tenant options:**
  /// - 'common': Multi-tenant (personal and work accounts)
  /// - 'organizations': Work/school accounts only
  /// - 'consumers': Personal Microsoft accounts only
  /// - Specific tenant ID: Single tenant
  ///
  /// **Example:**
  /// ```dart
  /// final microsoft = OAuthProvider.microsoft(
  ///   clientId: 'your-microsoft-client-id',
  ///   redirectUri: 'com.myapp://oauth/callback',
  ///   tenant: 'common', // or specific tenant ID
  /// );
  /// ```
  factory OAuthProvider.microsoft({
    required String clientId,
    required String redirectUri,
    String? tenant,
    List<String>? scopes,
  }) {
    final tenantId = tenant ?? AppStrings.oauthValueCommon;
    return OAuthProvider(
      type: OAuthProviderType.microsoft,
      displayName: AppStrings.oauthProviderDisplayMicrosoft,
      authorizationEndpoint:
          'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize',
      tokenEndpoint:
          'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token',
      userInfoEndpoint: 'https://graph.microsoft.com/v1.0/me',
      clientId: clientId,
      redirectUri: redirectUri,
      scopes: scopes ??
          [
            AppStrings.oauthScopeOpenId,
            AppStrings.oauthScopeProfile,
            AppStrings.oauthScopeEmail,
            AppStrings.oauthScopeOfflineAccess,
          ],
    );
  }

  /// Builds the authorization URL with all required parameters
  ///
  /// **What it does:**
  /// - Constructs full OAuth2 authorization URL
  /// - Includes PKCE parameters (code_challenge)
  /// - Adds CSRF protection (state parameter)
  /// - URL-encodes all parameters
  /// - Includes provider-specific parameters
  ///
  /// **Parameters:**
  /// - [state]: Random CSRF protection token (required, should be cryptographically random)
  /// - [codeChallenge]: PKCE code challenge (required, SHA256 hash of verifier)
  /// - [codeChallengeMethod]: Hash method (optional, defaults to 'S256')
  ///
  /// **Returns:** Complete authorization URL to open in browser
  ///
  /// **Security:**
  /// - State prevents CSRF attacks
  /// - PKCE prevents authorization code interception
  /// - All parameters properly URL-encoded
  ///
  /// **Example:**
  /// ```dart
  /// final pkce = PKCEChallenge.generate();
  /// final state = generateRandomString(32);
  ///
  /// final url = provider.buildAuthorizationUrl(
  ///   state: state,
  ///   codeChallenge: pkce.codeChallenge,
  /// );
  ///
  /// // Open in browser
  /// await launchUrl(Uri.parse(url));
  /// ```
  String buildAuthorizationUrl({
    required String state,
    required String codeChallenge,
    String codeChallengeMethod = AppStrings.oauthValueS256,
  }) {
    final params = {
      AppStrings.oauthParamClientId: clientId,
      AppStrings.oauthParamRedirectUri: redirectUri,
      AppStrings.oauthParamResponseType: AppStrings.oauthValueCode,
      AppStrings.oauthParamScope: scopes.join(' '),
      AppStrings.oauthParamState: state,
      AppStrings.oauthParamCodeChallenge: codeChallenge,
      AppStrings.oauthParamChallengeMethod: codeChallengeMethod,
      ...additionalParams,
    };

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$authorizationEndpoint?$queryString';
  }

  /// Equatable props - equality based on all fields
  @override
  List<Object?> get props => [
        type,
        displayName,
        authorizationEndpoint,
        tokenEndpoint,
        userInfoEndpoint,
        clientId,
        redirectUri,
        scopes,
        revocationEndpoint,
        additionalParams,
      ];
}
