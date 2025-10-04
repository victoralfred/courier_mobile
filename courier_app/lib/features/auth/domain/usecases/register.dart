import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/utils/validators.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';

/// [Register] - Use case for creating new user accounts (registration)
///
/// **What it does:**
/// - Validates user registration data (name, email, phone, password, role)
/// - Ensures all required fields are provided
/// - Validates email and phone formats
/// - Delegates account creation to AuthRepository
/// - Returns newly created User or Failure
/// - Automatically logs in user after successful registration
///
/// **Why it exists:**
/// - Encapsulates registration business logic in one place
/// - Separates validation from presentation layer (BLoC)
/// - Separates business rules from data layer (Repository)
/// - Makes registration logic reusable across app
/// - Enables testing business logic in isolation
/// - Follows Single Responsibility Principle
///
/// **Validation Flow:**
/// ```
/// RegisterParams (firstName, lastName, email, phone, password, role)
///       ↓
/// Validate firstName not empty
///       ↓
/// Validate lastName not empty
///       ↓
/// Validate email not empty + valid format
///       ↓
/// Validate phone not empty + valid format
///       ↓
/// Validate password not empty + min 8 chars
///       ↓
/// Call repository.register()
///       ↓
/// Return Either<Failure, User>
/// ```
///
/// **Clean Architecture Layer:**
/// ```
/// Presentation (RegistrationBloc)
///       ↓
/// Domain (Register UseCase) ← YOU ARE HERE
///       ↓
/// Domain (AuthRepository interface)
///       ↓
/// Data (AuthRepositoryImpl)
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In BLoC or presentation layer
/// class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
///   final Register registerUseCase;
///
///   Future<void> _onRegistrationSubmitted(RegistrationSubmitted event) async {
///     emit(RegistrationLoading());
///
///     final params = RegisterParams(
///       firstName: event.firstName,
///       lastName: event.lastName,
///       email: event.email,
///       phone: event.phone,
///       password: event.password,
///       role: event.role,
///     );
///
///     final result = await registerUseCase(params);
///
///     result.fold(
///       (failure) => emit(RegistrationError(failure.message)),
///       (user) => emit(RegistrationSuccess(user)),
///     );
///   }
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add password confirmation validation (password == confirmPassword)
/// - [Medium Priority] Add email uniqueness check before submission (pre-validation)
/// - [Medium Priority] Add password complexity validation (uppercase, numbers, symbols)
/// - [Low Priority] Add terms and conditions acceptance validation
/// - [Low Priority] Add referral code support
class Register {
  /// Authentication repository for performing registration
  ///
  /// **Why injected:**
  /// - Dependency inversion (depend on interface, not implementation)
  /// - Enables testing with mock repository
  /// - Supports different registration flows (email, social, OAuth)
  final AuthRepository repository;

  /// Creates Register use case
  ///
  /// **Parameters:**
  /// - [repository]: AuthRepository implementation for registration
  ///
  /// **Example:**
  /// ```dart
  /// final registerUseCase = Register(authRepository);
  /// ```
  Register(this.repository);

  /// Executes registration use case with comprehensive validation
  ///
  /// **What it does:**
  /// 1. Validates all required fields are not empty
  /// 2. Validates email format (via Validators.isValidEmail)
  /// 3. Validates phone format (via Validators.isValidPhone)
  /// 4. Validates password minimum length (8 chars)
  /// 5. Calls repository.register() if all validation passes
  /// 6. Returns Either<Failure, User>
  ///
  /// **Validation Rules:**
  /// - First name: Required, not empty
  /// - Last name: Required, not empty
  /// - Email: Required, valid email format
  /// - Phone: Required, valid phone format
  /// - Password: Required, minimum 8 characters
  /// - Role: Required (driver or customer)
  ///
  /// **Parameters:**
  /// - [params]: RegisterParams containing all registration data
  ///
  /// **Returns:**
  /// - Right(User): Registration successful, user created and logged in
  /// - Left(ValidationFailure): Invalid input (empty field, invalid format, etc.)
  /// - Left(ServerFailure): Email already exists, server error
  /// - Left(NetworkFailure): Network error
  ///
  /// **Error Examples:**
  /// ```dart
  /// // Empty first name
  /// RegisterParams(firstName: '', ...)
  /// → Left(ValidationFailure('First name is required'))
  ///
  /// // Invalid email
  /// RegisterParams(email: 'not-an-email', ...)
  /// → Left(ValidationFailure('Invalid email format'))
  ///
  /// // Password too short
  /// RegisterParams(password: 'pass', ...)
  /// → Left(ValidationFailure('Password must be at least 8 characters'))
  ///
  /// // Email already exists
  /// RegisterParams(email: 'existing@example.com', ...)
  /// → Left(ServerFailure('Email already registered'))
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// final params = RegisterParams(
  ///   firstName: 'John',
  ///   lastName: 'Doe',
  ///   email: 'john@example.com',
  ///   phone: '+1234567890',
  ///   password: 'SecurePass123',
  ///   role: 'driver',
  /// );
  ///
  /// final result = await registerUseCase(params);
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (user) => navigateToHome(user),
  /// );
  /// ```
  Future<Either<Failure, User>> call(RegisterParams params) async {
    // Validate inputs
    if (params.firstName.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.validationFirstNameRequired));
    }

    if (params.lastName.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.validationLastNameRequired));
    }

    if (params.email.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.validationEmailRequired));
    }

    if (!Validators.isValidEmail(params.email)) {
      return const Left(
          ValidationFailure(message: AppStrings.validationInvalidEmailFormat));
    }

    if (params.phone.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.validationPhoneRequired));
    }

    if (!Validators.isValidPhone(params.phone)) {
      return const Left(
          ValidationFailure(message: AppStrings.validationInvalidPhoneFormat));
    }

    if (params.password.isEmpty) {
      return const Left(
          ValidationFailure(message: AppStrings.validationPasswordRequired));
    }

    if (params.password.length < 8) {
      return const Left(
          ValidationFailure(message: AppStrings.validationPasswordTooShort));
    }

    // Call repository to register
    return repository.register(
      firstName: params.firstName,
      lastName: params.lastName,
      email: params.email,
      phone: params.phone,
      password: params.password,
      role: params.role,
    );
  }
}

/// [RegisterParams] - Parameters for Register use case
///
/// **What it contains:**
/// - User's personal information (first name, last name)
/// - Contact information (email, phone)
/// - Authentication credentials (password)
/// - User role (driver or customer)
///
/// **Usage Example:**
/// ```dart
/// final params = RegisterParams(
///   firstName: 'John',
///   lastName: 'Doe',
///   email: 'john@example.com',
///   phone: '+1234567890',
///   password: 'SecurePass123',
///   role: 'driver',
/// );
///
/// final result = await registerUseCase(params);
/// ```
class RegisterParams {
  /// User's first name
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Will be trimmed and validated (2-50 chars) in User entity
  final String firstName;

  /// User's last name
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Will be trimmed and validated (2-50 chars) in User entity
  final String lastName;

  /// User's email address
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Must be valid email format (validated in Register use case)
  /// - Must be unique (validated by backend)
  final String email;

  /// User's phone number
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Must be valid phone format (validated in Register use case)
  /// - Recommended: E.164 format (e.g., +1234567890)
  final String phone;

  /// User's password
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Minimum 8 characters (validated in Register use case)
  ///
  /// **Security:**
  /// - Stored in memory only (not persisted)
  /// - Sent to backend over HTTPS (encrypted in transit)
  /// - Hashed by backend before storage
  /// - Never logged or displayed
  final String password;

  /// User's role in the system
  ///
  /// **Valid values:**
  /// - "driver": User will deliver orders
  /// - "customer": User will place orders
  ///
  /// **Validation:**
  /// - Required (validated in Register use case)
  /// - Must be either "driver" or "customer" (validated by backend)
  final String role;

  /// Creates registration parameters
  ///
  /// **Parameters:**
  /// - [firstName]: User's first name (required)
  /// - [lastName]: User's last name (required)
  /// - [email]: User's email address (required)
  /// - [phone]: User's phone number (required)
  /// - [password]: User's password (required, min 8 chars)
  /// - [role]: User's role - "driver" or "customer" (required)
  ///
  /// **Example:**
  /// ```dart
  /// final params = RegisterParams(
  ///   firstName: 'Jane',
  ///   lastName: 'Smith',
  ///   email: 'jane@example.com',
  ///   phone: '+9876543210',
  ///   password: 'MySecurePassword123',
  ///   role: 'customer',
  /// );
  /// ```
  RegisterParams({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });
}
