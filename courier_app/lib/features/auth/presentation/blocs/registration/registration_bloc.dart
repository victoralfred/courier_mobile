import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/utils/validators.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/features/auth/domain/usecases/register.dart';
import 'registration_event.dart';
import 'registration_state.dart';

class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  final AuthRepository authRepository;
  final Register registerUseCase;

  RegistrationBloc({
    required this.authRepository,
    required this.registerUseCase,
  }) : super(const RegistrationState()) {
    on<RegistrationFirstNameChanged>(_onFirstNameChanged);
    on<RegistrationLastNameChanged>(_onLastNameChanged);
    on<RegistrationEmailChanged>(_onEmailChanged);
    on<RegistrationPhoneChanged>(_onPhoneChanged);
    on<RegistrationPasswordChanged>(_onPasswordChanged);
    on<RegistrationConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<RegistrationRoleSelected>(_onRoleSelected);
    on<RegistrationPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<RegistrationConfirmPasswordVisibilityToggled>(_onConfirmPasswordVisibilityToggled);
    on<RegistrationTermsAccepted>(_onTermsAccepted);
    on<RegistrationSubmitted>(_onSubmitted);
  }

  Future<void> _onFirstNameChanged(
    RegistrationFirstNameChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final firstName = event.firstName;
    String? error;

    if (firstName.isNotEmpty && !Validators.isValidName(firstName)) {
      error = AppStrings.errorFirstNameTooShort;
    }

    emit(state.copyWith(
      firstName: firstName,
      firstNameError: () => error,
      canSubmit: _canSubmit(
        firstName: firstName,
        firstNameError: error,
      ),
    ));
  }

  Future<void> _onLastNameChanged(
    RegistrationLastNameChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final lastName = event.lastName;
    String? error;

    if (lastName.isNotEmpty && !Validators.isValidName(lastName)) {
      error = AppStrings.errorLastNameTooShort;
    }

    emit(state.copyWith(
      lastName: lastName,
      lastNameError: () => error,
      canSubmit: _canSubmit(
        lastName: lastName,
        lastNameError: error,
      ),
    ));
  }

  Future<void> _onEmailChanged(
    RegistrationEmailChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final email = event.email;
    String? error;

    if (email.isNotEmpty && !Validators.isValidEmail(email)) {
      error = AppStrings.errorInvalidEmail;
    }

    emit(state.copyWith(
      email: email,
      emailError: () => error,
      canSubmit: _canSubmit(
        email: email,
        emailError: error,
      ),
    ));
  }

  Future<void> _onPhoneChanged(
    RegistrationPhoneChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final phone = event.phone;
    String? error;

    if (phone.isNotEmpty && !Validators.isValidNigerianPhone(phone)) {
      error = AppStrings.errorPhoneInvalid;
    }

    emit(state.copyWith(
      phone: phone,
      phoneError: () => error,
      canSubmit: _canSubmit(
        phone: phone,
        phoneError: error,
      ),
    ));
  }

  Future<void> _onPasswordChanged(
    RegistrationPasswordChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final password = event.password;
    String? passwordError;
    String? confirmPasswordError;
    int strength = 0;

    if (password.isNotEmpty) {
      strength = Validators.getPasswordStrength(password);

      if (password.length < 8) {
        passwordError = AppStrings.errorPasswordTooShort;
      } else if (strength < 2) {
        passwordError = AppStrings.errorPasswordWeak;
      }
    }

    // Check if confirm password still matches
    if (state.confirmPassword.isNotEmpty && password != state.confirmPassword) {
      confirmPasswordError = AppStrings.errorPasswordMismatch;
    }

    emit(state.copyWith(
      password: password,
      passwordError: () => passwordError,
      confirmPasswordError: () => confirmPasswordError,
      passwordStrength: strength,
      canSubmit: _canSubmit(
        password: password,
        confirmPassword: state.confirmPassword,
        passwordError: passwordError,
        confirmPasswordError: confirmPasswordError,
      ),
    ));
  }

  Future<void> _onConfirmPasswordChanged(
    RegistrationConfirmPasswordChanged event,
    Emitter<RegistrationState> emit,
  ) async {
    final confirmPassword = event.confirmPassword;
    String? error;

    if (confirmPassword.isNotEmpty && confirmPassword != state.password) {
      error = AppStrings.errorPasswordMismatch;
    }

    emit(state.copyWith(
      confirmPassword: confirmPassword,
      confirmPasswordError: () => error,
      canSubmit: _canSubmit(
        confirmPassword: confirmPassword,
        confirmPasswordError: error,
      ),
    ));
  }

  Future<void> _onRoleSelected(
    RegistrationRoleSelected event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      selectedRole: () => event.role,
      canSubmit: _canSubmit(selectedRole: event.role),
    ));
  }

  Future<void> _onPasswordVisibilityToggled(
    RegistrationPasswordVisibilityToggled event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  Future<void> _onConfirmPasswordVisibilityToggled(
    RegistrationConfirmPasswordVisibilityToggled event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    ));
  }

  Future<void> _onTermsAccepted(
    RegistrationTermsAccepted event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      termsAccepted: event.accepted,
      canSubmit: _canSubmit(termsAccepted: event.accepted),
    ));
  }

  Future<void> _onSubmitted(
    RegistrationSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(state.copyWith(
      status: RegistrationStatus.loading,
      isLoading: true,
      generalError: () => null,
    ));

    // Normalize phone number for Nigerian format
    String normalizedPhone = state.phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If it's just 10 digits, add +234
    if (RegExp(r'^[789][01]\d{8}$').hasMatch(normalizedPhone)) {
      normalizedPhone = '+234$normalizedPhone';
    }
    // If it starts with 0, replace with +234
    else if (normalizedPhone.startsWith('0')) {
      normalizedPhone = '+234${normalizedPhone.substring(1)}';
    }
    // If it starts with 234 but no +, add +
    else if (normalizedPhone.startsWith('234')) {
      normalizedPhone = '+$normalizedPhone';
    }
    // If none of the above, assume it needs +234 prefix
    else if (!normalizedPhone.startsWith('+234')) {
      normalizedPhone = '+234$normalizedPhone';
    }

    // Get selected role and convert to string value
    if (state.selectedRole == null) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        isLoading: false,
        generalError: () => AppStrings.errorRoleRequired,
      ));
      return;
    }

    final result = await registerUseCase(
      RegisterParams(
        firstName: state.firstName,
        lastName: state.lastName,
        email: state.email,
        phone: normalizedPhone,
        password: state.password,
        role: state.selectedRole!.value,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: RegistrationStatus.failure,
        isLoading: false,
        generalError: () => failure.message,
      )),
      (user) => emit(state.copyWith(
        status: RegistrationStatus.success,
        isLoading: false,
        user: () => user,
      )),
    );
  }

  bool _canSubmit({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? password,
    String? confirmPassword,
    UserRoleType? selectedRole,
    bool? termsAccepted,
    String? firstNameError,
    String? lastNameError,
    String? emailError,
    String? phoneError,
    String? passwordError,
    String? confirmPasswordError,
  }) {
    final actualFirstName = firstName ?? state.firstName;
    final actualLastName = lastName ?? state.lastName;
    final actualEmail = email ?? state.email;
    final actualPhone = phone ?? state.phone;
    final actualPassword = password ?? state.password;
    final actualConfirmPassword = confirmPassword ?? state.confirmPassword;
    final actualSelectedRole = selectedRole ?? state.selectedRole;
    final actualTermsAccepted = termsAccepted ?? state.termsAccepted;
    final actualFirstNameError = firstNameError ?? state.firstNameError;
    final actualLastNameError = lastNameError ?? state.lastNameError;
    final actualEmailError = emailError ?? state.emailError;
    final actualPhoneError = phoneError ?? state.phoneError;
    final actualPasswordError = passwordError ?? state.passwordError;
    final actualConfirmPasswordError = confirmPasswordError ?? state.confirmPasswordError;

    return actualFirstName.isNotEmpty &&
        actualLastName.isNotEmpty &&
        actualEmail.isNotEmpty &&
        actualPhone.isNotEmpty &&
        actualPassword.isNotEmpty &&
        actualConfirmPassword.isNotEmpty &&
        actualSelectedRole != null &&
        actualTermsAccepted &&
        actualFirstNameError == null &&
        actualLastNameError == null &&
        actualEmailError == null &&
        actualPhoneError == null &&
        actualPasswordError == null &&
        actualConfirmPasswordError == null &&
        Validators.isValidEmail(actualEmail) &&
        Validators.isValidNigerianPhone(actualPhone) &&
        actualPassword.length >= 8 &&
        actualPassword == actualConfirmPassword;
  }
}