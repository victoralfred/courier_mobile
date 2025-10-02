import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';
import 'package:delivery_app/features/auth/domain/services/token_manager.dart';
import 'package:delivery_app/features/auth/data/services/user_storage_service.dart';
import 'package:delivery_app/features/auth/domain/entities/jwt_token.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// TODO Implementation of the AuthRepository interface
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final BiometricService biometricService;
  final TokenManager tokenManager;
  late final UserStorageService _userStorageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.biometricService,
    required this.tokenManager,
    FlutterSecureStorage? secureStorage,
  }) {
    _userStorageService = UserStorageService(
      secureStorage: secureStorage ?? const FlutterSecureStorage(),
    );
  }

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Get the user model from remote data source
      // The remote data source includes tokens in the UserModel
      final userModel = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // Extract tokens from userModel
      final accessToken = userModel.accessToken;
      final refreshToken = userModel.refreshToken;

      // Create JwtToken and store via TokenManager
      // This will set the token on ApiClient automatically
      if (accessToken != null && accessToken.isNotEmpty) {
        final jwtToken = JwtToken(
          token: accessToken,
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 15)), // Default 15 mins
          refreshToken: refreshToken,
        );

        // Store token via TokenManager - this sets it on ApiClient
        final storeResult = await tokenManager.storeToken(jwtToken);
        if (storeResult.isLeft()) {
          return Left(storeResult.fold((f) => f, (_) => const UnexpectedFailure(message: 'Failed to store token')));
        }
      }

      // Cache the user locally
      await localDataSource.cacheUser(userModel);

      // Persist user data with role to secure storage
      await _userStorageService.saveUser(userModel);

      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure(message: AppStrings.errorUnexpected));
    }
  }

  @override
  Future<Either<Failure, User>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final userModel = await remoteDataSource.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );

      // Cache the user locally
      await localDataSource.cacheUser(userModel);

      // Persist user data with role to secure storage
      await _userStorageService.saveUser(userModel);

      // Note: Registration doesn't automatically authenticate the user
      // User must login after registration to get tokens

      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure(message: AppStrings.errorUnexpected));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      // Try to get user from persistent storage first
      final persistedUser = await _userStorageService.getCachedUser();
      if (persistedUser != null) {
        // Check if session is still valid only if we have a user
        if (await _userStorageService.isSessionExpired()) {
          // Session expired, clear data and require re-authentication
          await _userStorageService.clearUserData();
          return const Left(
              AuthenticationFailure(message: AppStrings.errorSessionExpired));
        }
        return Right(persistedUser);
      }

      // Then try local cache
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        // Save to persistent storage for next time
        await _userStorageService.saveUser(cachedUser);
        return Right(cachedUser);
      }

      // If no cached user, fetch from remote
      final userModel = await remoteDataSource.getCurrentUser();

      // Cache the user both locally and persistently
      await localDataSource.cacheUser(userModel);
      await _userStorageService.saveUser(userModel);

      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // If network error, try to return cached user
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        return Right(cachedUser);
      }
      return Left(NetworkFailure(message: e.message));
    } on AuthenticationException {
      return const Left(
          AuthenticationFailure(message: AppStrings.errorUserNotAuthenticated));
    } catch (e) {
      return const Left(UnexpectedFailure(message: AppStrings.errorUnexpected));
    }
  }

  @override
  Future<Either<Failure, bool>> logout() async {
    try {
      // Clear tokens via TokenManager - this clears from ApiClient too
      await tokenManager.clearTokens();

      // Clear cached user
      await localDataSource.clearCachedUser();

      // Clear persisted user data
      await _userStorageService.clearUserData();

      // Optionally call remote logout endpoint if available
      // await remoteDataSource.logout();

      return const Right(true);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorLogoutFailed));
    }
  }


  @override
  Future<bool> isAuthenticated() async {
    try {
      // Use TokenManager to check authentication status
      // This ensures consistency with the login flow
      return await tokenManager.isAuthenticated();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      // Use TokenManager to get access token
      // This ensures consistency with the login flow
      final result = await tokenManager.getAccessToken();
      return result.fold(
        (failure) => null,
        (token) => token,
      );
    } catch (e) {
      return null;
    }
  }


  @override
  Future<Either<Failure, User>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final userModel = await remoteDataSource.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      // Update cached user
      await localDataSource.cacheUser(userModel);

      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorUpdateProfileFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
      return const Right(true);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorPasswordResetEmailFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyEmail(String verificationCode) async {
    try {
      await remoteDataSource.verifyEmail(verificationCode);
      return const Right(true);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorVerifyEmailFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Right(true);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException {
      return const Left(AuthenticationFailure(
          message: AppStrings.errorCurrentPasswordIncorrect));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorChangePasswordFailed));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithBiometric() async {
    try {
      // Check if biometric is enabled
      if (!await localDataSource.isBiometricEnabled()) {
        return const Left(
            AuthenticationFailure(message: AppStrings.biometricNotEnabled));
      }

      // Authenticate using biometric
      final isAuthenticated = await biometricService.authenticate();
      if (!isAuthenticated) {
        return const Left(
            AuthenticationFailure(message: AppStrings.biometricFailed));
      }

      // Get stored credentials
      final credentials = await localDataSource.getBiometricCredentials();
      if (credentials == null) {
        return const Left(AuthenticationFailure(
            message: AppStrings.biometricNoStoredCredentials));
      }

      // Parse credentials (assuming format: email:password)
      final parts = credentials.split(':');
      if (parts.length != 2) {
        return const Left(AuthenticationFailure(
            message: AppStrings.biometricInvalidStoredCredentials));
      }

      // Login with stored credentials
      return login(email: parts[0], password: parts[1]);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.biometricLoginFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> enableBiometric() async {
    try {
      // Check if biometric is available
      final isAvailable = await biometricService.isAvailable();
      if (!isAvailable) {
        return const Left(
            ValidationFailure(message: AppStrings.biometricNotAvailable));
      }

      // Get current user
      final userResult = await getCurrentUser();
      if (userResult.isLeft()) {
        return const Left(AuthenticationFailure(
            message: AppStrings.errorUserNotAuthenticated));
      }

      // TODO For now, we'll need to prompt for password to enable biometric
      // In a real app, this would be handled differently
      // Store credentials securely (this is simplified, use proper encryption)
      // await localDataSource.enableBiometric(credentials);

      return const Right(true);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.biometricEnableFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> disableBiometric() async {
    try {
      await localDataSource.disableBiometric();
      return const Right(true);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.biometricDisableFailed));
    }
  }

  @override
  Future<bool> isBiometricEnabled() async {
    try {
      return await localDataSource.isBiometricEnabled();
    } catch (e) {
      return false;
    }
  }
}
