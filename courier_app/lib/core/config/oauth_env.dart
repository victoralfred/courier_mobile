/// OAuth Environment Configuration
///
/// In production, these values should be injected via:
/// 1. CI/CD environment variables
/// 2. Secure key management service
/// 3. Build-time configuration
///
/// For local development, create a `.env` file (git-ignored) with actual values
class OAuthEnv {
  // Development OAuth Client IDs
  static const String googleClientIdDev = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID_DEV',
    defaultValue: '', // Empty default, must be provided
  );

  static const String githubClientIdDev = String.fromEnvironment(
    'GITHUB_OAUTH_CLIENT_ID_DEV',
    defaultValue: '',
  );

  static const String microsoftClientIdDev = String.fromEnvironment(
    'MICROSOFT_OAUTH_CLIENT_ID_DEV',
    defaultValue: '',
  );

  static const String appleServiceIdDev = String.fromEnvironment(
    'APPLE_OAUTH_SERVICE_ID_DEV',
    defaultValue: '',
  );

  // Staging OAuth Client IDs
  static const String googleClientIdStaging = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID_STAGING',
    defaultValue: '',
  );

  static const String githubClientIdStaging = String.fromEnvironment(
    'GITHUB_OAUTH_CLIENT_ID_STAGING',
    defaultValue: '',
  );

  static const String microsoftClientIdStaging = String.fromEnvironment(
    'MICROSOFT_OAUTH_CLIENT_ID_STAGING',
    defaultValue: '',
  );

  static const String appleServiceIdStaging = String.fromEnvironment(
    'APPLE_OAUTH_SERVICE_ID_STAGING',
    defaultValue: '',
  );

  // Production OAuth Client IDs
  static const String googleClientIdProd = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID_PROD',
    defaultValue: '',
  );

  static const String githubClientIdProd = String.fromEnvironment(
    'GITHUB_OAUTH_CLIENT_ID_PROD',
    defaultValue: '',
  );

  static const String microsoftClientIdProd = String.fromEnvironment(
    'MICROSOFT_OAUTH_CLIENT_ID_PROD',
    defaultValue: '',
  );

  static const String appleServiceIdProd = String.fromEnvironment(
    'APPLE_OAUTH_SERVICE_ID_PROD',
    defaultValue: '',
  );

  // Microsoft Tenant IDs
  static const String microsoftTenantDev = String.fromEnvironment(
    'MICROSOFT_OAUTH_TENANT_DEV',
    defaultValue: 'common',
  );

  static const String microsoftTenantStaging = String.fromEnvironment(
    'MICROSOFT_OAUTH_TENANT_STAGING',
    defaultValue: 'common',
  );

  static const String microsoftTenantProd = String.fromEnvironment(
    'MICROSOFT_OAUTH_TENANT_PROD',
    defaultValue: 'common',
  );

  /// Check if OAuth is properly configured for the given environment
  static bool isConfigured(String clientId) =>
      clientId.isNotEmpty && !clientId.startsWith('YOUR_');

  /// Get error message for missing configuration
  static String getMissingConfigMessage(String provider) =>
      'OAuth client ID for $provider is not configured. '
      'Please set the appropriate environment variable or use a .env file.';
}
