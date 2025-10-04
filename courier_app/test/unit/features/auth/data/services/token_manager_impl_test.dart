import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:delivery_app/features/auth/data/services/token_manager_impl.dart';
import 'package:delivery_app/features/auth/data/datasources/token_local_data_source.dart';
import 'package:delivery_app/features/auth/domain/entities/jwt_token.dart';
import 'package:delivery_app/core/network/api_client.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

@GenerateMocks([
  TokenLocalDataSource,
  ApiClient,
])
import 'token_manager_impl_test.mocks.dart';

void main() {
  late TokenManagerImpl tokenManager;
  late MockTokenLocalDataSource mockLocalDataSource;
  late MockApiClient mockApiClient;

  setUp(() {
    mockLocalDataSource = MockTokenLocalDataSource();
    mockApiClient = MockApiClient();
    tokenManager = TokenManagerImpl(
      localDataSource: mockLocalDataSource,
      apiClient: mockApiClient,
    );
  });

  tearDown(() {
    tokenManager.dispose();
  });

  final tValidToken = JwtToken(
    token: 'valid-access-token',
    type: 'Bearer',
    issuedAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    refreshToken: 'valid-refresh-token',
    csrfToken: 'valid-csrf-token',
  );

  final tExpiredToken = JwtToken(
    token: 'expired-access-token',
    type: 'Bearer',
    issuedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    refreshToken: 'valid-refresh-token',
    csrfToken: 'valid-csrf-token',
  );

  final tTokenNearExpiry = JwtToken(
    token: 'near-expiry-token',
    type: 'Bearer',
    issuedAt: DateTime.now().subtract(const Duration(minutes: 11)),
    expiresAt: DateTime.now().add(const Duration(minutes: 4)),
    refreshToken: 'valid-refresh-token',
    csrfToken: 'valid-csrf-token',
  );

  group('getAccessToken', () {
    test('should return token when valid token exists', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tValidToken);

      // Act
      final result = await tokenManager.getAccessToken();

      // Assert
      expect(result, Right(tValidToken.token));
      verify(mockLocalDataSource.getToken());
    });

    test('should return failure when no token exists', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => null);

      // Act
      final result = await tokenManager.getAccessToken();

      // Assert
      expect(result, const Left(AuthenticationFailure(
        message: AppStrings.errorTokenNotFound,
        code: AppStrings.errorCodeNoToken,
      )));
    });

    test('should trigger refresh when token is near expiry', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tTokenNearExpiry);

      // Act
      await tokenManager.getAccessToken();

      // Assert
      verify(mockLocalDataSource.getToken());
      // Token should be returned immediately while refresh happens in background
      expect(await tokenManager.getAccessToken(), Right(tTokenNearExpiry.token));
    });

    test('should refresh token when expired with refresh token', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tExpiredToken);

      final newToken = JwtToken(
        token: 'new-access-token',
        type: 'Bearer',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        refreshToken: 'new-refresh-token',
        csrfToken: 'valid-csrf-token',
      );

      when(mockApiClient.post(
        '/api/v1/auth/refresh',
        data: anyNamed('data'),
      )).thenAnswer((_) async => Response(
        data: {
          'access_token': newToken.token,
          'token_type': newToken.type,
          'expires_in': 900,
          'refresh_token': newToken.refreshToken,
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
      ));

      when(mockLocalDataSource.storeToken(any))
          .thenAnswer((_) async => null);

      when(mockApiClient.setAuthToken(any, refreshToken: anyNamed('refreshToken')))
          .thenReturn(null);

      // Act
      final result = await tokenManager.getAccessToken();

      // Assert
      expect(result, Right(newToken.token));
      verify(mockLocalDataSource.storeToken(any));
      verify(mockApiClient.setAuthToken(newToken.token, refreshToken: newToken.refreshToken));
    });
  });

  group('getCsrfToken', () {
    test('should return stored CSRF token when available', () async {
      // Arrange
      when(mockLocalDataSource.getCsrfToken())
          .thenAnswer((_) async => 'stored-csrf-token');

      // Act
      final result = await tokenManager.getCsrfToken();

      // Assert
      expect(result, const Right('stored-csrf-token'));
      verify(mockLocalDataSource.getCsrfToken());
      verifyNever(mockApiClient.get(any));
    });

    test('should fetch new CSRF token when not available locally', () async {
      // Arrange
      when(mockLocalDataSource.getCsrfToken())
          .thenAnswer((_) async => null);

      when(mockApiClient.get('/api/v1/auth/csrf'))
          .thenAnswer((_) async => Response(
        data: {'csrf_token': 'new-csrf-token'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/v1/auth/csrf'),
      ));

      when(mockLocalDataSource.storeCsrfToken(any))
          .thenAnswer((_) async => null);

      // Act
      final result = await tokenManager.getCsrfToken();

      // Assert
      expect(result, const Right('new-csrf-token'));
      verify(mockLocalDataSource.getCsrfToken());
      verify(mockApiClient.get('/api/v1/auth/csrf'));
      verify(mockLocalDataSource.storeCsrfToken('new-csrf-token'));
    });

    test('should return failure when API call fails', () async {
      // Arrange
      when(mockLocalDataSource.getCsrfToken())
          .thenAnswer((_) async => null);

      when(mockApiClient.get('/api/v1/auth/csrf'))
          .thenThrow(DioException(
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/api/v1/auth/csrf'),
        ),
        requestOptions: RequestOptions(path: '/api/v1/auth/csrf'),
      ));

      // Act
      final result = await tokenManager.getCsrfToken();

      // Assert
      expect(result, const Left(AuthenticationFailure(
        message: AppStrings.errorUnauthorized,
        code: AppStrings.errorCodeSessionExpired,
      )));
    });
  });

  group('refreshToken', () {
    test('should successfully refresh token', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tExpiredToken);

      when(mockApiClient.post(
        '/api/v1/auth/refresh',
        data: anyNamed('data'),
      )).thenAnswer((_) async => Response(
        data: {
          'access_token': 'new-access-token',
          'token_type': 'Bearer',
          'expires_in': 900,
          'refresh_token': 'new-refresh-token',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
      ));

      when(mockLocalDataSource.storeToken(any))
          .thenAnswer((_) async => null);

      when(mockApiClient.setAuthToken(any))
          .thenReturn(null);

      // Act
      final result = await tokenManager.refreshToken();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should succeed'),
        (token) {
          expect(token.token, 'new-access-token');
          expect(token.refreshToken, 'new-refresh-token');
        },
      );
    });

    test('should return failure when no refresh token available', () async {
      // Arrange
      final tokenWithoutRefresh = JwtToken(
        token: 'access-token',
        type: 'Bearer',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        refreshToken: null,
        csrfToken: null,
      );

      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tokenWithoutRefresh);

      // Act
      final result = await tokenManager.refreshToken();

      // Assert
      expect(result, const Left(AuthenticationFailure(
        message: AppStrings.errorNoRefreshToken,
        code: AppStrings.errorCodeNoToken,
      )));
    });

    test('should clear tokens when refresh fails with 401', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tExpiredToken);

      when(mockApiClient.post(
        '/api/v1/auth/refresh',
        data: anyNamed('data'),
      )).thenThrow(DioException(
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
        ),
        requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
      ));

      when(mockLocalDataSource.clearAll())
          .thenAnswer((_) async => null);

      when(mockApiClient.clearTokens())
          .thenReturn(null);

      // Act
      final result = await tokenManager.refreshToken();

      // Assert
      expect(result, const Left(AuthenticationFailure(
        message: AppStrings.errorInvalidRefreshToken,
        code: AppStrings.errorCodeInvalidToken,
      )));
      verify(mockLocalDataSource.clearAll());
      verify(mockApiClient.clearTokens());
    });
  });

  group('isAuthenticated', () {
    test('should return true when valid token exists', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tValidToken);

      // Act
      final result = await tokenManager.isAuthenticated();

      // Assert
      expect(result, true);
    });

    test('should return false when no token exists', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => null);

      // Act
      final result = await tokenManager.isAuthenticated();

      // Assert
      expect(result, false);
    });

    test('should attempt refresh when token is expired with refresh token', () async {
      // Arrange
      when(mockLocalDataSource.getToken())
          .thenAnswer((_) async => tExpiredToken);

      when(mockApiClient.post(
        '/api/v1/auth/refresh',
        data: anyNamed('data'),
      )).thenAnswer((_) async => Response(
        data: {
          'access_token': 'new-access-token',
          'token_type': 'Bearer',
          'expires_in': 900,
          'refresh_token': 'new-refresh-token',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
      ));

      when(mockLocalDataSource.storeToken(any))
          .thenAnswer((_) async => null);

      when(mockApiClient.setAuthToken(any))
          .thenReturn(null);

      // Act
      final result = await tokenManager.isAuthenticated();

      // Assert
      expect(result, true);
      verify(mockApiClient.post('/api/v1/auth/refresh', data: anyNamed('data')));
    });
  });

  group('storeToken', () {
    test('should store token and update API client', () async {
      // Arrange
      when(mockLocalDataSource.storeToken(any))
          .thenAnswer((_) async => null);

      when(mockApiClient.setAuthToken(any, refreshToken: anyNamed('refreshToken')))
          .thenReturn(null);

      // Act
      final result = await tokenManager.storeToken(tValidToken);

      // Assert
      expect(result, const Right(unit));
      verify(mockLocalDataSource.storeToken(tValidToken));
      verify(mockApiClient.setAuthToken(tValidToken.token, refreshToken: tValidToken.refreshToken));
      // Note: CSRF tokens are now managed automatically by CsrfInterceptor
    });
  });

  group('clearTokens', () {
    test('should clear all tokens and stop auto refresh', () async {
      // Arrange
      when(mockLocalDataSource.clearAll())
          .thenAnswer((_) async => null);

      when(mockApiClient.clearTokens())
          .thenReturn(null);

      // Act
      final result = await tokenManager.clearTokens();

      // Assert
      expect(result, const Right(unit));
      verify(mockLocalDataSource.clearAll());
      verify(mockApiClient.clearTokens());
    });
  });
}