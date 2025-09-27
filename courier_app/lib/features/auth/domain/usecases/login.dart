import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/usecases/usecase.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';

/// Use case for user login
class Login implements UseCase<User, LoginParams> {
  final AuthRepository repository;

  Login(this.repository);

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

/// Parameters for the Login use case
class LoginParams extends Equatable {
  final String email;
  final String password;

  const LoginParams({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}
