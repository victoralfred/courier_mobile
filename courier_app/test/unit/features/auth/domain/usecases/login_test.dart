import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:delivery_app/features/auth/domain/usecases/login.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/core/error/failures.dart';

import 'login_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late Login usecase;
  late MockAuthRepository mockAuthRepository;
  late User testUser;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = Login(mockAuthRepository);

    testUser = User(
      id: EntityID.generate(),
      firstName: 'John',
      lastName: 'Doe',
      email: Email('john.doe@example.com'),
      phone: PhoneNumber('+2348031234567'),
      status: UserStatus.active,
      role: UserRole.customer(),
      customerData: const CustomerData(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  group('Login Use Case', () {
    const testEmail = 'john.doe@example.com';
    const testPassword = 'Test@1234';

    test('should get user from repository when login is successful', () async {
      // Arrange
      when(mockAuthRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => Right(testUser));

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: testPassword,
      ));

      // Assert
      expect(result, equals(Right(testUser)));
      verify(mockAuthRepository.login(
        email: testEmail,
        password: testPassword,
      ));
      verifyNoMoreInteractions(mockAuthRepository);
    });

    test('should return AuthenticationFailure when credentials are invalid', () async {
      // Arrange
      const failure = AuthenticationFailure(message: 'Invalid credentials');
      when(mockAuthRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: testPassword,
      ));

      // Assert
      expect(result, equals(const Left(failure)));
      verify(mockAuthRepository.login(
        email: testEmail,
        password: testPassword,
      ));
      verifyNoMoreInteractions(mockAuthRepository);
    });

    test('should return NetworkFailure when there is no internet connection', () async {
      // Arrange
      const failure = NetworkFailure(message: 'No internet connection');
      when(mockAuthRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: testPassword,
      ));

      // Assert
      expect(result, equals(const Left(failure)));
    });

    test('should return ServerFailure when server error occurs', () async {
      // Arrange
      const failure = ServerFailure(message: 'Internal server error');
      when(mockAuthRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: testPassword,
      ));

      // Assert
      expect(result, equals(const Left(failure)));
    });

    test('should validate email format before calling repository', () async {
      // Arrange
      const invalidEmail = 'invalid-email';

      // Act
      final result = await usecase(const LoginParams(
        email: invalidEmail,
        password: testPassword,
      ));

      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return ValidationFailure'),
      );
      verifyZeroInteractions(mockAuthRepository);
    });

    test('should validate password is not empty', () async {
      // Arrange
      const emptyPassword = '';

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: emptyPassword,
      ));

      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return ValidationFailure'),
      );
      verifyZeroInteractions(mockAuthRepository);
    });

    test('should validate password minimum length', () async {
      // Arrange
      const shortPassword = '1234567'; // Less than 8 characters

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: shortPassword,
      ));

      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should return ValidationFailure'),
      );
      verifyZeroInteractions(mockAuthRepository);
    });

    test('should save tokens after successful login', () async {
      // Arrange
      when(mockAuthRepository.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => Right(testUser));

      when(mockAuthRepository.saveTokens(
        accessToken: anyNamed('accessToken'),
        refreshToken: anyNamed('refreshToken'),
        csrfToken: anyNamed('csrfToken'),
      )).thenAnswer((_) async => const Right(true));

      // Act
      final result = await usecase(const LoginParams(
        email: testEmail,
        password: testPassword,
      ));

      // Assert
      expect(result, equals(Right(testUser)));
      verify(mockAuthRepository.login(
        email: testEmail,
        password: testPassword,
      ));
    });
  });

  group('LoginParams', () {
    test('should support equality', () {
      // Arrange
      const params1 = LoginParams(
        email: 'test@example.com',
        password: 'password123',
      );
      const params2 = LoginParams(
        email: 'test@example.com',
        password: 'password123',
      );
      const params3 = LoginParams(
        email: 'different@example.com',
        password: 'password123',
      );

      // Assert
      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });
  });
}