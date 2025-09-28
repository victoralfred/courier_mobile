import '../../../../core/config/app_config.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/config/oauth_env.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/oauth_provider.dart';

/// OAuth configuration for different providers and environments
class OAuthConfig {
  /// Get OAuth provider configuration based on environment
  static OAuthProvider getProvider(OAuthProviderType type) {
    switch (type) {
      case OAuthProviderType.google:
        return _getGoogleProvider();
      case OAuthProviderType.github:
        return _getGithubProvider();
      case OAuthProviderType.microsoft:
        return _getMicrosoftProvider();
      case OAuthProviderType.apple:
        return _getAppleProvider();
    }
  }

  static OAuthProvider _getGoogleProvider() {
    final env = AppConfig.config.name;

    final String clientId;
    switch (env) {
      case Environment.development:
        clientId = OAuthEnv.googleClientIdDev;
        break;
      case Environment.staging:
        clientId = OAuthEnv.googleClientIdStaging;
        break;
      case Environment.production:
        clientId = OAuthEnv.googleClientIdProd;
        break;
      default:
        clientId = OAuthEnv.googleClientIdDev;
        break;
    }

    if (!OAuthEnv.isConfigured(clientId)) {
      throw ConfigurationException(
        message: OAuthEnv.getMissingConfigMessage(AppStrings.oauthProviderGoogle),
      );
    }

    return OAuthProvider.google(
      clientId: clientId,
      redirectUri: _getRedirectUri(AppStrings.oauthProviderGoogle.toLowerCase()),
      scopes: [
        AppStrings.oauthScopeOpenId,
        AppStrings.oauthScopeProfile,
        AppStrings.oauthScopeEmail,
      ],
    );
  }

  static OAuthProvider _getGithubProvider() {
    final env = AppConfig.config.name;

    final String clientId;
    switch (env) {
      case Environment.development:
        clientId = OAuthEnv.githubClientIdDev;
        break;
      case Environment.staging:
        clientId = OAuthEnv.githubClientIdStaging;
        break;
      case Environment.production:
        clientId = OAuthEnv.githubClientIdProd;
        break;
      default:
        clientId = OAuthEnv.githubClientIdDev;
        break;
    }

    if (!OAuthEnv.isConfigured(clientId)) {
      throw ConfigurationException(
        message: OAuthEnv.getMissingConfigMessage(AppStrings.oauthProviderGithub),
      );
    }

    return OAuthProvider.github(
      clientId: clientId,
      redirectUri: _getRedirectUri(AppStrings.oauthProviderGithub.toLowerCase()),
      scopes: [
        AppStrings.oauthScopeGithubReadUser,
        AppStrings.oauthScopeGithubUserEmail,
      ],
    );
  }

  static OAuthProvider _getMicrosoftProvider() {
    final env = AppConfig.config.name;

    final String clientId;
    final String tenant;
    switch (env) {
      case Environment.development:
        clientId = OAuthEnv.microsoftClientIdDev;
        tenant = OAuthEnv.microsoftTenantDev;
        break;
      case Environment.staging:
        clientId = OAuthEnv.microsoftClientIdStaging;
        tenant = OAuthEnv.microsoftTenantStaging;
        break;
      case Environment.production:
        clientId = OAuthEnv.microsoftClientIdProd;
        tenant = OAuthEnv.microsoftTenantProd;
        break;
      default:
        clientId = OAuthEnv.microsoftClientIdDev;
        tenant = OAuthEnv.microsoftTenantDev;
        break;
    }

    if (!OAuthEnv.isConfigured(clientId)) {
      throw ConfigurationException(
        message: OAuthEnv.getMissingConfigMessage(AppStrings.oauthProviderMicrosoft),
      );
    }

    return OAuthProvider.microsoft(
      clientId: clientId,
      redirectUri: _getRedirectUri(AppStrings.oauthProviderMicrosoft.toLowerCase()),
      tenant: tenant,
      scopes: [
        AppStrings.oauthScopeOpenId,
        AppStrings.oauthScopeProfile,
        AppStrings.oauthScopeEmail,
        AppStrings.oauthScopeOfflineAccess,
      ],
    );
  }

  static OAuthProvider _getAppleProvider() {
    final env = AppConfig.config.name;

    // Apple Sign In configuration
    final String clientId;
    switch (env) {
      case Environment.development:
        clientId = OAuthEnv.appleServiceIdDev;
        break;
      case Environment.staging:
        clientId = OAuthEnv.appleServiceIdStaging;
        break;
      case Environment.production:
        clientId = OAuthEnv.appleServiceIdProd;
        break;
      default:
        clientId = OAuthEnv.appleServiceIdDev;
        break;
    }

    if (!OAuthEnv.isConfigured(clientId)) {
      throw ConfigurationException(
        message: OAuthEnv.getMissingConfigMessage(AppStrings.oauthProviderApple),
      );
    }

    // Apple uses a different OAuth flow, but we'll use similar structure
    return OAuthProvider(
      type: OAuthProviderType.apple,
      displayName: AppStrings.oauthProviderDisplayApple,
      authorizationEndpoint: 'https://appleid.apple.com/auth/authorize',
      tokenEndpoint: 'https://appleid.apple.com/auth/token',
      userInfoEndpoint: '', // Apple doesn't provide a userinfo endpoint
      clientId: clientId,
      redirectUri: _getRedirectUri(AppStrings.oauthProviderApple.toLowerCase()),
      scopes: [
        AppStrings.oauthScopeAppleName,
        AppStrings.oauthScopeEmail,
      ],
      additionalParams: {
        AppStrings.oauthParamResponseMode: AppStrings.oauthValueFormPost,
      },
    );
  }

  /// Get the redirect URI based on the provider and platform
  static String _getRedirectUri(String provider) {
    // Custom URL scheme for mobile apps
    // This should match what's configured in your OAuth provider settings
    final env = AppConfig.config.name;

    switch (env) {
      case Environment.development:
        return '${AppStrings.oauthUrlSchemeBaseDev}$provider${AppStrings.oauthUrlSchemeCallback}';
      case Environment.staging:
        return '${AppStrings.oauthUrlSchemeBaseStaging}$provider${AppStrings.oauthUrlSchemeCallback}';
      case Environment.production:
        return '${AppStrings.oauthUrlSchemeBaseProd}$provider${AppStrings.oauthUrlSchemeCallback}';
      default:
        return '${AppStrings.oauthUrlSchemeBaseDev}$provider${AppStrings.oauthUrlSchemeCallback}';
    }
  }

  /// Validate OAuth configuration
  static bool validateConfiguration(OAuthProvider provider) {
    // Check that client ID is not a placeholder
    if (provider.clientId.startsWith(AppStrings.oauthConfigValidationPrefix) ||
        provider.clientId.isEmpty) {
      return false;
    }

    // Check that redirect URI is properly formatted
    if (!provider.redirectUri.contains('://')) {
      return false;
    }

    // Check that required endpoints are present
    if (provider.authorizationEndpoint.isEmpty ||
        provider.tokenEndpoint.isEmpty) {
      return false;
    }

    return true;
  }
}