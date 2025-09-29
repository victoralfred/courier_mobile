import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/utils/validators.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';

/// Use case for user registration
class Register {
  final AuthRepository repository;

  Register(this.repository);

  /// Executes the registration use case
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

/// Parameters for the Register use case
class RegisterParams {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String role;

  RegisterParams({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });
}
