import 'package:delivery_app/core/network/csrf_token_manager.dart';
import 'package:delivery_app/core/network/interceptors/csrf_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'csrf_interceptor_test.mocks.dart';

@GenerateMocks([CsrfTokenManager, RequestInterceptorHandler])
void main() {
  late CsrfInterceptor csrfInterceptor;
  late MockCsrfTokenManager mockCsrfTokenManager;
  late MockRequestInterceptorHandler mockHandler;

  setUp(() {
    mockCsrfTokenManager = MockCsrfTokenManager();
    mockHandler = MockRequestInterceptorHandler();
    csrfInterceptor = CsrfInterceptor(csrfTokenManager: mockCsrfTokenManager);
  });

  group('CsrfInterceptor', () {
    group('onRequest', () {
      test('should add CSRF token header for POST requests', () async {
        // Arrange
        const testToken = 'csrf-token-123';
        final options = RequestOptions(path: '/api/v1/orders', method: 'POST');
        when(
          mockCsrfTokenManager.getToken(),
        ).thenAnswer((_) async => testToken);

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], testToken);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should add CSRF token header for PUT requests', () async {
        // Arrange
        const testToken = 'csrf-token-456';
        final options = RequestOptions(path: '/api/v1/users/me', method: 'PUT');
        when(
          mockCsrfTokenManager.getToken(),
        ).thenAnswer((_) async => testToken);

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], testToken);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should add CSRF token header for DELETE requests', () async {
        // Arrange
        const testToken = 'csrf-token-789';
        final options = RequestOptions(
          path: '/api/v1/orders/123',
          method: 'DELETE',
        );
        when(
          mockCsrfTokenManager.getToken(),
        ).thenAnswer((_) async => testToken);

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], testToken);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should add CSRF token header for PATCH requests', () async {
        // Arrange
        const testToken = 'csrf-token-patch';
        final options = RequestOptions(
          path: '/api/v1/users/me',
          method: 'PATCH',
        );
        when(
          mockCsrfTokenManager.getToken(),
        ).thenAnswer((_) async => testToken);

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], testToken);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add CSRF token for GET requests', () async {
        // Arrange
        final options = RequestOptions(path: '/api/v1/orders', method: 'GET');

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verifyNever(mockCsrfTokenManager.getToken());
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add CSRF token for HEAD requests', () async {
        // Arrange
        final options = RequestOptions(path: '/api/v1/health', method: 'HEAD');

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verifyNever(mockCsrfTokenManager.getToken());
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add CSRF token for OPTIONS requests', () async {
        // Arrange
        final options = RequestOptions(
          path: '/api/v1/orders',
          method: 'OPTIONS',
        );

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verifyNever(mockCsrfTokenManager.getToken());
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle CSRF token fetch failure gracefully', () async {
        // Arrange
        final options = RequestOptions(path: '/api/v1/orders', method: 'POST');
        when(
          mockCsrfTokenManager.getToken(),
        ).thenThrow(Exception('Failed to get token'));

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert - Should continue without CSRF token
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle null token from manager', () async {
        // Arrange
        final options = RequestOptions(path: '/api/v1/orders', method: 'POST');
        when(
          mockCsrfTokenManager.getTokenOrNull(),
        ).thenAnswer((_) async => null);

        final interceptor = CsrfInterceptor(
          csrfTokenManager: mockCsrfTokenManager,
          useNullableGetter: true,
        );

        // Act
        await interceptor.onRequest(options, mockHandler);

        // Assert - Should continue without CSRF token
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockCsrfTokenManager.getTokenOrNull()).called(1);
        verify(mockHandler.next(options)).called(1);
      });

      test('should skip CSRF for excluded paths', () async {
        // Arrange
        final interceptor = CsrfInterceptor(
          csrfTokenManager: mockCsrfTokenManager,
          excludedPaths: ['/api/v1/users/auth', '/api/v1/auth/refresh'],
        );
        final options = RequestOptions(
          path: '/api/v1/users/auth',
          method: 'POST',
        );

        // Act
        await interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verifyNever(mockCsrfTokenManager.getToken());
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle case-insensitive HTTP methods', () async {
        // Arrange
        const testToken = 'csrf-token-case';
        final options = RequestOptions(
          path: '/api/v1/orders',
          method: 'post', // lowercase
        );
        when(
          mockCsrfTokenManager.getToken(),
        ).thenAnswer((_) async => testToken);

        // Act
        await csrfInterceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], testToken);
        verify(mockCsrfTokenManager.getToken()).called(1);
        verify(mockHandler.next(options)).called(1);
      });
    });
  });
}
