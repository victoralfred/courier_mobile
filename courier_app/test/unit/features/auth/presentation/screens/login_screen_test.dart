import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_app/features/auth/presentation/screens/login_screen.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_event.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_state.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/routing/route_names.dart';

@GenerateMocks([LoginBloc])
import 'login_screen_test.mocks.dart';

void main() {
  late MockLoginBloc mockLoginBloc;

  setUp(() {
    mockLoginBloc = MockLoginBloc();
    when(mockLoginBloc.state).thenReturn(const LoginState());
    when(mockLoginBloc.stream).thenAnswer((_) => Stream.value(const LoginState()));
    when(mockLoginBloc.add(any)).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<LoginBloc>.value(
        value: mockLoginBloc,
        child: const LoginScreen(),
      ),
    );
  }

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

  group('LoginScreen', () {
    testWidgets('should display login form with all elements', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Check for logo/title
      expect(find.text(AppStrings.loginTitle), findsOneWidget);

      // Check for email field
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(AppStrings.emailLabel), findsOneWidget);

      // Check for password field
      expect(find.text(AppStrings.passwordLabel), findsOneWidget);

      // Check for login button
      expect(find.text(AppStrings.loginButton), findsOneWidget);

      // Check for forgot password link
      expect(find.text(AppStrings.forgotPassword), findsOneWidget);

      // Check for sign up link
      expect(find.text(AppStrings.signUpPrompt), findsOneWidget);
    });

    testWidgets('should show password visibility toggle', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Find password visibility icon
      final visibilityIcon = find.byIcon(Icons.visibility_outlined);
      expect(visibilityIcon, findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(visibilityIcon);
      await tester.pump();

      // Verify event was sent to bloc
      verify(mockLoginBloc.add(const LoginPasswordVisibilityToggled())).called(1);
    });

    testWidgets('should dispatch LoginEmailChanged when email is entered', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.widgetWithText(TextField, AppStrings.emailLabel);
      await tester.enterText(emailField, 'test@example.com');

      verify(mockLoginBloc.add(const LoginEmailChanged('test@example.com'))).called(1);
    });

    testWidgets('should dispatch LoginPasswordChanged when password is entered', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final passwordField = find.widgetWithText(TextField, AppStrings.passwordLabel);
      await tester.enterText(passwordField, 'password123');

      verify(mockLoginBloc.add(const LoginPasswordChanged('password123'))).called(1);
    });

    testWidgets('should dispatch LoginSubmitted when login button is pressed', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        email: 'test@example.com',
        password: 'password123',
        canSubmit: true,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      final loginButton = find.text(AppStrings.loginButton);
      await tester.tap(loginButton);

      verify(mockLoginBloc.add(const LoginSubmitted())).called(1);
    });

    testWidgets('should disable login button when canSubmit is false', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        canSubmit: false,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      final loginButton = find.widgetWithText(ElevatedButton, AppStrings.loginButton);
      final button = tester.widget<ElevatedButton>(loginButton);

      expect(button.onPressed, isNull);
    });

    testWidgets('should enable login button when canSubmit is true', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        email: 'test@example.com',
        password: 'password123',
        canSubmit: true,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      final loginButton = find.widgetWithText(ElevatedButton, AppStrings.loginButton);
      final button = tester.widget<ElevatedButton>(loginButton);

      expect(button.onPressed, isNotNull);
    });

    testWidgets('should show loading indicator when status is loading', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        status: LoginStatus.loading,
        isLoading: true,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show email error when present', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        emailError: AppStrings.errorInvalidEmail,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text(AppStrings.errorInvalidEmail), findsOneWidget);
    });

    testWidgets('should show password error when present', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        passwordError: AppStrings.errorPasswordTooShort,
      ));

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text(AppStrings.errorPasswordTooShort), findsOneWidget);
    });

    testWidgets('should show general error in snackbar when present', (WidgetTester tester) async {
      when(mockLoginBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([
          const LoginState(
            status: LoginStatus.failure,
            generalError: AppStrings.errorInvalidCredentials,
          ),
        ]),
      );
      when(mockLoginBloc.state).thenReturn(const LoginState(
        status: LoginStatus.failure,
        generalError: AppStrings.errorInvalidCredentials,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text(AppStrings.errorInvalidCredentials), findsOneWidget);
    });

    testWidgets('should navigate to home when login succeeds', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider<LoginBloc>.value(
              value: mockLoginBloc,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.customerHome,
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      when(mockLoginBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([
          LoginState(
            status: LoginStatus.success,
            user: tUser,
          ),
        ]),
      );
      when(mockLoginBloc.state).thenReturn(LoginState(
        status: LoginStatus.success,
        user: tUser,
      ));

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('should show OAuth login buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text(AppStrings.loginWithGoogle), findsOneWidget);
      expect(find.text(AppStrings.loginWithGithub), findsOneWidget);
      expect(find.text(AppStrings.loginWithMicrosoft), findsOneWidget);
    });

    testWidgets('should dispatch LoginWithOAuth when OAuth button is pressed', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        isLoading: false,
      ));
      when(mockLoginBloc.stream).thenAnswer((_) => Stream.value(const LoginState(
        isLoading: false,
      )));

      await tester.pumpWidget(createWidgetUnderTest());

      // Ensure OAuth button is visible
      final googleButton = find.text(AppStrings.loginWithGoogle);
      await tester.ensureVisible(googleButton);
      await tester.pumpAndSettle();

      await tester.tap(googleButton);

      verify(mockLoginBloc.add(const LoginWithOAuth(OAuthProviderType.google))).called(1);
    });

    testWidgets('should show biometric login button when available', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        isBiometricAvailable: true,
      ));
      when(mockLoginBloc.stream).thenAnswer((_) => Stream.value(const LoginState(
        isBiometricAvailable: true,
      )));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final biometricButton = find.byIcon(Icons.fingerprint);

      // Scroll to make sure the button is visible
      await tester.ensureVisible(biometricButton);
      await tester.pumpAndSettle();

      expect(biometricButton, findsOneWidget);
    });

    testWidgets('should dispatch LoginWithBiometric when biometric button is pressed', (WidgetTester tester) async {
      when(mockLoginBloc.state).thenReturn(const LoginState(
        isBiometricAvailable: true,
        isLoading: false,
      ));
      when(mockLoginBloc.stream).thenAnswer((_) => Stream.value(const LoginState(
        isBiometricAvailable: true,
        isLoading: false,
      )));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final biometricButton = find.byIcon(Icons.fingerprint);

      // Ensure the biometric button is visible
      await tester.ensureVisible(biometricButton);
      await tester.pumpAndSettle();

      expect(biometricButton, findsOneWidget); // Verify button exists

      await tester.tap(biometricButton);
      await tester.pump();

      verify(mockLoginBloc.add(const LoginWithBiometric())).called(1);
    });

    testWidgets('should navigate to registration screen when sign up is pressed', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider<LoginBloc>.value(
              value: mockLoginBloc,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.register,
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Register')),
              body: const Text('Registration Page'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Scroll to make sign up link visible
      await tester.ensureVisible(find.text(AppStrings.signUp));
      await tester.pumpAndSettle();

      final signUpLink = find.text(AppStrings.signUp);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('should navigate to forgot password when link is pressed', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider<LoginBloc>.value(
              value: mockLoginBloc,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.forgotPassword,
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Forgot Password')),
              body: const Text('Password Reset Page'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Ensure forgot password link is visible
      await tester.ensureVisible(find.text(AppStrings.forgotPassword));
      await tester.pumpAndSettle();

      final forgotPasswordLink = find.text(AppStrings.forgotPassword);
      await tester.tap(forgotPasswordLink);
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
    });
  });
}