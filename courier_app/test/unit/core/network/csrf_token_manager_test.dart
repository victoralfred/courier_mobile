import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/network/csrf_token_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'csrf_token_manager_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late CsrfTokenManager csrfTokenManager;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    csrfTokenManager = CsrfTokenManager(
      dio: mockDio,
      getAuthToken: null, // No auth token for these tests
    );
  });

  group('CsrfTokenManager', () {
    const testToken = 'test-csrf-token-123';
    const apiPath = '/auth/csrf';

    group('getToken', () {
      test('should fetch and cache CSRF token from API', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        final result = await csrfTokenManager.getToken();

        // Assert
        expect(result, testToken);
        verify(mockDio.get(apiPath, options: anyNamed('options'))).called(1);
      });

      test('should return cached token if available and not expired', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act - First call fetches from API
        await csrfTokenManager.getToken();
        // Second call should return cached value
        final result = await csrfTokenManager.getToken();

        // Assert
        expect(result, testToken);
        // API should only be called once (cached on second call)
        verify(mockDio.get(apiPath, options: anyNamed('options'))).called(1);
      });

      test('should refresh token if cache is expired', () async {
        // Arrange
        final response1 = Response(
          data: {'success': true, 'data': {'token': 'token-1'}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response1);

        // Act - First call
        final firstResult = await csrfTokenManager.getToken();
        // Force expiration by clearing cache
        csrfTokenManager.clearCache();
        // Second call should fetch new token
        final secondResult = await csrfTokenManager.getToken();

        // Assert
        expect(firstResult, 'token-1');
        expect(secondResult, 'token-1');
        verify(mockDio.get(apiPath, options: anyNamed('options'))).called(2);
      });

      test('should throw ServerException on API error', () async {
        // Arrange
        when(mockDio.get(apiPath, options: anyNamed('options'))).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: apiPath),
            response: Response(
              statusCode: 500,
              data: {'error': 'Internal Server Error'},
              requestOptions: RequestOptions(path: apiPath),
            ),
          ),
        );

        // Act & Assert
        expect(
          () => csrfTokenManager.getToken(),
          throwsA(isA<ServerException>()),
        );
      });

      test('should throw NetworkException on connection error', () async {
        // Arrange
        when(mockDio.get(apiPath, options: anyNamed('options'))).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: apiPath),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act & Assert
        expect(
          () => csrfTokenManager.getToken(),
          throwsA(isA<NetworkException>()),
        );
      });

      test('should throw ServerException if token not in response', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {}}, // Missing token
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act & Assert
        expect(
          () => csrfTokenManager.getToken(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              AppStrings.errorCsrfTokenNotFound,
            ),
          ),
        );
      });
    });

    group('getTokenOrNull', () {
      test('should return token if available', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        final result = await csrfTokenManager.getTokenOrNull();

        // Assert
        expect(result, testToken);
      });

      test('should return null on error instead of throwing', () async {
        // Arrange
        when(mockDio.get(apiPath, options: anyNamed('options'))).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: apiPath),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        // Act
        final result = await csrfTokenManager.getTokenOrNull();

        // Assert
        expect(result, isNull);
      });
    });

    group('clearCache', () {
      test('should clear cached token', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        await csrfTokenManager.getToken();
        csrfTokenManager.clearCache();
        await csrfTokenManager.getToken();

        // Assert
        // Should fetch twice since cache was cleared
        verify(mockDio.get(apiPath, options: anyNamed('options'))).called(2);
      });
    });

    group('hasCachedToken', () {
      test('should return false when no token is cached', () {
        // Act & Assert
        expect(csrfTokenManager.hasCachedToken(), false);
      });

      test('should return true when token is cached', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        await csrfTokenManager.getToken();

        // Assert
        expect(csrfTokenManager.hasCachedToken(), true);
      });

      test('should return false after cache is cleared', () async {
        // Arrange
        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );
        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        await csrfTokenManager.getToken();
        csrfTokenManager.clearCache();

        // Assert
        expect(csrfTokenManager.hasCachedToken(), false);
      });
    });

    group('with auth token', () {
      test('should include auth token in request when provided', () async {
        // Arrange
        const authToken = 'test-auth-token';
        final csrfTokenManagerWithAuth = CsrfTokenManager(
          dio: mockDio,
          getAuthToken: () => authToken,
        );

        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );

        when(mockDio.get(
          apiPath,
          options: argThat(
            isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization header',
              'Bearer $authToken',
            ),
            named: 'options',
          ),
        )).thenAnswer((_) async => response);

        // Act
        final result = await csrfTokenManagerWithAuth.getToken();

        // Assert
        expect(result, testToken);
        verify(mockDio.get(
          apiPath,
          options: argThat(
            isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization header',
              'Bearer $authToken',
            ),
            named: 'options',
          ),
        )).called(1);
      });

      test('should not include auth header when getAuthToken returns null', () async {
        // Arrange
        final csrfTokenManagerWithAuth = CsrfTokenManager(
          dio: mockDio,
          getAuthToken: () => null,
        );

        final response = Response(
          data: {'success': true, 'data': {'token': testToken}},
          statusCode: 200,
          requestOptions: RequestOptions(path: apiPath),
        );

        when(mockDio.get(apiPath, options: anyNamed('options')))
            .thenAnswer((_) async => response);

        // Act
        final result = await csrfTokenManagerWithAuth.getToken();

        // Assert
        expect(result, testToken);
      });
    });
  });
}
