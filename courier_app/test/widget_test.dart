import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_app/app.dart';
import 'package:delivery_app/core/config/app_config.dart';
import 'package:delivery_app/core/config/environment.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_state.dart';

@GenerateMocks([LoginBloc])
import 'widget_test.mocks.dart';

void main() {
  late MockLoginBloc mockLoginBloc;

  setUp(() {
    mockLoginBloc = MockLoginBloc();
    when(mockLoginBloc.state).thenReturn(const LoginState());
    when(mockLoginBloc.stream).thenAnswer((_) => Stream.value(const LoginState()));
  });

  testWidgets('CourierApp displays correctly', (WidgetTester tester) async {
    // Set up the environment for testing
    AppConfig.setEnvironment(Environment.development);

    // Build our app with mocked LoginBloc
    await tester.pumpWidget(
      BlocProvider<LoginBloc>.value(
        value: mockLoginBloc,
        child: const CourierApp(),
      ),
    );

    // Wait for any animations to complete
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed with app title
    expect(find.text(AppStrings.loginTitle), findsOneWidget);

    // Verify the shipping icon is displayed
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);

    // Verify email field is present
    expect(find.text(AppStrings.emailLabel), findsOneWidget);

    // Verify password field is present
    expect(find.text(AppStrings.passwordLabel), findsOneWidget);

    // Verify login button is present
    expect(find.text(AppStrings.loginButton), findsOneWidget);
  });
}