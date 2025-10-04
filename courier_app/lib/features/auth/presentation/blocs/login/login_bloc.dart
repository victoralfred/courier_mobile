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

/// [LoginBloc] - BLoC managing login screen state and authentication flows
///
/// **What it does:**
/// - Manages login form state (email, password, validation errors)
/// - Handles email/password login via Login use case
/// - Supports OAuth login (Google, GitHub, Microsoft, Apple)
/// - Supports biometric authentication (Face ID, Touch ID, Fingerprint)
/// - Validates inputs in real-time with error messages
/// - Enables/disables submit button based on validation
/// - Checks biometric availability on initialization
/// - Emits loading/success/failure states for UI updates
///
/// **Why it exists:**
/// - Separates presentation logic from UI (Clean Architecture)
/// - Makes login logic testable (mock events, verify states)
/// - Enables reactive UI (rebuild on state changes)
/// - Centralizes login validation and business rules
/// - Supports multiple authentication methods in one place
/// - Follows BLoC pattern for state management
///
/// **Authentication Methods:**
/// 1. **Email/Password**: Traditional login with validation
/// 2. **OAuth 2.0**: Social login (Google, GitHub, Microsoft, Apple)
/// 3. **Biometric**: Face ID, Touch ID, Fingerprint (requires prior enrollment)
///
/// **State Flow:**
/// ```
/// Initial State
///     ↓
/// User types email → LoginEmailChanged event
///     ↓
/// Validate email → Update state (emailError, canSubmit)
///     ↓
/// User types password → LoginPasswordChanged event
///     ↓
/// Validate password → Update state (passwordError, canSubmit)
///     ↓
/// User taps login → LoginSubmitted event
///     ↓
/// Call Login use case → Loading state
///     ↓
/// Success → LoginState(status: success, user: User)
/// Failure → LoginState(status: failure, generalError: "...")
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In UI (login_screen.dart)
/// class LoginScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return BlocProvider(
///       create: (context) => LoginBloc(
///         authRepository: context.read<AuthRepository>(),
///         oauthRepository: context.read<OAuthRepository>(),
///         localAuth: LocalAuthentication(),
///         loginUseCase: context.read<Login>(),
///       ),
///       child: BlocListener<LoginBloc, LoginState>(
///         listener: (context, state) {
///           if (state.status == LoginStatus.success) {
///             Navigator.pushReplacementNamed(context, '/home');
///           } else if (state.status == LoginStatus.failure) {
///             showErrorSnackbar(context, state.generalError);
///           }
///         },
///         child: LoginForm(),
///       ),
///     );
///   }
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Remove debug print statements (use logging service)
/// - [High Priority] Add remember me functionality (persistent login)
/// - [Medium Priority] Add rate limiting (prevent brute force)
/// - [Medium Priority] Complete OAuth flow implementation (currently placeholder)
/// - [Low Priority] Add social account linking (link OAuth to existing account)
/// - [Low Priority] Add login analytics (track success/failure rates)
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  /// Repository for authentication operations
  ///
  /// **Used for:**
  /// - Biometric login (loginWithBiometric)
  /// - OAuth callback handling (future implementation)
  final AuthRepository authRepository;

  /// Repository for OAuth authentication flows
  ///
  /// **Used for:**
  /// - Generating OAuth authorization requests
  /// - Exchanging authorization codes for tokens
  final OAuthRepository oauthRepository;

  /// Local authentication plugin for biometric authentication
  ///
  /// **Used for:**
  /// - Checking biometric availability (Face ID, Touch ID, Fingerprint)
  /// - Prompting biometric authentication
  final LocalAuthentication localAuth;

  /// Use case for email/password login
  ///
  /// **Used for:**
  /// - Validating email and password
  /// - Performing login via AuthRepository
  final Login loginUseCase;

  /// Creates LoginBloc with required dependencies
  ///
  /// **Parameters:**
  /// - [authRepository]: Repository for auth operations (required)
  /// - [oauthRepository]: Repository for OAuth flows (required)
  /// - [localAuth]: Biometric authentication plugin (required)
  /// - [loginUseCase]: Email/password login use case (required)
  ///
  /// **Initialization:**
  /// - Registers event handlers for all login events
  /// - Checks biometric availability asynchronously
  /// - Initializes with default LoginState
  ///
  /// **Example:**
  /// ```dart
  /// final loginBloc = LoginBloc(
  ///   authRepository: GetIt.I<AuthRepository>(),
  ///   oauthRepository: GetIt.I<OAuthRepository>(),
  ///   localAuth: LocalAuthentication(),
  ///   loginUseCase: GetIt.I<Login>(),
  /// );
  /// ```
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

  /// Checks biometric authentication availability on device
  ///
  /// **What it does:**
  /// - Queries device for biometric hardware support
  /// - Checks if biometric credentials are enrolled
  /// - Updates state with availability status
  /// - Called automatically during BLoC initialization
  ///
  /// **Checks performed:**
  /// 1. Device has biometric hardware (Face ID, Touch ID, Fingerprint)
  /// 2. User has enrolled biometric credentials
  /// 3. App has permission to use biometrics
  ///
  /// **Flow:**
  /// ```
  /// Check isDeviceSupported()
  ///       ↓
  /// Check canCheckBiometrics
  ///       ↓
  /// Both true → Add _UpdateBiometricAvailability(true)
  ///       ↓
  /// State updated → UI shows biometric button
  /// ```
  ///
  /// **Use cases:**
  /// - Show/hide biometric login button
  /// - Display biometric onboarding if available
  /// - Fallback to email/password only if unavailable
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

  /// Handles email input changes with real-time validation
  ///
  /// **What it does:**
  /// - Validates email format as user types
  /// - Updates email error message if invalid
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty email: No error (allow clearing field)
  /// - Non-empty + invalid format: Show error
  /// - Valid format: Clear error
  ///
  /// **Flow:**
  /// ```
  /// User types email
  ///       ↓
  /// Validate format (Validators.isValidEmail)
  ///       ↓
  /// Set emailError if invalid
  ///       ↓
  /// Recalculate canSubmit (email + password valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: LoginEmailChanged containing new email value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   onChanged: (value) => bloc.add(LoginEmailChanged(value)),
  /// )
  /// ```
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

  /// Handles password input changes with real-time validation
  ///
  /// **What it does:**
  /// - Validates password length as user types
  /// - Updates password error message if invalid
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty password: Show "Password required" error
  /// - 1-7 characters: Show "Password too short" error
  /// - 8+ characters: Clear error
  ///
  /// **Flow:**
  /// ```
  /// User types password
  ///       ↓
  /// Check if empty → Show "required" error
  ///       ↓
  /// Check if < 8 chars → Show "too short" error
  ///       ↓
  /// Recalculate canSubmit (email + password valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: LoginPasswordChanged containing new password value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   obscureText: true,
  ///   onChanged: (value) => bloc.add(LoginPasswordChanged(value)),
  /// )
  /// ```
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

  /// Toggles password visibility (show/hide password text)
  ///
  /// **What it does:**
  /// - Toggles isPasswordVisible state flag
  /// - Switches between obscured and plain text display
  /// - Provides visual feedback (icon change)
  ///
  /// **Flow:**
  /// ```
  /// User taps eye icon
  ///       ↓
  /// Toggle isPasswordVisible (true ↔ false)
  ///       ↓
  /// Emit state
  ///       ↓
  /// UI updates (TextField obscureText property)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: LoginPasswordVisibilityToggled event
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   obscureText: !state.isPasswordVisible,
  /// )
  /// IconButton(
  ///   icon: Icon(state.isPasswordVisible ? Icons.visibility_off : Icons.visibility),
  ///   onPressed: () => bloc.add(LoginPasswordVisibilityToggled()),
  /// )
  /// ```
  Future<void> _onPasswordVisibilityToggled(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  /// Handles login form submission via Login use case
  ///
  /// **What it does:**
  /// - Validates canSubmit flag (early return if invalid)
  /// - Shows loading state (spinner)
  /// - Calls Login use case with email and password
  /// - Emits success state with User or failure state with error
  /// - Clears previous errors before submission
  ///
  /// **Flow:**
  /// ```
  /// User taps login button
  ///       ↓
  /// Check canSubmit → Return if false
  ///       ↓
  /// Emit loading state (show spinner)
  ///       ↓
  /// Call loginUseCase(email, password)
  ///       ↓
  /// Success → Emit LoginStatus.success + User
  /// Failure → Emit LoginStatus.failure + error message
  ///       ↓
  /// UI responds (navigate to home or show error)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: LoginSubmitted event
  /// - [emit]: State emitter for updating UI
  ///
  /// **State Transitions:**
  /// - Initial → Loading (isLoading: true, generalError: null)
  /// - Loading → Success (status: success, user: User, isLoading: false)
  /// - Loading → Failure (status: failure, generalError: message, isLoading: false)
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// ElevatedButton(
  ///   onPressed: state.canSubmit
  ///     ? () => bloc.add(LoginSubmitted())
  ///     : null,
  ///   child: state.isLoading
  ///     ? CircularProgressIndicator()
  ///     : Text('Login'),
  /// )
  /// ```
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

  /// Handles OAuth 2.0 social login (Google, GitHub, Microsoft, Apple)
  ///
  /// **What it does:**
  /// - Generates OAuth authorization request
  /// - Maps presentation provider type to domain provider
  /// - Shows loading state during OAuth flow
  /// - Emits failure (OAuth flow not fully implemented yet)
  ///
  /// **OAuth Flow (when implemented):**
  /// ```
  /// User taps social login button (Google, GitHub, etc.)
  ///       ↓
  /// Map OAuthProviderType → domain.OAuthProvider
  ///       ↓
  /// Generate authorization request (OAuth URL + PKCE)
  ///       ↓
  /// Launch browser with OAuth URL
  ///       ↓
  /// User authenticates with provider
  ///       ↓
  /// Redirect to app with auth code
  ///       ↓
  /// Exchange auth code for tokens
  ///       ↓
  /// Emit success with User
  /// ```
  ///
  /// **Supported Providers:**
  /// - Google: OAuth 2.0 with PKCE
  /// - GitHub: OAuth 2.0
  /// - Microsoft: OAuth 2.0 with PKCE
  /// - Apple: Sign in with Apple (placeholder)
  ///
  /// **Parameters:**
  /// - [event]: LoginWithOAuth containing provider type
  /// - [emit]: State emitter for updating UI
  ///
  /// **Current Status:**
  /// - Authorization request generation: ✅ Implemented
  /// - Browser launch and callback: ❌ Not implemented (TODO)
  /// - Token exchange: ❌ Not implemented (TODO)
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// IconButton(
  ///   icon: Icon(Icons.google),
  ///   onPressed: () => bloc.add(LoginWithOAuth(OAuthProviderType.google)),
  /// )
  /// ```
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

  /// Handles biometric authentication login (Face ID, Touch ID, Fingerprint)
  ///
  /// **What it does:**
  /// - Validates biometric hardware availability
  /// - Prompts OS-level biometric authentication
  /// - Retrieves stored credentials from secure enclave
  /// - Performs automatic login with stored credentials
  /// - Emits success with User or failure with error
  ///
  /// **Biometric Flow:**
  /// ```
  /// User taps biometric login button
  ///       ↓
  /// Check device supports biometrics
  ///       ↓
  /// Check biometric credentials enrolled
  ///       ↓
  /// Emit loading state
  ///       ↓
  /// Prompt biometric authentication (OS dialog)
  ///       ↓
  /// User authenticates (Face ID, Touch ID, Fingerprint)
  ///       ↓
  /// Call authRepository.loginWithBiometric()
  ///       ↓
  /// Success → Emit LoginStatus.success + User
  /// Failure → Emit LoginStatus.failure + error
  /// ```
  ///
  /// **Biometric Types:**
  /// - iOS: Face ID, Touch ID
  /// - Android: Fingerprint, Face Unlock
  ///
  /// **Authentication Options:**
  /// - stickyAuth: true (dialog persists across app pauses)
  /// - biometricOnly: true (no PIN/password fallback)
  ///
  /// **Error Cases:**
  /// - Device doesn't support biometrics → Show error
  /// - No biometric credentials enrolled → Show error
  /// - User cancels authentication → Show error
  /// - Biometric authentication fails → Show error
  /// - Login fails (invalid credentials) → Show error
  ///
  /// **Parameters:**
  /// - [event]: LoginWithBiometric event
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// if (state.isBiometricAvailable)
  ///   IconButton(
  ///     icon: Icon(Icons.fingerprint),
  ///     onPressed: () => bloc.add(LoginWithBiometric()),
  ///   )
  /// ```
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

  /// Updates biometric availability flag in state (internal event handler)
  ///
  /// **What it does:**
  /// - Updates isBiometricAvailable state flag
  /// - Triggered by _checkBiometricAvailability during initialization
  /// - Controls biometric button visibility in UI
  ///
  /// **Flow:**
  /// ```
  /// _checkBiometricAvailability checks device
  ///       ↓
  /// Adds _UpdateBiometricAvailability(true) event
  ///       ↓
  /// This handler updates state.isBiometricAvailable
  ///       ↓
  /// UI rebuilds, shows biometric login button
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: Internal _UpdateBiometricAvailability event
  /// - [emit]: State emitter for updating UI
  ///
  /// **Note:** This is an internal event, not exposed to UI layer
  void _onUpdateBiometricAvailability(
    _UpdateBiometricAvailability event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(isBiometricAvailable: event.isAvailable));
  }

  /// Validates if login form can be submitted
  ///
  /// **What it does:**
  /// - Validates all required fields are filled
  /// - Validates no validation errors exist
  /// - Validates email format is correct
  /// - Validates password meets minimum length
  /// - Returns true if all validation passes
  ///
  /// **Validation Checks:**
  /// 1. Email not empty
  /// 2. Password not empty
  /// 3. No email error message
  /// 4. No password error message
  /// 5. Email has valid format
  /// 6. Password is at least 8 characters
  ///
  /// **Used by:**
  /// - _onEmailChanged: Recalculate after email change
  /// - _onPasswordChanged: Recalculate after password change
  ///
  /// **Parameters:**
  /// - [email]: Email to validate (required)
  /// - [password]: Password to validate (required)
  /// - [emailError]: Current email error message (optional)
  /// - [passwordError]: Current password error message (optional)
  ///
  /// **Returns:** true if form is valid and can submit, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// final canSubmit = _canSubmit(
  ///   email: 'user@example.com',
  ///   password: 'SecurePass123',
  ///   emailError: null,
  ///   passwordError: null,
  /// ); // Returns true
  /// ```
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

  /// Maps presentation OAuthProviderType to domain OAuthProvider
  ///
  /// **What it does:**
  /// - Converts UI-layer provider enum to domain-layer provider entity
  /// - Creates OAuthProvider with placeholder client ID and redirect URI
  /// - Supports Google, GitHub, Microsoft, and Apple providers
  /// - Actual OAuth config will be provided by OAuthConfig at runtime
  ///
  /// **Provider Mapping:**
  /// - OAuthProviderType.google → domain.OAuthProvider.google()
  /// - OAuthProviderType.github → domain.OAuthProvider.github()
  /// - OAuthProviderType.microsoft → domain.OAuthProvider.microsoft()
  /// - OAuthProviderType.apple → domain.OAuthProvider.google() (placeholder)
  ///
  /// **Why needed:**
  /// - Presentation layer uses OAuthProviderType enum
  /// - Domain layer uses OAuthProvider value object
  /// - Mapper prevents domain dependency in presentation layer
  ///
  /// **Parameters:**
  /// - [eventProvider]: OAuthProviderType from LoginWithOAuth event
  ///
  /// **Returns:** domain.OAuthProvider entity for use case
  ///
  /// **Note:** Client ID and redirect URI are placeholders. Real values come
  /// from OAuthConfig during authorization request generation.
  ///
  /// **Example:**
  /// ```dart
  /// final provider = _mapToDomainOAuthProvider(OAuthProviderType.google);
  /// // Returns: domain.OAuthProvider.google(clientId: '', redirectUri: '')
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Implement Apple Sign In properly (currently uses Google placeholder)
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

/// [_UpdateBiometricAvailability] - Internal event for updating biometric availability state
///
/// **What it does:**
/// - Encapsulates biometric availability status
/// - Triggered after checking device biometric capabilities
/// - Updates LoginState.isBiometricAvailable flag
/// - Controls biometric login button visibility
///
/// **Why private:**
/// - Internal implementation detail (not for UI layer)
/// - Only used by _checkBiometricAvailability method
/// - Prevents external state manipulation
///
/// **Flow:**
/// ```
/// _checkBiometricAvailability checks device
///       ↓
/// Device supports biometrics
///       ↓
/// add(_UpdateBiometricAvailability(true))
///       ↓
/// _onUpdateBiometricAvailability handles event
///       ↓
/// State updated with isBiometricAvailable: true
/// ```
///
/// **Example (internal use):**
/// ```dart
/// if (isSupported && canCheck) {
///   add(const _UpdateBiometricAvailability(true));
/// }
/// ```
class _UpdateBiometricAvailability extends LoginEvent {
  /// Biometric availability status
  ///
  /// **Values:**
  /// - true: Device supports biometrics and user enrolled credentials
  /// - false: Device doesn't support or no credentials enrolled
  final bool isAvailable;

  /// Creates internal biometric availability event
  ///
  /// **Parameters:**
  /// - [isAvailable]: Biometric availability status (required)
  const _UpdateBiometricAvailability(this.isAvailable);

  /// Equatable props for event comparison
  ///
  /// **Why needed:**
  /// - LoginEvent extends Equatable
  /// - Enables event deduplication in BLoC
  @override
  List<Object> get props => [isAvailable];
}
