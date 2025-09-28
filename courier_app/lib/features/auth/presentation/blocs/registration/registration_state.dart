import 'package:equatable/equatable.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_role.dart';

class RegistrationState extends Equatable {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;
  final UserRoleType? selectedRole;
  final bool termsAccepted;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final RegistrationStatus status;
  final String? firstNameError;
  final String? lastNameError;
  final String? emailError;
  final String? phoneError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String? generalError;
  final User? user;
  final bool canSubmit;
  final bool isLoading;
  final int passwordStrength;

  const RegistrationState({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.confirmPassword = '',
    this.selectedRole,
    this.termsAccepted = false,
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.status = RegistrationStatus.initial,
    this.firstNameError,
    this.lastNameError,
    this.emailError,
    this.phoneError,
    this.passwordError,
    this.confirmPasswordError,
    this.generalError,
    this.user,
    this.canSubmit = false,
    this.isLoading = false,
    this.passwordStrength = 0,
  });

  RegistrationState copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? password,
    String? confirmPassword,
    UserRoleType? Function()? selectedRole,
    bool? termsAccepted,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    RegistrationStatus? status,
    String? Function()? firstNameError,
    String? Function()? lastNameError,
    String? Function()? emailError,
    String? Function()? phoneError,
    String? Function()? passwordError,
    String? Function()? confirmPasswordError,
    String? Function()? generalError,
    User? Function()? user,
    bool? canSubmit,
    bool? isLoading,
    int? passwordStrength,
  }) {
    return RegistrationState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      selectedRole: selectedRole != null ? selectedRole() : this.selectedRole,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible: isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      status: status ?? this.status,
      firstNameError: firstNameError != null ? firstNameError() : this.firstNameError,
      lastNameError: lastNameError != null ? lastNameError() : this.lastNameError,
      emailError: emailError != null ? emailError() : this.emailError,
      phoneError: phoneError != null ? phoneError() : this.phoneError,
      passwordError: passwordError != null ? passwordError() : this.passwordError,
      confirmPasswordError: confirmPasswordError != null ? confirmPasswordError() : this.confirmPasswordError,
      generalError: generalError != null ? generalError() : this.generalError,
      user: user != null ? user() : this.user,
      canSubmit: canSubmit ?? this.canSubmit,
      isLoading: isLoading ?? this.isLoading,
      passwordStrength: passwordStrength ?? this.passwordStrength,
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        email,
        phone,
        password,
        confirmPassword,
        selectedRole,
        termsAccepted,
        isPasswordVisible,
        isConfirmPasswordVisible,
        status,
        firstNameError,
        lastNameError,
        emailError,
        phoneError,
        passwordError,
        confirmPasswordError,
        generalError,
        user,
        canSubmit,
        isLoading,
        passwordStrength,
      ];
}

enum RegistrationStatus {
  initial,
  loading,
  success,
  failure,
}