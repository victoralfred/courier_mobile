import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_app/core/routing/splash_screen.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';

@GenerateMocks([AuthRepository])
import 'widget_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    when(mockAuthRepository.isAuthenticated()).thenAnswer((_) async => false);
  });

  testWidgets('SplashScreen displays correctly', (WidgetTester tester) async {
    // Disable automatic timer execution
    await tester.runAsync(() async {
      // Build just the splash screen widget with mocked AuthRepository
      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<AuthRepository>.value(
            value: mockAuthRepository,
            child: const SplashScreen(),
          ),
        ),
      );
    });

    // Verify splash screen displays the correct elements immediately
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}