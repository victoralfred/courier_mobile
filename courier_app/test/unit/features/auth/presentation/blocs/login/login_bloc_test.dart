import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_event.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_state.dart';
import 'package:delivery_app/features/auth/domain/usecases/login.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/repositories/oauth_repository.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:local_auth/local_auth.dart';

@GenerateMocks([
  AuthRepository,
  OAuthRepository,
  LocalAuthentication,
  Login,
])
import 'login_bloc_test.mocks.dart';

void main() {
  late LoginBloc bloc;
  late MockAuthRepository mockAuthRepository;
  late MockOAuthRepository mockOAuthRepository;
  late MockLocalAuthentication mockLocalAuth;
  late MockLogin mockLoginUseCase;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockOAuthRepository = MockOAuthRepository();
    mockLocalAuth = MockLocalAuthentication();
    mockLoginUseCase = MockLogin();

    bloc = LoginBloc(
      authRepository: mockAuthRepository,
      oauthRepository: mockOAuthRepository,
      localAuth: mockLocalAuth,
      loginUseCase: mockLoginUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  final tUser = User(
    id: EntityID('550e8400-e29b-41d4-a716-446655440001'),
    firstName: 'John',
    lastName: 'Doe',
    email: Email('john.doe@example.com'),
    phone: PhoneNumber('+2341234567890'),
    status: UserStatus.active,
    role: UserRole.customer(),
    customerData: const CustomerData(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('LoginBloc', () {
    test('initial state should be LoginState with default values', () {
      expect(bloc.state, const LoginState());
    });

    group('LoginEmailChanged', () {
      blocTest<LoginBloc, LoginState>(
        'should update email and validate it',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoginEmailChanged('test@example.com')),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should set email error for invalid email',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoginEmailChanged('invalid-email')),
        expect: () => [
          const LoginState(
            email: 'invalid-email',
            emailError: AppStrings.errorInvalidEmail,
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should clear email error for valid email',
        build: () => bloc,
        seed: () => const LoginState(
          email: 'invalid',
          emailError: AppStrings.errorInvalidEmail,
        ),
        act: (bloc) => bloc.add(const LoginEmailChanged('valid@example.com')),
        expect: () => [
          const LoginState(
            email: 'valid@example.com',
            emailError: null,
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should enable submit when both email and password are valid',
        build: () => bloc,
        seed: () => const LoginState(
          password: 'ValidPassword123!',
        ),
        act: (bloc) => bloc.add(const LoginEmailChanged('test@example.com')),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123!',
            canSubmit: true,
          ),
        ],
      );
    });

    group('LoginPasswordChanged', () {
      blocTest<LoginBloc, LoginState>(
        'should update password',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoginPasswordChanged('password123')),
        expect: () => [
          const LoginState(
            password: 'password123',
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should set password error for empty password',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoginPasswordChanged('')),
        expect: () => [
          const LoginState(
            password: '',
            passwordError: AppStrings.errorPasswordRequired,
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should set password error for short password',
        build: () => bloc,
        act: (bloc) => bloc.add(const LoginPasswordChanged('123')),
        expect: () => [
          const LoginState(
            password: '123',
            passwordError: AppStrings.errorPasswordTooShort,
            canSubmit: false,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should enable submit when both email and password are valid',
        build: () => bloc,
        seed: () => const LoginState(
          email: 'test@example.com',
        ),
        act: (bloc) => bloc.add(const LoginPasswordChanged('ValidPassword123')),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123',
            canSubmit: true,
          ),
        ],
      );
    });

    group('LoginPasswordVisibilityToggled', () {
      blocTest<LoginBloc, LoginState>(
        'should toggle password visibility',
        build: () => bloc,
        act: (bloc) {
          bloc.add(const LoginPasswordVisibilityToggled());
          bloc.add(const LoginPasswordVisibilityToggled());
        },
        expect: () => [
          const LoginState(isPasswordVisible: true),
          const LoginState(isPasswordVisible: false),
        ],
      );
    });

    group('LoginSubmitted', () {
      blocTest<LoginBloc, LoginState>(
        'should not submit when form is invalid',
        build: () => bloc,
        seed: () => const LoginState(
          email: 'invalid',
          password: '123',
          canSubmit: false,
        ),
        act: (bloc) => bloc.add(const LoginSubmitted()),
        expect: () => [],
      );

      blocTest<LoginBloc, LoginState>(
        'should emit loading then success when login succeeds',
        build: () {
          when(mockLoginUseCase(any))
              .thenAnswer((_) async => Right(tUser));
          return bloc;
        },
        seed: () => const LoginState(
          email: 'test@example.com',
          password: 'ValidPassword123',
          canSubmit: true,
        ),
        act: (bloc) => bloc.add(const LoginSubmitted()),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123',
            canSubmit: true,
            status: LoginStatus.loading,
            isLoading: true,
          ),
          LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123',
            canSubmit: true,
            status: LoginStatus.success,
            isLoading: false,
            user: tUser,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should emit loading then failure with error message when login fails',
        build: () {
          when(mockLoginUseCase(any))
              .thenAnswer((_) async => const Left(
                    AuthenticationFailure(
                      message: AppStrings.errorInvalidCredentials,
                      code: 'INVALID_CREDENTIALS',
                    ),
                  ));
          return bloc;
        },
        seed: () => const LoginState(
          email: 'test@example.com',
          password: 'WrongPassword',
          canSubmit: true,
        ),
        act: (bloc) => bloc.add(const LoginSubmitted()),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            password: 'WrongPassword',
            canSubmit: true,
            status: LoginStatus.loading,
            isLoading: true,
          ),
          const LoginState(
            email: 'test@example.com',
            password: 'WrongPassword',
            canSubmit: true,
            status: LoginStatus.failure,
            isLoading: false,
            generalError: AppStrings.errorInvalidCredentials,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should handle network failure',
        build: () {
          when(mockLoginUseCase(any))
              .thenAnswer((_) async => const Left(
                    NetworkFailure(message: AppStrings.errorNoInternet),
                  ));
          return bloc;
        },
        seed: () => const LoginState(
          email: 'test@example.com',
          password: 'ValidPassword123',
          canSubmit: true,
        ),
        act: (bloc) => bloc.add(const LoginSubmitted()),
        expect: () => [
          const LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123',
            canSubmit: true,
            status: LoginStatus.loading,
            isLoading: true,
          ),
          const LoginState(
            email: 'test@example.com',
            password: 'ValidPassword123',
            canSubmit: true,
            status: LoginStatus.failure,
            isLoading: false,
            generalError: AppStrings.errorNoInternet,
          ),
        ],
      );
    });

    group('LoginWithBiometric', () {
      blocTest<LoginBloc, LoginState>(
        'should authenticate with biometrics when available',
        build: () {
          when(mockLocalAuth.isDeviceSupported())
              .thenAnswer((_) async => true);
          when(mockLocalAuth.canCheckBiometrics)
              .thenAnswer((_) async => true);
          when(mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            options: anyNamed('options'),
          )).thenAnswer((_) async => true);
          when(mockAuthRepository.loginWithBiometric())
              .thenAnswer((_) async => Right(tUser));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoginWithBiometric()),
        expect: () => [
          const LoginState(
            status: LoginStatus.loading,
            isLoading: true,
          ),
          LoginState(
            status: LoginStatus.success,
            isLoading: false,
            user: tUser,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should fail when biometric authentication fails',
        build: () {
          when(mockLocalAuth.isDeviceSupported())
              .thenAnswer((_) async => true);
          when(mockLocalAuth.canCheckBiometrics)
              .thenAnswer((_) async => true);
          when(mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            options: anyNamed('options'),
          )).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(const LoginWithBiometric()),
        expect: () => [
          const LoginState(
            status: LoginStatus.loading,
            isLoading: true,
          ),
          const LoginState(
            status: LoginStatus.failure,
            isLoading: false,
            generalError: AppStrings.errorBiometricAuthFailed,
          ),
        ],
      );

      blocTest<LoginBloc, LoginState>(
        'should fail when biometrics not available',
        build: () {
          when(mockLocalAuth.isDeviceSupported())
              .thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(const LoginWithBiometric()),
        expect: () => [
          const LoginState(
            status: LoginStatus.failure,
            generalError: AppStrings.errorBiometricNotAvailable,
          ),
        ],
      );
    });

    group('initialization', () {
      test('should check biometric availability on initialization', () async {
        when(mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);

        final bloc = LoginBloc(
          authRepository: mockAuthRepository,
          oauthRepository: mockOAuthRepository,
          localAuth: mockLocalAuth,
          loginUseCase: mockLoginUseCase,
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(bloc.state.isBiometricAvailable, true);

        bloc.close();
      });
    });
  });
}