/// Centralized string constants for localization
class AppStrings {
  AppStrings._();

  // App General
  static const String appTitle = 'Courier Delivery';
  static const String environmentDevelopment = 'Development';
  static const String environmentStaging = 'Staging';
  static const String environmentProduction = 'Production';

  // Error Messages - General
  static const String errorUnknown = 'An unknown error occurred';
  static const String errorUnexpected =
      'An unexpected error occurred. Please try again.';
  static const String errorSomethingWentWrong =
      'Something went wrong. Please try again later.';
  static const String requestWasCancelled = ' Request was cancelled';

  // Error Messages - Network
  static const String errorNoInternet = 'No internet connection';
  static const String errorConnectionTimeout = 'Connection timeout';
  static const String errorNetworkGeneral = 'Network error occurred';
  static const String errorCheckInternet =
      'Please check your internet connection and try again.';

  // Error Messages - Server
  static const String errorServerGeneral = 'Server error occurred';
  static const String errorInternalServer = 'Internal server error';
  static const String errorServiceUnavailable =
      'Service temporarily unavailable';

  // Error Messages - Authentication
  static const String errorUnauthorized = 'Unauthorized access';
  static const String errorSessionExpired = 'Session has expired';
  static const String errorInvalidCredentials = 'Invalid credentials';
  static const String errorAuthenticationFailed = 'Authentication failed';
  static const String errorPleaseLogin = 'Please login to continue.';

  // Error Messages - Authorization
  static const String errorAccessDenied = 'Access denied';
  static const String errorForbidden =
      'You do not have permission to perform this action';
  static const String errorAuthorizationFailed = 'Authorization failed';

  // Error Messages - Validation
  static const String errorValidationFailed = 'Validation failed';
  static const String errorInvalidInput = 'Invalid input data';
  static const String errorCheckInput =
      'Please check your input and try again.';
  static const String errorFieldRequired = 'This field is required';
  static const String errorInvalidPhoneFormat = 'Invalid phone number format';
  static const String errorPasswordTooShort =
      'Password must be at least 8 characters';

  // Error Messages - Cache
  static const String errorCacheGeneral = 'Cache error occurred';
  static const String errorCacheExpired = 'Cache has expired';
  static const String errorCacheNotFound = 'Cache not found for key: {key}';
  static const String errorCacheFailed = 'Failed to {operation}: {error}';

  // Error Messages - Resource
  static const String errorResourceNotFound = 'Resource not found';
  static const String errorPageNotFound = 'Page not found';
  static const String errorDataNotFound = 'Data not found';

  // Error Messages - Timeout
  static const String errorRequestTimeout = 'Request timeout';
  static const String errorOperationTimeout =
      'Operation timed out. Please try again.';

  // Error Messages - Offline
  static const String errorOfflineAction =
      'This action requires internet connection';
  static const String errorOfflineFeature =
      'This feature is not available offline';

  // Success Messages
  static const String successGeneral = 'Operation completed successfully';
  static const String successDataSaved = 'Data saved successfully';
  static const String successDataUpdated = 'Data updated successfully';
  static const String successDataDeleted = 'Data deleted successfully';

  // Loading Messages
  static const String loadingGeneral = 'Loading...';
  static const String loadingPleaseWait = 'Please wait...';
  static const String loadingData = 'Loading data...';
  static const String loadingSaving = 'Saving...';
  static const String loadingUpdating = 'Updating...';
  static const String loadingDeleting = 'Deleting...';

  // Button Labels
  static const String buttonOk = 'OK';
  static const String buttonCancel = 'Cancel';
  static const String buttonSave = 'Save';
  static const String buttonUpdate = 'Update';
  static const String buttonDelete = 'Delete';
  static const String buttonRetry = 'Retry';
  static const String buttonContinue = 'Continue';
  static const String buttonBack = 'Back';
  static const String buttonNext = 'Next';
  static const String buttonFinish = 'Finish';
  static const String buttonSubmit = 'Submit';
  static const String buttonConfirm = 'Confirm';
  static const String buttonYes = 'Yes';
  static const String buttonNo = 'No';

  // Authentication
  static const String authLogin = 'Login';
  static const String authLogout = 'Logout';
  static const String authRegister = 'Register';
  static const String authSignUp = 'Sign Up';
  static const String authForgotPassword = 'Forgot Password?';
  static const String authResetPassword = 'Reset Password';
  static const String authEmail = 'Email';
  static const String authPassword = 'Password';
  static const String authConfirmPassword = 'Confirm Password';
  static const String authFirstName = 'First Name';
  static const String authLastName = 'Last Name';
  static const String authPhoneNumber = 'Phone Number';

  // User Roles
  static const String roleCustomer = 'Customer';
  static const String roleDriver = 'Driver';
  static const String roleAdmin = 'Admin';

  // Order Status
  static const String orderStatusPending = 'Pending';
  static const String orderStatusAssigned = 'Assigned';
  static const String orderStatusPickup = 'Pickup in Progress';
  static const String orderStatusInTransit = 'In Transit';
  static const String orderStatusCompleted = 'Completed';
  static const String orderStatusCancelled = 'Cancelled';

  // Driver Status
  static const String driverStatusPending = 'Pending Approval';
  static const String driverStatusApproved = 'Approved';
  static const String driverStatusRejected = 'Rejected';
  static const String driverStatusSuspended = 'Suspended';

  // Driver Availability
  static const String driverAvailabilityOffline = 'Offline';
  static const String driverAvailabilityAvailable = 'Available';
  static const String driverAvailabilityBusy = 'Busy';

  // Vehicle Types
  static const String vehicleCar = 'Car';
  static const String vehicleMotorcycle = 'Motorcycle';
  static const String vehicleBicycle = 'Bicycle';
  static const String vehicleVan = 'Van';

  // Package Sizes
  static const String packageSmall = 'Small';
  static const String packageMedium = 'Medium';
  static const String packageLarge = 'Large';
  static const String packageXLarge = 'Extra Large';

  // Payment Methods
  static const String paymentCard = 'Credit/Debit Card';
  static const String paymentBankTransfer = 'Bank Transfer';
  static const String paymentWallet = 'Digital Wallet';
  static const String paymentCash = 'Cash';

  // Validation - Entity ID
  static const String errorEntityIdEmpty = 'EntityID cannot be empty';
  static const String errorInvalidUuidFormat = 'Invalid UUID format: {id}';

  // Validation - Email
  static const String errorEmailEmpty = 'Email cannot be empty';
  static const String errorEmailWhitespace =
      'Email cannot be empty or whitespace';
  static const String errorInvalidEmailFormat = 'Invalid email format: {email}';
  static const String errorEmailConsecutiveDots =
      'Email cannot contain consecutive dots';
  static const String errorEmailEndsWithDot = 'Email cannot end with a dot';

  // Validation - Phone Number
  static const String errorPhoneEmpty = 'Phone number cannot be empty';
  static const String errorPhoneMissingCountryCode =
      'Phone number must include country code (start with +)';
  static const String errorPhoneInvalidChars =
      'Phone number must contain only digits after country code';
  static const String errorPhoneTooShort =
      'Phone number too short (minimum 10 characters including country code)';
  static const String errorPhoneTooLong =
      'Phone number too long (maximum 20 characters including country code)';

  // Validation - User
  static const String errorFirstNameEmpty = 'First name cannot be empty';
  static const String errorLastNameEmpty = 'Last name cannot be empty';
  static const String errorFirstNameTooShort =
      'First name must be at least 2 characters';
  static const String errorLastNameTooShort =
      'Last name must be at least 2 characters';
  static const String errorFirstNameTooLong =
      'First name must not exceed 50 characters';
  static const String errorLastNameTooLong =
      'Last name must not exceed 50 characters';
  static const String errorInvalidUserStatus = 'Invalid user status: {status}';

  // Authentication Messages
  static const String authLoginSuccess = 'Login successful';
  static const String authLogoutSuccess = 'Logout successful';
  static const String authRegisterSuccess = 'Registration successful';
  static const String authTokenRefreshed = 'Session refreshed';
  static const String authPasswordResetSent =
      'Password reset instructions sent to your email';
  static const String authEmailVerified = 'Email verified successfully';
  static const String authBiometricEnabled = 'Biometric authentication enabled';
  static const String authBiometricDisabled =
      'Biometric authentication disabled';

  // Authentication Errors
  static const String errorLoginFailed =
      'Login failed. Please check your credentials.';
  static const String errorRegistrationFailed =
      'Registration failed. Please try again.';
  static const String errorTokenExpired =
      'Your session has expired. Please login again.';
  static const String errorTokenInvalid = 'Invalid authentication token';
  static const String errorUserNotFound = 'User not found';
  static const String errorEmailAlreadyExists =
      'An account with this email already exists';
  static const String errorPhoneAlreadyExists =
      'An account with this phone number already exists';
  static const String errorWeakPassword = 'Password is too weak';
  static const String errorPasswordsDoNotMatch = 'Passwords do not match';
  static const String errorBiometricNotAvailable =
      'Biometric authentication is not available on this device';
  static const String errorBiometricNotEnrolled =
      'No biometric credentials are enrolled';
  static const String errorBiometricFailed = 'Biometric authentication failed';

  // Error Codes (for mapping backend error codes)
  static const String errorCodeValidation = 'VALIDATION_ERROR';
  static const String errorCodeUnauthorized = 'UNAUTHORIZED';
  static const String errorCodeForbidden = 'FORBIDDEN';
  static const String errorCodeNotFound = 'NOT_FOUND';
  static const String errorCodeTimeout = 'TIMEOUT';
  static const String errorCodeNoConnection = 'NO_CONNECTION';
  static const String errorCodeServerError = 'SERVER_ERROR';
  static const String errorCodeUnknown = 'UNKNOWN_ERROR';
  static const String errorCodeSessionExpired = 'SESSION_EXPIRED';
  static const String errorCodeInvalidCredentials = 'INVALID_CREDENTIALS';
  static const String errorCodeNetworkError = 'NETWORK_ERROR';
  static const String errorCodeCacheError = 'CACHE_ERROR';
  static const String errorCodeExpired = 'EXPIRED';

  // OAuth2 Error Messages
  static const String errorOAuthClientIdRequired =
      'OAuth client ID is required';
  static const String errorOAuthRedirectUriRequired =
      'OAuth redirect URI is required';
  static const String errorOAuthCodeRequired = 'Authorization code is required';
  static const String errorOAuthStateRequired = 'State parameter is required';
  static const String errorOAuthRequestInvalid =
      'Authorization request is invalid or expired';
  static const String errorOAuthGeneratePKCE =
      'Failed to generate PKCE challenge: {error}';
  static const String errorOAuthCodeVerifierLength =
      'Code verifier length must be between {min} and {max}';
  static const String errorOAuthInvalidVerifierLength =
      'Invalid code verifier length. Must be between {min} and {max}';
  static const String errorOAuthProviderError =
      '{provider} authentication failed: {error}';
  static const String errorOAuthStateValidationFailed =
      'OAuth state validation failed';
  static const String errorOAuthCodeExpired = 'Authorization code has expired';
  static const String errorOAuthTokenExchangeFailed =
      'Failed to exchange authorization code for tokens';
  static const String errorOAuthUserInfoFailed =
      'Failed to fetch user information from {provider}';
  static const String errorOAuthRefreshTokenFailed =
      'Failed to refresh access token';
  static const String errorOAuthRevokeTokenFailed = 'Failed to revoke token';
  static const String errorOAuthLinkAccountFailed =
      'Failed to link {provider} account';
  static const String errorOAuthUnlinkAccountFailed =
      'Failed to unlink {provider} account';
  static const String errorOAuthProviderAlreadyLinked =
      '{provider} account is already linked';
  static const String errorOAuthProviderNotLinked =
      '{provider} account is not linked';
  static const String errorOAuthInvalidResponse =
      'Invalid response from {provider}';
  static const String errorOAuthNetworkError =
      'Network error during {provider} authentication';

  // OAuth2 Success Messages
  static const String successOAuthLogin =
      'Successfully logged in with {provider}';
  static const String successOAuthLinked =
      '{provider} account linked successfully';
  static const String successOAuthUnlinked =
      '{provider} account unlinked successfully';
  static const String successOAuthTokenRefreshed =
      'Access token refreshed successfully';
  static const String successOAuthTokenRevoked = 'Token revoked successfully';

  // OAuth2 Loading Messages
  static const String loadingOAuthLogin = 'Logging in with {provider}...';
  static const String loadingOAuthLinking = 'Linking {provider} account...';
  static const String loadingOAuthUnlinking = 'Unlinking {provider} account...';
  static const String loadingOAuthUserInfo = 'Fetching user information...';
  static const String loadingOAuthTokenRefresh = 'Refreshing access token...';

  // OAuth2 Provider Names
  static const String oauthProviderGoogle = 'Google';
  static const String oauthProviderGithub = 'GitHub';
  static const String oauthProviderMicrosoft = 'Microsoft';
  static const String oauthProviderApple = 'Apple';

  // OAuth2 UI Strings
  static const String oauthLoginWithProvider = 'Login with {provider}';
  static const String oauthLinkProvider = 'Link {provider} account';
  static const String oauthUnlinkProvider = 'Unlink {provider} account';
  static const String oauthChooseProvider = 'Choose a login method';
  static const String oauthLinkedAccounts = 'Linked accounts';
  static const String oauthNoLinkedAccounts = 'No linked accounts';

  // OAuth2 Technical Constants
  static const String oauthStoragePrefixAuthRequest = 'oauth_auth_request_';
  static const String oauthStoragePrefixLinkedProviders = 'oauth_linked_providers_';
  static const String oauthStoragePrefixTokenCache = 'oauth_token_cache_';
  static const String oauthStorageKeyRequestIndex = 'oauth_request_index';

  // OAuth2 Provider Display Names
  static const String oauthProviderDisplayGoogle = 'Google';
  static const String oauthProviderDisplayGithub = 'GitHub';
  static const String oauthProviderDisplayMicrosoft = 'Microsoft';
  static const String oauthProviderDisplayApple = 'Apple';

  // OAuth2 URL Schemes
  static const String oauthUrlSchemeBaseDev = 'com.courier.delivery.dev://oauth/';
  static const String oauthUrlSchemeBaseStaging = 'com.courier.delivery.staging://oauth/';
  static const String oauthUrlSchemeBaseProd = 'com.courier.delivery://oauth/';
  static const String oauthUrlSchemeCallback = '/callback';

  // OAuth2 Scopes
  static const String oauthScopeOpenId = 'openid';
  static const String oauthScopeProfile = 'profile';
  static const String oauthScopeEmail = 'email';
  static const String oauthScopeOfflineAccess = 'offline_access';
  static const String oauthScopeGithubReadUser = 'read:user';
  static const String oauthScopeGithubUserEmail = 'user:email';
  static const String oauthScopeAppleName = 'name';

  // OAuth2 Parameters
  static const String oauthParamClientId = 'client_id';
  static const String oauthParamRedirectUri = 'redirect_uri';
  static const String oauthParamResponseType = 'response_type';
  static const String oauthParamScope = 'scope';
  static const String oauthParamState = 'state';
  static const String oauthParamCodeChallenge = 'code_challenge';
  static const String oauthParamChallengeMethod = 'code_challenge_method';
  static const String oauthValueCode = 'code';
  static const String oauthParamAccessType = 'access_type';
  static const String oauthParamPrompt = 'prompt';
  static const String oauthParamResponseMode = 'response_mode';
  static const String oauthValueOffline = 'offline';
  static const String oauthValueConsent = 'consent';
  static const String oauthValueFormPost = 'form_post';
  static const String oauthValueS256 = 'S256';
  static const String oauthValueCommon = 'common';

  // OAuth2 API Endpoints
  static const String oauthApiCallback = '/api/v1/auth/oauth/callback';
  static const String oauthApiRefresh = '/api/v1/auth/refresh';
  static const String oauthApiRevoke = '/api/v1/auth/revoke';
  static const String oauthApiUsersMe = '/api/v1/users/me';

  // OAuth2 Field Names
  static const String oauthFieldProvider = 'provider';
  static const String oauthFieldCode = 'code';
  static const String oauthFieldCodeVerifier = 'code_verifier';
  static const String oauthFieldRefreshToken = 'refresh_token';
  static const String oauthFieldToken = 'token';
  static const String oauthFieldError = 'error';
  static const String oauthFieldOperation = 'operation';
  static const String oauthFieldMin = 'min';
  static const String oauthFieldMax = 'max';

  // OAuth2 Warning Messages
  static const String warningOAuthDeleteAuthRequest = 'Warning: Failed to delete authorization request: ';
  static const String warningOAuthCleanupExpired = 'Warning: Failed to cleanup expired requests: ';
  static const String warningOAuthUpdateIndex = 'Warning: Failed to update request index: ';
  static const String warningOAuthTokenRevocation = 'Token revocation warning: ';

  // OAuth2 Cache Operation Names
  static const String oauthOpStoreAuthRequest = 'store authorization request';
  static const String oauthOpGetAuthRequest = 'get authorization request';
  static const String oauthOpStoreLinkedProviders = 'store linked providers';
  static const String oauthOpGetLinkedProviders = 'get linked providers';
  static const String oauthOpCacheTokens = 'cache tokens';
  static const String oauthOpClearAllData = 'clear all OAuth data';

  // Authorization Header
  static const String authorizationBearer = 'Bearer ';

  // OAuth2 Error Codes
  static const String oauthErrorCodeTokenExchangeFailed = 'OAUTH_TOKEN_EXCHANGE_FAILED';

  // OAuth2 Configuration Validation
  static const String oauthConfigValidationPrefix = 'YOUR_';
  static const String oauthMissingConfigMessage = 'OAuth client ID for %s is not configured. Please set the appropriate environment variable or use a .env file.';

  // PKCE Character Set
  static const String pkceUnreservedChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  // Utility method to replace placeholders in strings
  static String format(String template, Map<String, String> values) {
    String result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
