import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/usecases/usecase.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';

/// [Login] - Use case for authenticating users with email and password
///
/// **What it does:**
/// - Validates email format using Email value object
/// - Validates password length (min 8 characters)
/// - Delegates authentication to AuthRepository
/// - Returns authenticated User or Failure
/// - Implements UseCase pattern from Clean Architecture
///
/// **Why it exists:**
/// - Encapsulates login business logic in one place
/// - Separates validation from presentation layer (BLoC)
/// - Separates business rules from data layer (Repository)
/// - Makes login logic reusable across app
/// - Enables testing business logic in isolation
/// - Follows Single Responsibility Principle
///
/// **Validation Flow:**
/// ```
/// LoginParams (email, password)
///       ↓
/// Validate email format (Email value object)
///       ↓
/// Validate password not empty
///       ↓
/// Validate password min 8 characters
///       ↓
/// Call repository.login()
///       ↓
/// Return Either<Failure, User>
/// ```
///
/// **Clean Architecture Layer:**
/// ```
/// Presentation (BLoC)
///       ↓
/// Domain (Login UseCase) ← YOU ARE HERE
///       ↓
/// Domain (AuthRepository interface)
///       ↓
/// Data (AuthRepositoryImpl)
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In BLoC or presentation layer
/// class LoginBloc extends Bloc<LoginEvent, LoginState> {
///   final Login loginUseCase;
///
///   Future<void> _onLoginSubmitted(LoginSubmitted event) async {
///     emit(LoginLoading());
///
///     final params = LoginParams(
///       email: event.email,
///       password: event.password,
///     );
///
///     final result = await loginUseCase(params);
///
///     result.fold(
///       (failure) => emit(LoginError(failure.message)),
///       (user) => emit(LoginSuccess(user)),
///     );
///   }
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add password complexity validation (uppercase, numbers, symbols)
/// - [Medium Priority] Add rate limiting (prevent brute force)
/// - [Low Priority] Add remember me functionality
class Login implements UseCase<User, LoginParams> {
  /// Authentication repository for performing login
  ///
  /// **Why injected:**
  /// - Dependency inversion (depend on interface, not implementation)
  /// - Enables testing with mock repository
  /// - Supports different auth implementations (OAuth, biometric, etc.)
  final AuthRepository repository;

  /// Creates Login use case
  ///
  /// **Parameters:**
  /// - [repository]: AuthRepository implementation for login
  ///
  /// **Example:**
  /// ```dart
  /// final loginUseCase = Login(authRepository);
  /// ```
  Login(this.repository);

  /// Executes login use case with validation
  ///
  /// **What it does:**
  /// 1. Validates email format (via Email value object)
  /// 2. Validates password not empty
  /// 3. Validates password minimum length (8 chars)
  /// 4. Calls repository.login() if validation passes
  /// 5. Returns Either<Failure, User>
  ///
  /// **Validation Rules:**
  /// - Email must be valid format (checked by Email value object)
  /// - Password must not be empty
  /// - Password must be at least 8 characters
  ///
  /// **Parameters:**
  /// - [params]: LoginParams containing email and password
  ///
  /// **Returns:**
  /// - Right(User): Login successful, user authenticated
  /// - Left(ValidationFailure): Invalid email or password format
  /// - Left(AuthFailure): Invalid credentials (from repository)
  /// - Left(NetworkFailure): Network error (from repository)
  /// - Left(ServerFailure): Server error (from repository)
  ///
  /// **Error Examples:**
  /// ```dart
  /// // Invalid email
  /// LoginParams(email: 'not-an-email', password: 'pass123')
  /// → Left(ValidationFailure('Invalid email format'))
  ///
  /// // Password too short
  /// LoginParams(email: 'user@example.com', password: 'pass')
  /// → Left(ValidationFailure('Password must be at least 8 characters'))
  ///
  /// // Wrong credentials
  /// LoginParams(email: 'user@example.com', password: 'wrongpass')
  /// → Left(AuthFailure('Invalid email or password'))
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// final params = LoginParams(
  ///   email: 'john@example.com',
  ///   password: 'SecurePass123',
  /// );
  ///
  /// final result = await loginUseCase(params);
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (user) => navigateToHome(user),
  /// );
  /// ```
  @override
  Future<Either<Failure, User>> call(LoginParams params) async {
    // Validate email format
    try {
      Email(params.email); // This will throw if invalid
    } catch (e) {
      return Left(ValidationFailure(
        message: AppStrings.format(
            AppStrings.errorInvalidEmailFormat, {'email': params.email}),
      ));
    }

    // Validate password
    if (params.password.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.errorFieldRequired));
    }

    if (params.password.length < 8) {
      return const Left(
          ValidationFailure(message: AppStrings.errorPasswordTooShort));
    }

    // Perform login
    return repository.login(
      email: params.email,
      password: params.password,
    );
  }
}

/// [LoginParams] - Parameters for Login use case
///
/// **What it contains:**
/// - Email address for authentication
/// - Password for authentication
///
/// **Why Equatable:**
/// - Enables value comparison (params1 == params2)
/// - Used in BLoC state management (detect param changes)
/// - Prevents unnecessary rebuilds in UI
///
/// **Usage Example:**
/// ```dart
/// const params = LoginParams(
///   email: 'user@example.com',
///   password: 'SecurePass123',
/// );
///
/// // Equatable enables comparison
/// const params2 = LoginParams(
///   email: 'user@example.com',
///   password: 'SecurePass123',
/// );
/// print(params == params2); // true (same values)
/// ```
class LoginParams extends Equatable {
  /// User's email address
  ///
  /// **Validation:**
  /// - Validated in Login use case (not here)
  /// - Must be valid email format
  final String email;

  /// User's password
  ///
  /// **Validation:**
  /// - Validated in Login use case (not here)
  /// - Must be at least 8 characters
  ///
  /// **Security:**
  /// - Stored in memory only (not persisted)
  /// - Sent to backend over HTTPS (encrypted in transit)
  /// - Never logged or displayed
  final String password;

  /// Creates login parameters
  ///
  /// **Parameters:**
  /// - [email]: User's email address (required)
  /// - [password]: User's password (required)
  ///
  /// **Example:**
  /// ```dart
  /// const params = LoginParams(
  ///   email: 'john@example.com',
  ///   password: 'MySecurePassword123',
  /// );
  /// ```
  const LoginParams({
    required this.email,
    required this.password,
  });

  /// Equatable props for value comparison
  ///
  /// **Why both email and password:**
  /// - Two LoginParams are equal if both email AND password match
  /// - Used by Equatable for == operator and hashCode
  @override
  List<Object> get props => [email, password];
}
