import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';

/// Authentication repository interface
/// Defines the contract for authentication operations
abstract class AuthRepository {
  /// Authenticates a user with email and password
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Registers a new user
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  });

  /// Gets the currently authenticated user
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> getCurrentUser();

  /// Logs out the current user
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> logout();

  /// Refreshes the authentication token
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> refreshToken();

  /// Checks if a user is currently authenticated
  /// Returns true if authenticated, false otherwise
  Future<bool> isAuthenticated();

  /// Gets the current access token
  /// Returns null if not authenticated
  Future<String?> getAccessToken();

  /// Gets the CSRF token for write operations
  /// Returns [String] on success or [Failure] on error
  Future<Either<Failure, String>> getCsrfToken();

  /// Saves authentication tokens securely
  Future<Either<Failure, bool>> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? csrfToken,
  });

  /// Clears all authentication tokens
  Future<Either<Failure, bool>> clearTokens();

  /// Updates the current user information
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  });

  /// Sends a password reset email
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> sendPasswordResetEmail(String email);

  /// Verifies the user's email address
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> verifyEmail(String verificationCode);

  /// Changes the user's password
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Authenticates using biometric credentials
  /// Returns [User] on success or [Failure] on error
  Future<Either<Failure, User>> loginWithBiometric();

  /// Enables biometric authentication for the current user
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> enableBiometric();

  /// Disables biometric authentication for the current user
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> disableBiometric();

  /// Checks if biometric authentication is enabled for current user
  /// Returns true if enabled, false otherwise
  Future<bool> isBiometricEnabled();
}