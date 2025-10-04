import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';

/// [BiometricServiceImpl] - Platform-specific biometric authentication implementation
///
/// **What it does:**
/// - Detects biometric hardware availability (Face ID, Touch ID, fingerprint)
/// - Checks if user has enrolled biometric credentials
/// - Performs biometric authentication prompts
/// - Manages user's biometric preference (enabled/disabled)
/// - Tracks enrollment prompt display state
///
/// **Why it exists:**
/// - Implements domain BiometricService interface with actual platform code
/// - Wraps local_auth plugin for cross-platform compatibility
/// - Stores biometric preferences in secure storage
/// - Provides graceful fallback when biometrics unavailable
/// - Separates platform-specific code from business logic
///
/// **Architecture:**
/// ```
/// Presentation Layer
///        ↓
/// Domain Layer (BiometricService interface)
///        ↓
/// Data Layer (BiometricServiceImpl) ← YOU ARE HERE
///        ↓
/// ├─ LocalAuthentication (iOS/Android biometric APIs)
/// └─ FlutterSecureStorage (preferences storage)
/// ```
///
/// **Biometric Flow:**
/// ```
/// User Action
///      ↓
/// isAvailable()
///   ↙       ↘
///  NO       YES
///   ↓        ↓
/// Show   authenticate()
/// error      ↓
///       Show biometric prompt
///            ↓
///      User authenticates
///       ↙          ↘
///    Success     Failure
///       ↓           ↓
///   Continue    Show error
/// ```
///
/// **Platform Support:**
/// - iOS: Face ID, Touch ID
/// - Android: Fingerprint, Face Unlock, Iris
/// - Fallback: Device PIN/Pattern (if biometricOnly: false)
///
/// **Usage Example:**
/// ```dart
/// final biometricService = BiometricServiceImpl(
///   localAuth: LocalAuthentication(),
///   storage: FlutterSecureStorage(),
/// );
///
/// // Check availability
/// if (await biometricService.isAvailable()) {
///   // Prompt for authentication
///   final authenticated = await biometricService.authenticate(
///     localizedReason: 'Unlock your account',
///   );
///
///   if (authenticated) {
///     // Proceed with login
///   }
/// }
///
/// // Enable biometric for future logins
/// await biometricService.enableBiometric();
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Add specific error types instead of returning false
/// - Currently, all errors silently return false (no context for UI)
/// - [Medium Priority] Add biometric type detection (Face ID vs Touch ID)
/// - UI could show appropriate icons and messages
/// - [Medium Priority] Implement biometric invalidation detection
/// - Detect when user adds/removes biometric credentials
/// - [Low Priority] Add analytics for authentication success/failure rates
/// - [Low Priority] Support multiple biometric modalities simultaneously
class BiometricServiceImpl implements BiometricService {
  /// Platform-specific biometric authentication handler
  ///
  /// **Why:**
  /// - Abstracts iOS/Android biometric APIs
  /// - Provides cross-platform interface
  final LocalAuthentication localAuth;

  /// Secure storage for biometric preferences
  ///
  /// **Why:**
  /// - Stores user's enable/disable preference
  /// - Tracks enrollment prompt display
  final FlutterSecureStorage storage;

  BiometricServiceImpl({
    required this.localAuth,
    required this.storage,
  });

  /// Checks if biometric authentication is available AND enrolled
  ///
  /// **What it does:**
  /// 1. Checks if device has biometric hardware
  /// 2. Checks if user has enrolled biometric credentials
  /// 3. Returns true only if both conditions met
  ///
  /// **Why both checks:**
  /// - Device may have hardware but no enrolled credentials
  /// - Enrolled check ensures user can actually authenticate
  ///
  /// **Flow Diagram:**
  /// ```
  /// isAvailable()
  ///       ↓
  /// isDeviceSupported()
  ///   ↙       ↘
  ///  NO       YES
  ///   ↓        ↓
  /// false  isEnrolled()
  ///         ↙      ↘
  ///       NO       YES
  ///        ↓        ↓
  ///     false     true
  /// ```
  ///
  /// **Returns:**
  /// - true: Biometrics available and enrolled
  /// - false: No hardware, not enrolled, or error
  ///
  /// **Edge Cases:**
  /// - Exception during check → Returns false
  /// - Device supported but no enrollment → Returns false
  ///
  /// **Example:**
  /// ```dart
  /// if (await biometricService.isAvailable()) {
  ///   // Show biometric login option
  ///   showBiometricLoginButton();
  /// } else {
  ///   // Show traditional login only
  ///   showPasswordLogin();
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Return specific reason for unavailability
  /// - UI needs to know: no hardware vs not enrolled vs error
  @override
  Future<bool> isAvailable() async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final isEnrolled = await this.isEnrolled();
      return isEnrolled;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isEnrolled() async {
    try {
      final availableBiometrics = await localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Prompts user for biometric authentication
  ///
  /// **What it does:**
  /// 1. Checks if biometrics are available
  /// 2. Shows platform-specific biometric prompt (Face ID, Touch ID, Fingerprint)
  /// 3. Waits for user authentication
  /// 4. Returns authentication result
  ///
  /// **Why custom reason:**
  /// - iOS requires explanation for Face ID usage (App Store requirement)
  /// - Localized reason shown to user in system prompt
  /// - Defaults to generic message if not provided
  ///
  /// **Authentication Options:**
  /// - biometricOnly: false → Allows fallback to device PIN/pattern
  /// - stickyAuth: true → Keeps auth active during app lifecycle
  ///
  /// **Flow Diagram:**
  /// ```
  /// authenticate(reason)
  ///       ↓
  /// isAvailable()
  ///   ↙       ↘
  ///  NO       YES
  ///   ↓        ↓
  /// false  Show biometric prompt
  ///             ↓
  ///        User attempts
  ///         ↙        ↘
  ///    Success    Failure
  ///       ↓          ↓
  ///     true       false
  /// ```
  ///
  /// **Returns:**
  /// - true: User authenticated successfully
  /// - false: Authentication failed, cancelled, or unavailable
  ///
  /// **Edge Cases:**
  /// - Biometrics not available → Returns false immediately
  /// - User cancels prompt → Returns false
  /// - User fails too many attempts → Returns false (iOS may lock)
  /// - Exception during auth → Returns false
  ///
  /// **Example:**
  /// ```dart
  /// final authenticated = await biometricService.authenticate(
  ///   localizedReason: 'Authenticate to view your orders',
  /// );
  ///
  /// if (authenticated) {
  ///   navigateToOrders();
  /// } else {
  ///   showError('Authentication failed');
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Return enum instead of bool (Success, Failed, Cancelled, NotAvailable)
  /// - UI needs to distinguish between failure types
  /// - [Medium Priority] Add custom biometric prompt styling (Android only)
  /// - [Low Priority] Add biometric attempt counting
  @override
  Future<bool> authenticate({String? localizedReason}) async {
    try {
      final isAvailable = await this.isAvailable();
      if (!isAvailable) return false;

      final authenticated = await localAuth.authenticate(
        localizedReason: localizedReason ?? AppStrings.biometricAuthReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await localAuth.canCheckBiometrics ||
             await localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await storage.read(key: AppStrings.keyBiometricEnabled);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> enableBiometric() async {
    try {
      await storage.write(
        key: AppStrings.keyBiometricEnabled,
        value: 'true',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> disableBiometric() async {
    try {
      await storage.write(
        key: AppStrings.keyBiometricEnabled,
        value: 'false',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasEnrollmentBeenShown() async {
    try {
      final value = await storage.read(
        key: AppStrings.keyBiometricEnrollmentShown,
      );
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> markEnrollmentShown() async {
    try {
      await storage.write(
        key: AppStrings.keyBiometricEnrollmentShown,
        value: 'true',
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}