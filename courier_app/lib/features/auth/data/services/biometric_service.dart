import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';

/// Implementation of BiometricService
/// Data layer - concrete implementation with platform-specific code
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