import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Service interface for biometric authentication
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
}

/// Implementation of BiometricService
class BiometricServiceImpl implements BiometricService {
  final LocalAuthentication localAuth;
  final FlutterSecureStorage storage;

  BiometricServiceImpl({
    required this.localAuth,
    required this.storage,
  });

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
}