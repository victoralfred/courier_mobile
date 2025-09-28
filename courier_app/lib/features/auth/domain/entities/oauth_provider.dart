import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';

/// Enum representing supported OAuth2 providers
enum OAuthProviderType {
  google,
  github,
  microsoft,
  apple,
}

/// Represents an OAuth2 authentication provider configuration.
class OAuthProvider extends Equatable {
  /// The type of OAuth provider.
  final OAuthProviderType type;

  /// The display name of the provider.
  final String displayName;

  /// The authorization endpoint URL.
  final String authorizationEndpoint;

  /// The token exchange endpoint URL.
  final String tokenEndpoint;

  /// The user info endpoint URL for fetching profile data.
  final String userInfoEndpoint;

  /// The OAuth2 client ID for this provider.
  final String clientId;

  /// The redirect URI registered with the provider.
  final String redirectUri;

  /// The requested OAuth2 scopes.
  final List<String> scopes;

  /// Optional revocation endpoint for token revocation.
  final String? revocationEndpoint;

  /// Additional provider-specific parameters.
  final Map<String, String> additionalParams;

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

  /// Creates a Google OAuth provider configuration.
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

  /// Creates a GitHub OAuth provider configuration.
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

  /// Creates a Microsoft OAuth provider configuration.
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

  /// Builds the authorization URL with all required parameters.
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
