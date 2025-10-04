import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';

/// [AuthRepository] - Repository interface defining authentication contracts
///
/// **What it does:**
/// - Defines authentication operations (login, register, logout)
/// - Provides user profile management methods
/// - Supports biometric authentication
/// - Handles password reset and email verification
/// - Returns Either<Failure, T> for error handling
/// - Abstracts authentication data sources (remote API, local storage)
///
/// **Why it exists:**
/// - Separates domain logic from data layer (Clean Architecture)
/// - Enables dependency inversion (depend on interface, not implementation)
/// - Makes authentication testable (mock repository in tests)
/// - Centralizes authentication contracts in one place
/// - Supports multiple implementations (OAuth, email/password, biometric)
/// - Enables offline-first authentication (local token validation)
///
/// **Architecture:**
/// ```
/// Domain Layer (this interface)
///      ↑
///      │ depends on
///      │
/// Data Layer (AuthRepositoryImpl)
///      ↓
/// Data Sources (Remote API + Local Storage)
/// ```
///
/// **Error Handling Pattern:**
/// - Uses Either<Failure, T> from dartz package
/// - Left: Failure (NetworkFailure, ServerFailure, AuthFailure, etc.)
/// - Right: Success value (User, bool, etc.)
/// - Forces explicit error handling in use cases and BLoCs
///
/// **Usage Example:**
/// ```dart
/// // In use case
/// class LoginUseCase {
///   final AuthRepository repository;
///
///   Future<Either<Failure, User>> call(String email, String password) {
///     return repository.login(email: email, password: password);
///   }
/// }
///
/// // In BLoC
/// final result = await loginUseCase(email, password);
/// result.fold(
///   (failure) => emit(LoginError(failure.message)),
///   (user) => emit(LoginSuccess(user)),
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add refresh token method
/// - [Medium Priority] Add multi-factor authentication (MFA) support
/// - [Medium Priority] Add social login methods (Google, Apple, Facebook)
/// - [Low Priority] Add account deletion method
/// - [Low Priority] Add session management (list active sessions, revoke)
abstract class AuthRepository {
  /// Authenticates user with email and password
  ///
  /// **What it does:**
  /// - Validates credentials against backend
  /// - Stores access/refresh tokens locally
  /// - Fetches user profile data
  /// - Returns authenticated User entity
  ///
  /// **Flow:**
  /// ```
  /// 1. POST /auth/login {email, password}
  /// 2. Receive {access_token, refresh_token, user}
  /// 3. Store tokens in secure storage
  /// 4. Return User entity
  /// ```
  ///
  /// **Parameters:**
  /// - [email]: User's email address
  /// - [password]: User's password (plaintext, encrypted in transit via HTTPS)
  ///
  /// **Returns:**
  /// - Right(User): Login successful, user authenticated
  /// - Left(AuthFailure): Invalid credentials
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Server error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.login(
  ///   email: 'user@example.com',
  ///   password: 'SecurePass123',
  /// );
  /// result.fold(
  ///   (failure) => print('Login failed: ${failure.message}'),
  ///   (user) => print('Logged in as ${user.fullName}'),
  /// );
  /// ```
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Registers a new user account
  ///
  /// **What it does:**
  /// - Creates new user account in backend
  /// - Validates email uniqueness
  /// - Hashes password (backend-side)
  /// - Automatically logs in user after registration
  /// - Returns newly created User entity
  ///
  /// **Flow:**
  /// ```
  /// 1. POST /auth/register {firstName, lastName, email, phone, password, role}
  /// 2. Backend validates email uniqueness
  /// 3. Backend creates user account
  /// 4. Receive {access_token, refresh_token, user}
  /// 5. Store tokens locally
  /// 6. Return User entity
  /// ```
  ///
  /// **Parameters:**
  /// - [firstName]: User's first name (2-50 chars)
  /// - [lastName]: User's last name (2-50 chars)
  /// - [email]: Unique email address
  /// - [phone]: Phone number (E.164 format recommended)
  /// - [password]: Password (min 8 chars, complexity rules enforced)
  /// - [role]: User role ("driver" or "customer")
  ///
  /// **Returns:**
  /// - Right(User): Registration successful, user logged in
  /// - Left(ValidationFailure): Invalid input (email format, password too short, etc.)
  /// - Left(ServerFailure): Email already exists, server error
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.register(
  ///   firstName: 'John',
  ///   lastName: 'Doe',
  ///   email: 'john@example.com',
  ///   phone: '+1234567890',
  ///   password: 'SecurePass123',
  ///   role: 'driver',
  /// );
  /// ```
  Future<Either<Failure, User>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String role,
  });

  /// Gets currently authenticated user profile
  ///
  /// **What it does:**
  /// - Fetches fresh user data from backend
  /// - Uses stored access token for authentication
  /// - Updates local user cache
  /// - Returns current User entity
  ///
  /// **When to use:**
  /// - App startup (check if user still authenticated)
  /// - Profile screen load (show latest data)
  /// - After profile update (fetch updated user)
  /// - Periodic refresh (ensure data is current)
  ///
  /// **Flow:**
  /// ```
  /// 1. GET /users/me (with Authorization: Bearer {token})
  /// 2. Receive user profile JSON
  /// 3. Convert to User entity
  /// 4. Cache locally
  /// 5. Return User
  /// ```
  ///
  /// **Returns:**
  /// - Right(User): User profile fetched successfully
  /// - Left(AuthFailure): Not authenticated (401)
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Server error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.getCurrentUser();
  /// result.fold(
  ///   (failure) => navigateToLogin(),
  ///   (user) => showProfile(user),
  /// );
  /// ```
  Future<Either<Failure, User>> getCurrentUser();

  /// Logs out the current user
  ///
  /// **What it does:**
  /// - Invalidates tokens on backend (optional)
  /// - Clears access/refresh tokens from local storage
  /// - Clears user data cache
  /// - Resets authentication state
  ///
  /// **Flow:**
  /// ```
  /// 1. POST /auth/logout (optional - invalidate server-side session)
  /// 2. Delete local tokens from secure storage
  /// 3. Clear cached user data
  /// 4. Return success
  /// ```
  ///
  /// **Returns:**
  /// - Right(true): Logout successful
  /// - Left(NetworkFailure): Network error (still logs out locally)
  /// - Left(ServerFailure): Server error (still logs out locally)
  ///
  /// **Note:** Logout succeeds locally even if backend call fails
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.logout();
  /// result.fold(
  ///   (failure) => print('Logout error (still logged out locally)'),
  ///   (_) => navigateToLogin(),
  /// );
  /// ```
  Future<Either<Failure, bool>> logout();

  /// Checks if user is currently authenticated
  ///
  /// **What it does:**
  /// - Checks if access token exists in local storage
  /// - Optionally validates token expiration
  /// - Does NOT make network request
  ///
  /// **Returns:** true if access token exists and valid, false otherwise
  ///
  /// **Use cases:**
  /// - Route guarding (redirect to login if false)
  /// - Conditional UI rendering
  /// - App initialization (determine initial route)
  ///
  /// **Example:**
  /// ```dart
  /// final isAuth = await authRepository.isAuthenticated();
  /// if (isAuth) {
  ///   navigateToHome();
  /// } else {
  ///   navigateToLogin();
  /// }
  /// ```
  Future<bool> isAuthenticated();

  /// Gets current JWT access token
  ///
  /// **What it does:**
  /// - Retrieves access token from secure storage
  /// - Returns raw JWT string
  /// - Does NOT validate token expiration
  ///
  /// **Returns:** JWT token string or null if not authenticated
  ///
  /// **Use cases:**
  /// - Manual API calls (outside repository pattern)
  /// - WebSocket authentication
  /// - Third-party integrations
  ///
  /// **Example:**
  /// ```dart
  /// final token = await authRepository.getAccessToken();
  /// if (token != null) {
  ///   webSocket.connect(authToken: token);
  /// }
  /// ```
  Future<String?> getAccessToken();

  /// Updates current user profile information
  ///
  /// **What it does:**
  /// - Sends profile updates to backend
  /// - Validates new data (name length, phone format)
  /// - Returns updated User entity
  /// - Updates local user cache
  ///
  /// **Flow:**
  /// ```
  /// 1. PATCH /users/me {firstName?, lastName?, phone?}
  /// 2. Backend validates and updates
  /// 3. Receive updated user JSON
  /// 4. Update local cache
  /// 5. Return User
  /// ```
  ///
  /// **Parameters:** All optional (only update provided fields)
  /// - [firstName]: New first name (2-50 chars)
  /// - [lastName]: New last name (2-50 chars)
  /// - [phone]: New phone number
  ///
  /// **Returns:**
  /// - Right(User): Profile updated successfully
  /// - Left(ValidationFailure): Invalid input
  /// - Left(AuthFailure): Not authenticated
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.updateProfile(
  ///   firstName: 'Jane',
  ///   phone: '+9876543210',
  /// );
  /// ```
  Future<Either<Failure, User>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  });

  /// Sends password reset email to user
  ///
  /// **What it does:**
  /// - Validates email exists in system
  /// - Generates password reset token
  /// - Sends email with reset link
  /// - Returns success (even if email doesn't exist - security)
  ///
  /// **Flow:**
  /// ```
  /// 1. POST /auth/password-reset {email}
  /// 2. Backend checks if email exists
  /// 3. Generate reset token (expires in 1 hour)
  /// 4. Send email with reset link
  /// 5. Return success (always, even if email not found)
  /// ```
  ///
  /// **Parameters:**
  /// - [email]: Email address to send reset link
  ///
  /// **Returns:**
  /// - Right(true): Email sent (or email doesn't exist - security measure)
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Server error
  ///
  /// **Security Note:** Always returns success to prevent email enumeration
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.sendPasswordResetEmail('user@example.com');
  /// result.fold(
  ///   (failure) => showError('Failed to send email'),
  ///   (_) => showMessage('Check your email for reset link'),
  /// );
  /// ```
  Future<Either<Failure, bool>> sendPasswordResetEmail(String email);

  /// Verifies user's email address with verification code
  ///
  /// **What it does:**
  /// - Validates verification code from email
  /// - Marks email as verified in backend
  /// - Updates user status
  ///
  /// **Parameters:**
  /// - [verificationCode]: Code from verification email
  ///
  /// **Returns:**
  /// - Right(true): Email verified successfully
  /// - Left(ValidationFailure): Invalid or expired code
  /// - Left(AuthFailure): Not authenticated
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.verifyEmail('ABC123');
  /// ```
  Future<Either<Failure, bool>> verifyEmail(String verificationCode);

  /// Changes user's password
  ///
  /// **What it does:**
  /// - Validates current password
  /// - Validates new password complexity
  /// - Updates password in backend
  /// - Invalidates old tokens (force re-login)
  ///
  /// **Parameters:**
  /// - [currentPassword]: Current password for verification
  /// - [newPassword]: New password (min 8 chars, complexity rules)
  ///
  /// **Returns:**
  /// - Right(true): Password changed successfully
  /// - Left(AuthFailure): Current password incorrect
  /// - Left(ValidationFailure): New password too weak
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.changePassword(
  ///   currentPassword: 'OldPass123',
  ///   newPassword: 'NewSecurePass456',
  /// );
  /// ```
  Future<Either<Failure, bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Authenticates using biometric credentials (Face ID, Touch ID, Fingerprint)
  ///
  /// **What it does:**
  /// - Prompts biometric authentication (OS-level)
  /// - Retrieves stored credentials from secure enclave
  /// - Automatically logs in user
  /// - Returns authenticated User entity
  ///
  /// **Flow:**
  /// ```
  /// 1. Prompt biometric (OS dialog)
  /// 2. Retrieve stored email/token from secure storage
  /// 3. Login with stored credentials
  /// 4. Return User
  /// ```
  ///
  /// **Returns:**
  /// - Right(User): Biometric login successful
  /// - Left(AuthFailure): Biometric not enrolled or authentication failed
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.loginWithBiometric();
  /// ```
  Future<Either<Failure, User>> loginWithBiometric();

  /// Enables biometric authentication for current user
  ///
  /// **What it does:**
  /// - Prompts biometric enrollment (OS-level)
  /// - Stores credentials in secure enclave (Keychain/Keystore)
  /// - Marks biometric as enabled for user
  ///
  /// **Returns:**
  /// - Right(true): Biometric enabled successfully
  /// - Left(AuthFailure): Biometric not available on device
  /// - Left(AuthFailure): User cancelled enrollment
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.enableBiometric();
  /// ```
  Future<Either<Failure, bool>> enableBiometric();

  /// Disables biometric authentication for current user
  ///
  /// **What it does:**
  /// - Deletes stored credentials from secure enclave
  /// - Marks biometric as disabled for user
  ///
  /// **Returns:**
  /// - Right(true): Biometric disabled successfully
  ///
  /// **Example:**
  /// ```dart
  /// final result = await authRepository.disableBiometric();
  /// ```
  Future<Either<Failure, bool>> disableBiometric();

  /// Checks if biometric authentication is enabled for current user
  ///
  /// **What it does:**
  /// - Checks if credentials stored in secure enclave
  /// - Checks if biometric hardware available
  ///
  /// **Returns:** true if biometric enabled, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// final isEnabled = await authRepository.isBiometricEnabled();
  /// if (isEnabled) {
  ///   showBiometricLoginButton();
  /// }
  /// ```
  Future<bool> isBiometricEnabled();
}