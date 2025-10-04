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

/// [AuthRepositoryImpl] - Complete authentication repository implementation
///
/// **What it does:**
/// - Orchestrates authentication flow across multiple data sources
/// - Handles login, registration, logout, and profile management
/// - Manages token storage and synchronization with ApiClient
/// - Coordinates user data caching (local + persistent storage)
/// - Implements biometric authentication with credential storage
/// - Validates session expiration and forces re-authentication
/// - Converts data layer exceptions to domain failures
///
/// **Why it exists:**
/// - Implements domain AuthRepository interface with actual platform code
/// - Bridges domain layer (use cases) and data layer (data sources)
/// - Centralizes authentication business logic and orchestration
/// - Provides clean error handling via Either<Failure, T>
/// - Enables testability through dependency injection
/// - Separates concerns: domain doesn't know about HTTP/storage
///
/// **Architecture (Repository Pattern):**
/// ```
/// Presentation Layer (UI/Bloc)
///          ↓
/// Domain Layer (Use Cases)
///          ↓
/// Domain Repository Interface
///          ↓
/// Data Repository Implementation ← YOU ARE HERE
///          ↓
/// ├─ AuthRemoteDataSource (API calls)
/// ├─ AuthLocalDataSource (cache)
/// ├─ TokenManager (JWT lifecycle)
/// ├─ UserStorageService (persistent storage)
/// └─ BiometricService (platform auth)
/// ```
///
/// **Login Flow:**
/// ```
/// login(email, password)
///       ↓
/// AuthRemoteDataSource.login()
///       ↓
/// Extract tokens from response
///       ↓
/// TokenManager.storeToken()
///   ├─ Stores in secure storage
///   └─ Syncs with ApiClient
///       ↓
/// Cache user (local + persistent)
///   ├─ LocalDataSource.cacheUser()
///   └─ UserStorageService.saveUser()
///       ↓
/// Return Right(User)
/// ```
///
/// **Error Handling Flow:**
/// ```
/// Repository Method
///       ↓
/// try-catch block
///       ↓
/// Data Source throws Exception
///       ↓
/// Catch specific exception types
/// ├─ ServerException → ServerFailure
/// ├─ NetworkException → NetworkFailure
/// ├─ ValidationException → ValidationFailure
/// └─ Unknown → UnexpectedFailure
///       ↓
/// Return Left(Failure)
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Login
/// final result = await authRepository.login(
///   email: 'user@example.com',
///   password: 'password123',
/// );
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (user) {
///     print('Logged in as: ${user.email}');
///     navigateToHome();
///   },
/// );
///
/// // Check authentication
/// final isAuth = await authRepository.isAuthenticated();
/// if (!isAuth) navigateToLogin();
///
/// // Logout
/// await authRepository.logout();
/// ```
///
/// **Dependency Injection:**
/// - @LazySingleton: Single instance created on first use
/// - Injectable: Auto-registered with get_it service locator
/// - Constructor injection: All dependencies provided externally
///
/// **IMPROVEMENTS:**
/// - [High Priority] Add refresh token rotation on login
/// - Backend may issue new refresh token, need to handle
/// - [Medium Priority] Implement concurrent request deduplication
/// - Multiple getCurrentUser() calls should share single API request
/// - [Medium Priority] Add offline-first authentication strategy
/// - Allow login to succeed with cached credentials when offline
/// - [Low Priority] Add authentication events stream
/// - Notify app-wide when auth state changes
/// - [Low Priority] Implement automatic token refresh on 401 errors
/// - Currently handled by TokenManager, could be more robust
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  /// Remote data source for API authentication calls
  final AuthRemoteDataSource remoteDataSource;

  /// Local data source for temporary user caching
  final AuthLocalDataSource localDataSource;

  /// Biometric authentication service
  final BiometricService biometricService;

  /// Token lifecycle manager
  final TokenManager tokenManager;

  /// Persistent secure storage for user data
  ///
  /// **Why late final:**
  /// - Initialized in constructor with optional storage override
  /// - Allows testing with mock storage
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

  /// Authenticates user with email and password
  ///
  /// **What it does:**
  /// 1. Calls backend login API via remote data source
  /// 2. Extracts access and refresh tokens from response
  /// 3. Creates JwtToken entity with default 15-minute expiry
  /// 4. Stores token via TokenManager (syncs with ApiClient)
  /// 5. Caches user in local storage (temporary)
  /// 6. Persists user in secure storage (permanent)
  /// 7. Returns authenticated User entity
  ///
  /// **Why multiple storage layers:**
  /// - LocalDataSource: Fast in-memory cache for session
  /// - UserStorageService: Encrypted persistent storage across restarts
  /// - TokenManager: Secure token storage with auto-refresh
  ///
  /// **Flow Diagram:**
  /// ```
  /// login(email, password)
  ///       ↓
  /// POST /auth/login
  ///       ↓
  /// Extract tokens from UserModel
  ///       ↓
  /// Create JwtToken entity
  ///       ↓
  /// TokenManager.storeToken()
  ///   ├─ Store in secure storage
  ///   ├─ Sync with ApiClient
  ///   └─ Schedule auto-refresh
  ///       ↓
  /// LocalDataSource.cacheUser()
  ///       ↓
  /// UserStorageService.saveUser()
  ///       ↓
  /// Return Right(User)
  /// ```
  ///
  /// **Returns:**
  /// - Right(User): Successfully authenticated user
  /// - Left(ServerFailure): Backend error (invalid credentials, server down)
  /// - Left(NetworkFailure): No internet connection
  /// - Left(UnexpectedFailure): Unknown error
  ///
  /// **Edge Cases:**
  /// - Invalid credentials → ServerException → ServerFailure
  /// - Network timeout → NetworkException → NetworkFailure
  /// - Token storage fails → CacheFailure (but user still logged in remotely)
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.login(
  ///   email: 'driver@example.com',
  ///   password: 'SecurePass123!',
  /// );
  ///
  /// result.fold(
  ///   (failure) {
  ///     if (failure is ServerFailure) {
  ///       showError('Invalid email or password');
  ///     } else if (failure is NetworkFailure) {
  ///       showError('No internet connection');
  ///     }
  ///   },
  ///   (user) {
  ///     print('Logged in: ${user.email}');
  ///     print('Role: ${user.role.type}');
  ///     navigateToHome();
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Extract token expiry from backend response
  /// - Currently hardcoded 15 minutes, should use server value
  /// - [Medium Priority] Add login attempt rate limiting
  /// - Prevent brute force attacks
  /// - [Low Priority] Add device fingerprinting for security
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

  /// Retrieves current authenticated user with multi-layer caching
  ///
  /// **What it does:**
  /// 1. Checks persistent storage first (fastest)
  /// 2. Validates session expiration (30-day default)
  /// 3. Falls back to local cache if persistent storage empty
  /// 4. Falls back to remote API if both caches empty
  /// 5. Updates both caches with fresh data
  /// 6. Returns User entity or failure
  ///
  /// **Why multi-layer caching:**
  /// - Persistent storage: Survives app restarts
  /// - Local cache: Faster than persistent storage
  /// - Remote API: Source of truth when caches miss
  /// - Offline capability: Works without network if cached
  ///
  /// **Flow Diagram:**
  /// ```
  /// getCurrentUser()
  ///       ↓
  /// Check persistent storage
  ///   ↙           ↘
  /// Found        Not found
  ///   ↓             ↓
  /// Expired?    Check local cache
  ///  ↙    ↘       ↙        ↘
  /// YES  NO    Found    Not found
  ///  ↓    ↓      ↓          ↓
  /// Clear Return Persist   Fetch from API
  /// cache  user  & return      ↓
  ///  ↓                     Cache & return
  /// Failure
  /// ```
  ///
  /// **Session Validation:**
  /// - Checks if 30 days passed since last login
  /// - Expired session → Clears data, returns AuthenticationFailure
  /// - Forces user to re-authenticate
  ///
  /// **Returns:**
  /// - Right(User): Current authenticated user
  /// - Left(AuthenticationFailure): Session expired or not logged in
  /// - Left(ServerFailure): API error when fetching fresh data
  /// - Left(NetworkFailure): No internet (but may return cached user)
  /// - Left(UnexpectedFailure): Unknown error
  ///
  /// **Edge Cases:**
  /// - No cached user, no network → NetworkFailure
  /// - Cached user, network error → Returns cached user (graceful degradation)
  /// - Session expired → Clears cache, returns AuthenticationFailure
  /// - Fresh user from API → Updates both caches
  ///
  /// **Example:**
  /// ```dart
  /// // On app launch
  /// final result = await authRepository.getCurrentUser();
  /// result.fold(
  ///   (failure) {
  ///     if (failure is AuthenticationFailure) {
  ///       // Session expired or not logged in
  ///       navigateToLogin();
  ///     } else {
  ///       // Network error, show offline mode
  ///       showOfflineWarning();
  ///     }
  ///   },
  ///   (user) {
  ///     print('Welcome back, ${user.firstName}!');
  ///     initializeUserSession(user);
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add background refresh of user data
  /// - Currently only refreshes on explicit call
  /// - [Medium Priority] Implement stale-while-revalidate pattern
  /// - Return cached data immediately, fetch fresh in background
  /// - [Low Priority] Add user data versioning
  /// - Detect when server user model has changed
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
