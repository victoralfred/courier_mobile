import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/utils/validators.dart';
import '../../../domain/entities/oauth_provider.dart' as domain;
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/oauth_repository.dart';
import '../../../domain/usecases/login.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository authRepository;
  final OAuthRepository oauthRepository;
  final LocalAuthentication localAuth;
  final Login loginUseCase;

  LoginBloc({
    required this.authRepository,
    required this.oauthRepository,
    required this.localAuth,
    required this.loginUseCase,
  }) : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginSubmitted>(_onSubmitted);
    on<LoginWithOAuth>(_onOAuthLogin);
    on<LoginWithBiometric>(_onBiometricLogin);
    on<_UpdateBiometricAvailability>(_onUpdateBiometricAvailability);

    // Check biometric availability on initialization
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isSupported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;

      if (isSupported && canCheck) {
        add(const _UpdateBiometricAvailability(true));
      }
    } catch (_) {
      // Biometrics not available
    }
  }

  Future<void> _onEmailChanged(
    LoginEmailChanged event,
    Emitter<LoginState> emit,
  ) async {
    final email = event.email;
    String? emailError;

    // Validate email
    if (email.isNotEmpty && !Validators.isValidEmail(email)) {
      emailError = AppStrings.errorInvalidEmail;
    }

    final canSubmit = _canSubmit(
      email: email,
      password: state.password,
      emailError: emailError,
      passwordError: state.passwordError,
    );

    emit(state.copyWith(
      email: email,
      emailError: () => emailError,
      canSubmit: canSubmit,
    ));
  }

  Future<void> _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginState> emit,
  ) async {
    final password = event.password;
    String? passwordError;

    // Validate password
    if (password.isEmpty) {
      passwordError = AppStrings.errorPasswordRequired;
    } else if (password.length < 8) {
      passwordError = AppStrings.errorPasswordTooShort;
    }

    final canSubmit = _canSubmit(
      email: state.email,
      password: password,
      emailError: state.emailError,
      passwordError: passwordError,
    );

    emit(state.copyWith(
      password: password,
      passwordError: () => passwordError,
      canSubmit: canSubmit,
    ));
  }

  Future<void> _onPasswordVisibilityToggled(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(state.copyWith(
      status: LoginStatus.loading,
      isLoading: true,
      generalError: () => null,
    ));

    final result = await loginUseCase(
      LoginParams(
        email: state.email,
        password: state.password,
      ),
    );

    result.fold(
      (failure) {
        print('LoginBloc: Login failed - ${failure.message}');
        emit(state.copyWith(
          status: LoginStatus.failure,
          isLoading: false,
          generalError: () => failure.message,
        ));
      },
      (user) {
        print('LoginBloc: Login success - User: ${user.email}, Role: ${user.role.type}');
        emit(state.copyWith(
          status: LoginStatus.success,
          isLoading: false,
          user: () => user,
        ));
      },
    );
  }

  Future<void> _onOAuthLogin(
    LoginWithOAuth event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(
      status: LoginStatus.loading,
      isLoading: true,
      generalError: () => null,
    ));

    // Map event provider type to domain provider
    final domainProvider = _mapToDomainOAuthProvider(event.provider);

    // Generate authorization request
    final authRequestResult =
        await oauthRepository.generateAuthorizationRequest(
      domainProvider,
    );

    await authRequestResult.fold(
      (failure) async => emit(state.copyWith(
        status: LoginStatus.failure,
        isLoading: false,
        generalError: () => failure.message,
      )),
      (authRequest) async {
        // In a real app, this would launch the browser and handle the callback
        // TODO For now, we'll just emit a failure to indicate OAuth flow is not fully implemented
        emit(state.copyWith(
          status: LoginStatus.failure,
          isLoading: false,
          generalError: () => 'OAuth login flow not fully implemented',
        ));
      },
    );
  }

  Future<void> _onBiometricLogin(
    LoginWithBiometric event,
    Emitter<LoginState> emit,
  ) async {
    try {
      final isSupported = await localAuth.isDeviceSupported();
      if (!isSupported) {
        emit(state.copyWith(
          status: LoginStatus.failure,
          generalError: () => AppStrings.errorBiometricNotAvailable,
        ));
        return;
      }

      final canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck) {
        emit(state.copyWith(
          status: LoginStatus.failure,
          generalError: () => AppStrings.errorBiometricNotAvailable,
        ));
        return;
      }

      emit(state.copyWith(
        status: LoginStatus.loading,
        isLoading: true,
        generalError: () => null,
      ));

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        emit(state.copyWith(
          status: LoginStatus.failure,
          isLoading: false,
          generalError: () => AppStrings.errorBiometricAuthFailed,
        ));
        return;
      }

      // Perform biometric login
      final result = await authRepository.loginWithBiometric();

      result.fold(
        (failure) => emit(state.copyWith(
          status: LoginStatus.failure,
          isLoading: false,
          generalError: () => failure.message,
        )),
        (user) => emit(state.copyWith(
          status: LoginStatus.success,
          isLoading: false,
          user: () => user,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        isLoading: false,
        generalError: () => AppStrings.errorUnexpected,
      ));
    }
  }

  void _onUpdateBiometricAvailability(
    _UpdateBiometricAvailability event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(isBiometricAvailable: event.isAvailable));
  }

  bool _canSubmit({
    required String email,
    required String password,
    String? emailError,
    String? passwordError,
  }) =>
      email.isNotEmpty &&
      password.isNotEmpty &&
      emailError == null &&
      passwordError == null &&
      Validators.isValidEmail(email) &&
      password.length >= 8;

  domain.OAuthProvider _mapToDomainOAuthProvider(
    OAuthProviderType eventProvider,
  ) {
    switch (eventProvider) {
      case OAuthProviderType.google:
        return domain.OAuthProvider.google(
          clientId: '', // Will be provided by OAuthConfig
          redirectUri: '', // Will be provided by OAuthConfig
        );
      case OAuthProviderType.github:
        return domain.OAuthProvider.github(
          clientId: '', // Will be provided by OAuthConfig
          redirectUri: '', // Will be provided by OAuthConfig
        );
      case OAuthProviderType.microsoft:
        return domain.OAuthProvider.microsoft(
          clientId: '', // Will be provided by OAuthConfig
          redirectUri: '', // Will be provided by OAuthConfig
        );
      case OAuthProviderType.apple:
        return domain.OAuthProvider.google(
          // Placeholder - Apple not implemented yet
          clientId: '', // Will be provided by OAuthConfig
          redirectUri: '', // Will be provided by OAuthConfig
        );
    }
  }
}

// Internal event for updating biometric availability
class _UpdateBiometricAvailability extends LoginEvent {
  final bool isAvailable;

  const _UpdateBiometricAvailability(this.isAvailable);

  @override
  List<Object> get props => [isAvailable];
}
