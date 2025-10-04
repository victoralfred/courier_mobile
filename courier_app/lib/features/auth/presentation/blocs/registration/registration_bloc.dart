import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/utils/validators.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/features/auth/domain/usecases/register.dart';
import 'registration_event.dart';
import 'registration_state.dart';

/// [RegistrationBloc] - BLoC managing registration form state and user account creation
///
/// **What it does:**
/// - Manages multi-field registration form (first name, last name, email, phone, password)
/// - Validates all inputs in real-time with error messages
/// - Enforces password strength requirements (min 8 chars, complexity check)
/// - Validates password confirmation match
/// - Normalizes Nigerian phone numbers to E.164 format (+234)
/// - Handles role selection (driver or customer)
/// - Enforces terms and conditions acceptance
/// - Creates user account via Register use case
/// - Automatically logs in user after successful registration
///
/// **Why it exists:**
/// - Separates presentation logic from UI (Clean Architecture)
/// - Centralizes complex registration validation in one place
/// - Makes registration logic testable (mock events, verify states)
/// - Enables reactive UI (rebuild on state changes)
/// - Supports role-based registration (driver vs customer)
/// - Follows BLoC pattern for state management
///
/// **Validation Features:**
/// - **Name validation**: 2+ characters, letters only
/// - **Email validation**: Standard email format
/// - **Phone validation**: Nigerian phone format (supports multiple formats)
/// - **Password strength**: 0-3 scale (weak, fair, good, strong)
/// - **Password match**: Confirm password must match
/// - **Terms acceptance**: Required checkbox
/// - **Role selection**: Driver or customer (required)
///
/// **Phone Normalization:**
/// ```
/// Input: 0801 234 5678 → Output: +2348012345678
/// Input: 8012345678    → Output: +2348012345678
/// Input: 2348012345678 → Output: +2348012345678
/// Input: +2348012345678 → Output: +2348012345678 (no change)
/// ```
///
/// **State Flow:**
/// ```
/// Initial State
///     ↓
/// User fills form fields → Field change events
///     ↓
/// Validate each field → Update errors, password strength
///     ↓
/// Recalculate canSubmit (all fields valid + terms accepted)
///     ↓
/// User taps register → RegistrationSubmitted event
///     ↓
/// Normalize phone number → E.164 format
///     ↓
/// Call Register use case → Loading state
///     ↓
/// Success → RegistrationState(status: success, user: User)
/// Failure → RegistrationState(status: failure, generalError: "...")
/// ```
///
/// **Usage Example:**
/// ```dart
/// // In UI (registration_screen.dart)
/// class RegistrationScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return BlocProvider(
///       create: (context) => RegistrationBloc(
///         authRepository: context.read<AuthRepository>(),
///         registerUseCase: context.read<Register>(),
///       ),
///       child: BlocListener<RegistrationBloc, RegistrationState>(
///         listener: (context, state) {
///           if (state.status == RegistrationStatus.success) {
///             Navigator.pushReplacementNamed(context, '/home');
///           } else if (state.status == RegistrationStatus.failure) {
///             showErrorSnackbar(context, state.generalError);
///           }
///         },
///         child: RegistrationForm(),
///       ),
///     );
///   }
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add email verification step (send verification code)
/// - [High Priority] Add phone verification step (SMS OTP)
/// - [Medium Priority] Add referral code support
/// - [Medium Priority] Add profile picture upload during registration
/// - [Low Priority] Add social registration (Google, Apple)
/// - [Low Priority] Add registration analytics (track conversion funnel)
class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  /// Repository for authentication operations
  ///
  /// **Used for:**
  /// - Future biometric enrollment after registration
  /// - Profile updates post-registration
  final AuthRepository authRepository;

  /// Use case for user registration
  ///
  /// **Used for:**
  /// - Creating new user account
  /// - Validating registration data
  /// - Automatic login after successful registration
  final Register registerUseCase;

  /// Creates RegistrationBloc with required dependencies
  ///
  /// **Parameters:**
  /// - [authRepository]: Repository for auth operations (required)
  /// - [registerUseCase]: User registration use case (required)
  ///
  /// **Initialization:**
  /// - Registers event handlers for all 11 registration events
  /// - Initializes with default RegistrationState (all fields empty)
  /// - Sets up real-time validation for form fields
  ///
  /// **Event Handlers:**
  /// 1. RegistrationFirstNameChanged → _onFirstNameChanged
  /// 2. RegistrationLastNameChanged → _onLastNameChanged
  /// 3. RegistrationEmailChanged → _onEmailChanged
  /// 4. RegistrationPhoneChanged → _onPhoneChanged
  /// 5. RegistrationPasswordChanged → _onPasswordChanged
  /// 6. RegistrationConfirmPasswordChanged → _onConfirmPasswordChanged
  /// 7. RegistrationRoleSelected → _onRoleSelected
  /// 8. RegistrationPasswordVisibilityToggled → _onPasswordVisibilityToggled
  /// 9. RegistrationConfirmPasswordVisibilityToggled → _onConfirmPasswordVisibilityToggled
  /// 10. RegistrationTermsAccepted → _onTermsAccepted
  /// 11. RegistrationSubmitted → _onSubmitted
  ///
  /// **Example:**
  /// ```dart
  /// final registrationBloc = RegistrationBloc(
  ///   authRepository: GetIt.I<AuthRepository>(),
  ///   registerUseCase: GetIt.I<Register>(),
  /// );
  /// ```
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

  /// Handles first name input changes with real-time validation
  ///
  /// **What it does:**
  /// - Validates first name format as user types
  /// - Updates first name error message if invalid
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty first name: No error (allow clearing field)
  /// - Non-empty + invalid format: Show error (must be valid name)
  /// - Valid format: Clear error (2+ characters, letters only)
  ///
  /// **Flow:**
  /// ```
  /// User types first name
  ///       ↓
  /// Validate format (Validators.isValidName)
  ///       ↓
  /// Set firstNameError if invalid
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationFirstNameChanged containing new first name value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   onChanged: (value) => bloc.add(RegistrationFirstNameChanged(value)),
  /// )
  /// ```
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

  /// Handles last name input changes with real-time validation
  ///
  /// **What it does:**
  /// - Validates last name format as user types
  /// - Updates last name error message if invalid
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty last name: No error (allow clearing field)
  /// - Non-empty + invalid format: Show error (must be valid name)
  /// - Valid format: Clear error (2+ characters, letters only)
  ///
  /// **Flow:**
  /// ```
  /// User types last name
  ///       ↓
  /// Validate format (Validators.isValidName)
  ///       ↓
  /// Set lastNameError if invalid
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationLastNameChanged containing new last name value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   onChanged: (value) => bloc.add(RegistrationLastNameChanged(value)),
  /// )
  /// ```
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
  /// - Valid format: Clear error (standard email format)
  ///
  /// **Flow:**
  /// ```
  /// User types email
  ///       ↓
  /// Validate format (Validators.isValidEmail)
  ///       ↓
  /// Set emailError if invalid
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationEmailChanged containing new email value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   keyboardType: TextInputType.emailAddress,
  ///   onChanged: (value) => bloc.add(RegistrationEmailChanged(value)),
  /// )
  /// ```
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

  /// Handles phone number input changes with real-time validation
  ///
  /// **What it does:**
  /// - Validates Nigerian phone number format as user types
  /// - Updates phone error message if invalid
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty phone: No error (allow clearing field)
  /// - Non-empty + invalid format: Show error
  /// - Valid format: Clear error (Nigerian phone format)
  ///
  /// **Accepted Phone Formats:**
  /// - 0801 234 5678 (with spaces)
  /// - 08012345678 (10 digits starting with 0)
  /// - 8012345678 (10 digits without leading 0)
  /// - 2348012345678 (13 digits with country code)
  /// - +2348012345678 (E.164 format)
  ///
  /// **Flow:**
  /// ```
  /// User types phone
  ///       ↓
  /// Validate format (Validators.isValidNigerianPhone)
  ///       ↓
  /// Set phoneError if invalid
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationPhoneChanged containing new phone value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   keyboardType: TextInputType.phone,
  ///   onChanged: (value) => bloc.add(RegistrationPhoneChanged(value)),
  /// )
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add phone formatter (auto-format as user types)
  /// - [Low Priority] Add country code selector (support other countries)
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

  /// Handles password input changes with real-time validation and strength calculation
  ///
  /// **What it does:**
  /// - Validates password length and strength as user types
  /// - Calculates password strength score (0-3)
  /// - Validates confirm password still matches
  /// - Updates password and confirm password error messages
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty password: No error, strength = 0 (allow clearing field)
  /// - 1-7 characters: Show "Password too short" error
  /// - 8+ characters + strength < 2: Show "Password too weak" error
  /// - 8+ characters + strength >= 2: Clear error
  ///
  /// **Password Strength Calculation:**
  /// ```
  /// Strength 0 (Weak):     < 8 chars or only lowercase
  /// Strength 1 (Fair):     8+ chars + lowercase + uppercase
  /// Strength 2 (Good):     8+ chars + lowercase + uppercase + numbers
  /// Strength 3 (Strong):   8+ chars + lowercase + uppercase + numbers + symbols
  /// ```
  ///
  /// **Confirm Password Check:**
  /// - If confirm password is filled but doesn't match new password
  /// - Show mismatch error on confirm password field
  /// - This provides real-time feedback as user changes password
  ///
  /// **Flow:**
  /// ```
  /// User types password
  ///       ↓
  /// Calculate strength (Validators.getPasswordStrength)
  ///       ↓
  /// Check length (min 8 chars)
  ///       ↓
  /// Check strength (min 2/3)
  ///       ↓
  /// Set passwordError if invalid
  ///       ↓
  /// Check if confirm password still matches
  ///       ↓
  /// Set confirmPasswordError if mismatch
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show errors, strength indicator, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationPasswordChanged containing new password value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   obscureText: true,
  ///   onChanged: (value) => bloc.add(RegistrationPasswordChanged(value)),
  /// )
  /// // Show password strength indicator
  /// LinearProgressIndicator(
  ///   value: state.passwordStrength / 3,
  ///   color: state.passwordStrength >= 2 ? Colors.green : Colors.red,
  /// )
  /// ```
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

  /// Handles confirm password input changes with real-time match validation
  ///
  /// **What it does:**
  /// - Validates confirm password matches password as user types
  /// - Updates confirm password error message if mismatch
  /// - Recalculates canSubmit status
  /// - Emits new state with validation results
  ///
  /// **Validation Rules:**
  /// - Empty confirm password: No error (allow clearing field)
  /// - Non-empty + doesn't match password: Show "Passwords do not match" error
  /// - Matches password: Clear error
  ///
  /// **Flow:**
  /// ```
  /// User types confirm password
  ///       ↓
  /// Compare with password field
  ///       ↓
  /// Set confirmPasswordError if mismatch
  ///       ↓
  /// Recalculate canSubmit (all fields valid)
  ///       ↓
  /// Emit state → UI updates (show error, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationConfirmPasswordChanged containing new confirm password value
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   obscureText: true,
  ///   onChanged: (value) => bloc.add(RegistrationConfirmPasswordChanged(value)),
  /// )
  /// ```
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

  /// Handles user role selection (driver or customer)
  ///
  /// **What it does:**
  /// - Updates selected role in state
  /// - Recalculates canSubmit status
  /// - Emits new state with role selection
  ///
  /// **Supported Roles:**
  /// - UserRoleType.driver: Register as driver (requires vehicle info later)
  /// - UserRoleType.customer: Register as customer (default role)
  ///
  /// **Flow:**
  /// ```
  /// User selects role (driver/customer)
  ///       ↓
  /// Update selectedRole
  ///       ↓
  /// Recalculate canSubmit (role is required)
  ///       ↓
  /// Emit state → UI updates (highlight selected role, enable/disable button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationRoleSelected containing selected role
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// SegmentedButton<UserRoleType>(
  ///   selected: {state.selectedRole},
  ///   onSelectionChanged: (roles) => bloc.add(
  ///     RegistrationRoleSelected(roles.first),
  ///   ),
  ///   segments: [
  ///     ButtonSegment(value: UserRoleType.customer, label: Text('Customer')),
  ///     ButtonSegment(value: UserRoleType.driver, label: Text('Driver')),
  ///   ],
  /// )
  /// ```
  Future<void> _onRoleSelected(
    RegistrationRoleSelected event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      selectedRole: () => event.role,
      canSubmit: _canSubmit(selectedRole: event.role),
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
  /// User taps eye icon on password field
  ///       ↓
  /// Toggle isPasswordVisible (true ↔ false)
  ///       ↓
  /// Emit state
  ///       ↓
  /// UI updates (TextField obscureText property)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationPasswordVisibilityToggled event
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
  ///   onPressed: () => bloc.add(RegistrationPasswordVisibilityToggled()),
  /// )
  /// ```
  Future<void> _onPasswordVisibilityToggled(
    RegistrationPasswordVisibilityToggled event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  /// Toggles confirm password visibility (show/hide confirm password text)
  ///
  /// **What it does:**
  /// - Toggles isConfirmPasswordVisible state flag
  /// - Switches between obscured and plain text display
  /// - Provides visual feedback (icon change)
  ///
  /// **Flow:**
  /// ```
  /// User taps eye icon on confirm password field
  ///       ↓
  /// Toggle isConfirmPasswordVisible (true ↔ false)
  ///       ↓
  /// Emit state
  ///       ↓
  /// UI updates (TextField obscureText property)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationConfirmPasswordVisibilityToggled event
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// TextField(
  ///   obscureText: !state.isConfirmPasswordVisible,
  /// )
  /// IconButton(
  ///   icon: Icon(state.isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
  ///   onPressed: () => bloc.add(RegistrationConfirmPasswordVisibilityToggled()),
  /// )
  /// ```
  Future<void> _onConfirmPasswordVisibilityToggled(
    RegistrationConfirmPasswordVisibilityToggled event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    ));
  }

  /// Handles terms and conditions acceptance checkbox
  ///
  /// **What it does:**
  /// - Updates termsAccepted state flag
  /// - Recalculates canSubmit status
  /// - Emits new state with acceptance status
  ///
  /// **Validation Rules:**
  /// - Terms must be accepted before registration
  /// - canSubmit returns false if termsAccepted is false
  /// - User must explicitly check the checkbox
  ///
  /// **Flow:**
  /// ```
  /// User toggles terms checkbox
  ///       ↓
  /// Update termsAccepted (true/false)
  ///       ↓
  /// Recalculate canSubmit (required for submission)
  ///       ↓
  /// Emit state → UI updates (enable/disable register button)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationTermsAccepted containing acceptance status
  /// - [emit]: State emitter for updating UI
  ///
  /// **Example:**
  /// ```dart
  /// // In UI
  /// CheckboxListTile(
  ///   value: state.termsAccepted,
  ///   onChanged: (value) => bloc.add(RegistrationTermsAccepted(value ?? false)),
  ///   title: Text('I agree to the Terms and Conditions'),
  /// )
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add terms and conditions dialog/web view
  /// - [Low Priority] Track terms version (for legal compliance)
  Future<void> _onTermsAccepted(
    RegistrationTermsAccepted event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      termsAccepted: event.accepted,
      canSubmit: _canSubmit(termsAccepted: event.accepted),
    ));
  }

  /// Handles registration form submission via Register use case
  ///
  /// **What it does:**
  /// - Validates canSubmit flag (early return if invalid)
  /// - Shows loading state (spinner)
  /// - Normalizes phone number to E.164 format (+234)
  /// - Validates role is selected
  /// - Calls Register use case with all registration data
  /// - Emits success state with User or failure state with error
  /// - Automatically logs in user after successful registration
  ///
  /// **Phone Normalization Logic:**
  /// ```
  /// Step 1: Remove formatting characters (spaces, dashes, parentheses)
  /// Step 2: Apply normalization rules:
  ///
  ///   Pattern 1: 10 digits starting with 7, 8, or 9
  ///   Example: 8012345678 → +2348012345678
  ///   Regex: ^[789][01]\d{8}$
  ///
  ///   Pattern 2: Starts with 0
  ///   Example: 08012345678 → +2348012345678
  ///   Logic: Replace leading 0 with +234
  ///
  ///   Pattern 3: Starts with 234 (no +)
  ///   Example: 2348012345678 → +2348012345678
  ///   Logic: Prepend +
  ///
  ///   Pattern 4: Already has +234
  ///   Example: +2348012345678 → +2348012345678 (no change)
  ///
  ///   Pattern 5: None of the above
  ///   Example: 12345678 → +23412345678
  ///   Logic: Prepend +234 (fallback)
  /// ```
  ///
  /// **Flow:**
  /// ```
  /// User taps register button
  ///       ↓
  /// Check canSubmit → Return if false
  ///       ↓
  /// Emit loading state (show spinner)
  ///       ↓
  /// Normalize phone number → E.164 format
  ///       ↓
  /// Validate role selected → Return if null
  ///       ↓
  /// Call registerUseCase(firstName, lastName, email, phone, password, role)
  ///       ↓
  /// Success → Emit RegistrationStatus.success + User (auto-login)
  /// Failure → Emit RegistrationStatus.failure + error message
  ///       ↓
  /// UI responds (navigate to home or show error)
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: RegistrationSubmitted event
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
  ///     ? () => bloc.add(RegistrationSubmitted())
  ///     : null,
  ///   child: state.isLoading
  ///     ? CircularProgressIndicator()
  ///     : Text('Register'),
  /// )
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add email verification before completing registration
  /// - [High Priority] Add SMS OTP verification for phone number
  /// - [Medium Priority] Add phone normalization unit tests
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

  /// Validates if registration form can be submitted
  ///
  /// **What it does:**
  /// - Validates all required fields are filled
  /// - Validates no validation errors exist
  /// - Validates email format is correct
  /// - Validates phone number format is correct
  /// - Validates password meets requirements
  /// - Validates passwords match
  /// - Validates role is selected
  /// - Validates terms are accepted
  /// - Returns true if all validation passes
  ///
  /// **Validation Checks (16 total):**
  /// 1. First name not empty
  /// 2. Last name not empty
  /// 3. Email not empty
  /// 4. Phone not empty
  /// 5. Password not empty
  /// 6. Confirm password not empty
  /// 7. Role selected (not null)
  /// 8. Terms accepted (true)
  /// 9. No first name error
  /// 10. No last name error
  /// 11. No email error
  /// 12. No phone error
  /// 13. No password error
  /// 14. No confirm password error
  /// 15. Email has valid format (double-check)
  /// 16. Phone has valid Nigerian format (double-check)
  /// 17. Password is at least 8 characters (double-check)
  /// 18. Password matches confirm password (double-check)
  ///
  /// **Parameter Merging:**
  /// - Accepts optional override parameters (for updated fields)
  /// - Falls back to current state values if not provided
  /// - This allows testing validation during state changes
  ///
  /// **Used by:**
  /// - _onFirstNameChanged: Recalculate after first name change
  /// - _onLastNameChanged: Recalculate after last name change
  /// - _onEmailChanged: Recalculate after email change
  /// - _onPhoneChanged: Recalculate after phone change
  /// - _onPasswordChanged: Recalculate after password change
  /// - _onConfirmPasswordChanged: Recalculate after confirm password change
  /// - _onRoleSelected: Recalculate after role selection
  /// - _onTermsAccepted: Recalculate after terms acceptance
  ///
  /// **Parameters:**
  /// - [firstName]: First name to validate (optional, defaults to state)
  /// - [lastName]: Last name to validate (optional, defaults to state)
  /// - [email]: Email to validate (optional, defaults to state)
  /// - [phone]: Phone to validate (optional, defaults to state)
  /// - [password]: Password to validate (optional, defaults to state)
  /// - [confirmPassword]: Confirm password to validate (optional, defaults to state)
  /// - [selectedRole]: Role to validate (optional, defaults to state)
  /// - [termsAccepted]: Terms acceptance to validate (optional, defaults to state)
  /// - [firstNameError]: First name error message (optional, defaults to state)
  /// - [lastNameError]: Last name error message (optional, defaults to state)
  /// - [emailError]: Email error message (optional, defaults to state)
  /// - [phoneError]: Phone error message (optional, defaults to state)
  /// - [passwordError]: Password error message (optional, defaults to state)
  /// - [confirmPasswordError]: Confirm password error message (optional, defaults to state)
  ///
  /// **Returns:** true if form is valid and can submit, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// // Test if form valid after email change
  /// final canSubmit = _canSubmit(
  ///   email: 'user@example.com',
  ///   emailError: null,
  /// );
  /// // Other fields use current state values
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Low Priority] Extract to separate validator class (for reusability)
  /// - [Low Priority] Add custom validation rules per field (for extensibility)
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