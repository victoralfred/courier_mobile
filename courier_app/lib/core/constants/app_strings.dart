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
  static const String errorInvalidEmailFormat = 'Invalid email format';
  static const String errorInvalidPhoneFormat = 'Invalid phone number format';
  static const String errorPasswordTooShort =
      'Password must be at least 8 characters';

  // Error Messages - Cache
  static const String errorCacheGeneral = 'Cache error occurred';
  static const String errorCacheExpired = 'Cache has expired';
  static const String errorCacheNotFound = 'Cache not found for key: {key}';

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

  // Utility method to replace placeholders in strings
  static String format(String template, Map<String, String> values) {
    String result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
