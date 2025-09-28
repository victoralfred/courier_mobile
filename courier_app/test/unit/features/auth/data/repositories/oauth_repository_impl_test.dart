import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_remote_data_source.dart';
import 'package:delivery_app/features/auth/data/repositories/oauth_repository_impl.dart';
import 'package:delivery_app/features/auth/domain/entities/authorization_request.dart';
import 'package:delivery_app/features/auth/domain/entities/oauth_provider.dart';
import 'package:delivery_app/features/auth/domain/entities/pkce_challenge.dart';
import 'package:delivery_app/features/auth/domain/entities/token_response.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/error/failures.dart';

import 'oauth_repository_impl_test.mocks.dart';

@GenerateMocks([
  OAuthRemoteDataSource,
  OAuthLocalDataSource,
])
void main() {
  late OAuthRepositoryImpl repository;
  late MockOAuthRemoteDataSource mockRemoteDataSource;
  late MockOAuthLocalDataSource mockLocalDataSource;

  setUp(() {
    mockRemoteDataSource = MockOAuthRemoteDataSource();
    mockLocalDataSource = MockOAuthLocalDataSource();
    repository = OAuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
    );
  });

  final tProvider = OAuthProvider.google(
    clientId: 'test-client-id',
    redirectUri: 'test://callback',
  );

  final tPkceChallenge = PKCEChallenge(
    codeVerifier: 'test-verifier-string-with-minimum-43-characters',
    codeChallenge: 'test-challenge',
    method: 'S256',
    createdAt: DateTime.now(),
  );

  final tAuthRequest = AuthorizationRequest(
    id: 'test-id',
    provider: tProvider,
    pkceChallenge: tPkceChallenge,
    state: 'test-state',
    authorizationUrl: 'https://oauth.provider.com/auth',
    createdAt: DateTime.now(),
  );

  final tTokenResponse = TokenResponse(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    receivedAt: DateTime.now(),
  );

  final tUser = User(
    id: EntityID('550e8400-e29b-41d4-a716-446655440000'),
    firstName: 'John',
    lastName: 'Doe',
    email: Email('john.doe@example.com'),
    phone: PhoneNumber('+2341234567890'),
    status: UserStatus.active,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('generateAuthorizationRequest', () {
    test('should generate authorization request and store it locally', () async {
      // Arrange
      when(mockRemoteDataSource.generateAuthorizationUrl(any))
          .thenAnswer((_) async => tAuthRequest);
      when(mockLocalDataSource.storeAuthorizationRequest(any))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.generateAuthorizationRequest(tProvider);

      // Assert
      expect(result, isA<Right>());
      verify(mockRemoteDataSource.generateAuthorizationUrl(tProvider));
      verify(mockLocalDataSource.storeAuthorizationRequest(any));
      verifyNoMoreInteractions(mockRemoteDataSource);
      verifyNoMoreInteractions(mockLocalDataSource);
    });

    test('should return ServerFailure when remote data source throws ServerException', () async {
      // Arrange
      when(mockRemoteDataSource.generateAuthorizationUrl(any))
          .thenThrow(const ServerException(message: 'Server error'));

      // Act
      final result = await repository.generateAuthorizationRequest(tProvider);

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Server error');
        },
        (_) => fail('Should return failure'),
      );
    });

    test('should return OAuthFailure when unexpected error occurs', () async {
      // Arrange
      when(mockRemoteDataSource.generateAuthorizationUrl(any))
          .thenThrow(Exception('Unexpected error'));

      // Act
      final result = await repository.generateAuthorizationRequest(tProvider);

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<OAuthFailure>());
        },
        (_) => fail('Should return failure'),
      );
    });
  });

  group('exchangeCodeForToken', () {
    const tCode = 'test-authorization-code';
    const tState = 'test-state';

    test('should exchange code for tokens successfully', () async {
      // Arrange
      when(mockRemoteDataSource.exchangeCodeForToken(
        code: anyNamed('code'),
        codeVerifier: anyNamed('codeVerifier'),
        provider: anyNamed('provider'),
      )).thenAnswer((_) async => tTokenResponse);

      when(mockLocalDataSource.deleteAuthorizationRequest(any))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.exchangeCodeForToken(
        code: tCode,
        state: tState,
        request: tAuthRequest,
      );

      // Assert
      expect(result, isA<Right>());
      verify(mockRemoteDataSource.exchangeCodeForToken(
        code: tCode,
        codeVerifier: tPkceChallenge.codeVerifier,
        provider: tProvider,
      ));
      verify(mockLocalDataSource.deleteAuthorizationRequest(tState));
    });

    test('should return OAuthStateFailure when state does not match', () async {
      // Act
      final result = await repository.exchangeCodeForToken(
        code: tCode,
        state: 'different-state',
        request: tAuthRequest,
      );

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<OAuthStateFailure>());
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRemoteDataSource);
    });

    test('should return OAuthStateFailure when request is expired', () async {
      // Arrange
      final expiredRequest = AuthorizationRequest(
        id: 'test-id',
        provider: tProvider,
        pkceChallenge: tPkceChallenge,
        state: tState,
        authorizationUrl: 'https://oauth.provider.com/auth',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      // Act
      final result = await repository.exchangeCodeForToken(
        code: tCode,
        state: tState,
        request: expiredRequest,
      );

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<OAuthStateFailure>());
        },
        (_) => fail('Should return failure'),
      );
    });
  });

  group('refreshToken', () {
    const tRefreshToken = 'test-refresh-token';

    test('should refresh token successfully', () async {
      // Arrange
      when(mockRemoteDataSource.refreshToken(
        refreshToken: anyNamed('refreshToken'),
        provider: anyNamed('provider'),
      )).thenAnswer((_) async => tTokenResponse);

      // Act
      final result = await repository.refreshToken(tRefreshToken, tProvider);

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (_) => fail('Should return success'),
        (response) {
          expect(response, equals(tTokenResponse));
        },
      );
      verify(mockRemoteDataSource.refreshToken(
        refreshToken: tRefreshToken,
        provider: tProvider,
      ));
    });

    test('should return AuthenticationFailure when token is invalid', () async {
      // Arrange
      when(mockRemoteDataSource.refreshToken(
        refreshToken: anyNamed('refreshToken'),
        provider: anyNamed('provider'),
      )).thenThrow(AuthenticationException(
        message: 'Token expired',
        code: 'TOKEN_EXPIRED',
      ));

      // Act
      final result = await repository.refreshToken(tRefreshToken, tProvider);

      // Assert
      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<AuthenticationFailure>());
          expect(failure.message, 'Token expired');
        },
        (_) => fail('Should return failure'),
      );
    });
  });

  group('fetchUserInfo', () {
    const tAccessToken = 'test-access-token';

    test('should fetch user info successfully', () async {
      // Arrange
      when(mockRemoteDataSource.fetchUserInfo(
        accessToken: anyNamed('accessToken'),
        provider: anyNamed('provider'),
      )).thenAnswer((_) async => tUser);

      // Act
      final result = await repository.fetchUserInfo(tAccessToken, tProvider);

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (_) => fail('Should return success'),
        (user) {
          expect(user, equals(tUser));
        },
      );
    });
  });

  group('getLinkedProviders', () {
    const tUserId = 'test-user-id';
    final tProviders = [OAuthProviderType.google, OAuthProviderType.github];

    test('should get linked providers successfully', () async {
      // Arrange
      when(mockLocalDataSource.getLinkedProviders(any))
          .thenAnswer((_) async => tProviders);

      // Act
      final result = await repository.getLinkedProviders(tUserId);

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (_) => fail('Should return success'),
        (providers) {
          expect(providers, equals(tProviders));
        },
      );
      verify(mockLocalDataSource.getLinkedProviders(tUserId));
    });
  });

  group('cleanupExpiredRequests', () {
    test('should cleanup expired requests successfully', () async {
      // Arrange
      when(mockLocalDataSource.cleanupExpiredRequests())
          .thenAnswer((_) async {});

      // Act
      final result = await repository.cleanupExpiredRequests();

      // Assert
      expect(result, isA<Right>());
      verify(mockLocalDataSource.cleanupExpiredRequests());
    });

    test('should return success even when cleanup fails', () async {
      // Arrange
      when(mockLocalDataSource.cleanupExpiredRequests())
          .thenThrow(Exception('Cleanup failed'));

      // Act
      final result = await repository.cleanupExpiredRequests();

      // Assert
      expect(result, isA<Right>());
    });
  });
}