import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';
import 'package:delivery_app/features/auth/data/services/user_storage_service.dart';
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
  late final UserStorageService _userStorageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.biometricService,
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

      // Extract tokens from userModel and save them
      final accessToken = userModel.accessToken;
      final refreshToken = userModel.refreshToken;
      final csrfToken = userModel.csrfToken;

      // Save tokens to local storage
      if (accessToken != null && accessToken.isNotEmpty) {
        await localDataSource.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          csrfToken: csrfToken,
        );
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

      // Save tokens separately for authentication checks
      // TODO: Update when backend provides tokens in a standardized way
      // For now, using placeholder token to enable authentication check
      await localDataSource.saveTokens(
        accessToken:
            'placeholder_token_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: null,
        csrfToken: null,
      );

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
      // Clear local tokens and cached user
      await localDataSource.clearTokens();
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
  Future<Either<Failure, bool>> refreshToken() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null) {
        return const Left(
            AuthenticationFailure(message: AppStrings.errorNoRefreshToken));
      }

      final tokenData = await remoteDataSource.refreshToken(refreshToken);

      // Save new tokens
      await localDataSource.saveTokens(
        accessToken: tokenData['access_token'] as String,
        refreshToken: tokenData['refresh_token'] as String?,
        csrfToken: tokenData['csrf_token'] as String?,
      );

      return const Right(true);
    } on AuthenticationException {
      return const Left(
          AuthenticationFailure(message: AppStrings.errorInvalidRefreshToken));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorRefreshTokenFailed));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final token = await localDataSource.getAccessToken();
      return token != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await localDataSource.getAccessToken();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Either<Failure, String>> getCsrfToken() async {
    try {
      final token = await localDataSource.getCsrfToken();
      if (token == null) {
        return const Left(
            AuthenticationFailure(message: AppStrings.errorNoCsrfToken));
      }
      return Right(token);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorGetCsrfTokenFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? csrfToken,
  }) async {
    try {
      await localDataSource.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        csrfToken: csrfToken,
      );
      return const Right(true);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorSaveTokensFailed));
    }
  }

  @override
  Future<Either<Failure, bool>> clearTokens() async {
    try {
      await localDataSource.clearTokens();
      return const Right(true);
    } catch (e) {
      return const Left(
          UnexpectedFailure(message: AppStrings.errorClearTokensFailed));
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
