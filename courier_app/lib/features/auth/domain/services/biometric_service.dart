import 'package:local_auth/local_auth.dart';

/// Service interface for biometric authentication
/// Domain layer - defines the contract for biometric operations
abstract class BiometricService {
  /// Check if biometric authentication is available on the device
  Future<bool> isAvailable();

  /// Check if biometric authentication is enrolled on the device
  Future<bool> isEnrolled();

  /// Authenticate the user using biometric authentication
  Future<bool> authenticate({String? localizedReason});

  /// Get available biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics();

  /// Check if the device supports biometric authentication
  Future<bool> isDeviceSupported();

  /// Check if user has enabled biometric authentication in app settings
  Future<bool> isBiometricEnabled();

  /// Enable biometric authentication in app settings
  Future<bool> enableBiometric();

  /// Disable biometric authentication in app settings
  Future<bool> disableBiometric();

  /// Check if biometric enrollment dialog has been shown to user
  Future<bool> hasEnrollmentBeenShown();

  /// Mark that biometric enrollment dialog has been shown
  Future<bool> markEnrollmentShown();
}