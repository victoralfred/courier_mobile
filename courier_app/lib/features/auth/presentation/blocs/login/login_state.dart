import 'package:equatable/equatable.dart';
import '../../../domain/entities/user.dart';

class LoginState extends Equatable {
  final String email;
  final String password;
  final bool isPasswordVisible;
  final LoginStatus status;
  final String? emailError;
  final String? passwordError;
  final String? generalError;
  final User? user;
  final bool canSubmit;
  final bool isBiometricAvailable;
  final bool isLoading;

  const LoginState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.status = LoginStatus.initial,
    this.emailError,
    this.passwordError,
    this.generalError,
    this.user,
    this.canSubmit = false,
    this.isBiometricAvailable = false,
    this.isLoading = false,
  });

  LoginState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    LoginStatus? status,
    String? Function()? emailError,
    String? Function()? passwordError,
    String? Function()? generalError,
    User? Function()? user,
    bool? canSubmit,
    bool? isBiometricAvailable,
    bool? isLoading,
  }) =>
      LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
        isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
        status: status ?? this.status,
        emailError: emailError != null ? emailError() : this.emailError,
        passwordError:
            passwordError != null ? passwordError() : this.passwordError,
        generalError: generalError != null ? generalError() : this.generalError,
        user: user != null ? user() : this.user,
        canSubmit: canSubmit ?? this.canSubmit,
        isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [
        email,
        password,
        isPasswordVisible,
        status,
        emailError,
        passwordError,
        generalError,
        user,
        canSubmit,
        isBiometricAvailable,
        isLoading,
      ];
}

enum LoginStatus {
  initial,
  loading,
  success,
  failure,
}
