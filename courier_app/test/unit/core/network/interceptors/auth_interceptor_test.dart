import 'package:delivery_app/core/network/interceptors/auth_interceptor.dart';
import 'package:delivery_app/features/auth/domain/entities/jwt_token.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_interceptor_test.mocks.dart';

@GenerateMocks([RequestInterceptorHandler])
void main() {
  late MockRequestInterceptorHandler mockHandler;

  setUp(() {
    mockHandler = MockRequestInterceptorHandler();
  });

  group('AuthInterceptor', () {
    group('JWT token injection', () {
      test('should add Authorization header when valid token is available',
          () {
        // Arrange
        final validToken = JwtToken(
          token: 'valid_jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => validToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/users', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['Authorization'], 'Bearer valid_jwt_token');
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add Authorization header when token is null', () {
        // Arrange
        final interceptor = AuthInterceptor(
          getAuthToken: () => null,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/users', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('Authorization'), false);
        verify(mockHandler.next(options)).called(1);
      });

      test('should continue request even when token is null', () {
        // Arrange
        final interceptor = AuthInterceptor(
          getAuthToken: () => null,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/users', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Request should continue (graceful degradation)
        verify(mockHandler.next(options)).called(1);
      });
    });

    group('token expiry checking', () {
      test('should add Authorization header when token is not expired', () {
        // Arrange
        final validToken = JwtToken(
          token: 'not_expired_token',
          type: 'Bearer',
          issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          expiresAt: DateTime.now().add(const Duration(minutes: 55)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => validToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['Authorization'], 'Bearer not_expired_token');
        verify(mockHandler.next(options)).called(1);
      });

      test('should add Authorization header even when token is expired', () {
        // Arrange - Token expired 5 minutes ago
        final expiredToken = JwtToken(
          token: 'expired_token',
          type: 'Bearer',
          issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => expiredToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Still adds header (backend will reject, but we log warning)
        expect(options.headers['Authorization'], 'Bearer expired_token');
        verify(mockHandler.next(options)).called(1);
      });

      test('should add Authorization header when token should refresh', () {
        // Arrange - Token expires in 4 minutes (should refresh threshold is 5 min)
        final shouldRefreshToken = JwtToken(
          token: 'should_refresh_token',
          type: 'Bearer',
          issuedAt: DateTime.now().subtract(const Duration(minutes: 56)),
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => shouldRefreshToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Still adds header (logs warning about refresh needed)
        expect(
            options.headers['Authorization'], 'Bearer should_refresh_token');
        verify(mockHandler.next(options)).called(1);
      });
    });

    group('CSRF token injection', () {
      test('should add X-CSRF-Token header for POST requests when available',
          () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          csrfToken: 'csrf_token_123',
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_123',
        );
        final options = RequestOptions(path: '/api/orders', method: 'POST');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_token_123');
        verify(mockHandler.next(options)).called(1);
      });

      test('should add X-CSRF-Token header for PUT requests when available',
          () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_put',
        );
        final options = RequestOptions(path: '/api/users/me', method: 'PUT');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_token_put');
        verify(mockHandler.next(options)).called(1);
      });

      test('should add X-CSRF-Token header for DELETE requests when available',
          () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_delete',
        );
        final options =
            RequestOptions(path: '/api/orders/123', method: 'DELETE');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_token_delete');
        verify(mockHandler.next(options)).called(1);
      });

      test('should add X-CSRF-Token header for PATCH requests when available',
          () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_patch',
        );
        final options = RequestOptions(path: '/api/users/me', method: 'PATCH');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_token_patch');
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add X-CSRF-Token header for GET requests', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_get',
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockHandler.next(options)).called(1);
      });

      test('should NOT add X-CSRF-Token header for HEAD requests', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_token_head',
        );
        final options = RequestOptions(path: '/api/health', method: 'HEAD');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockHandler.next(options)).called(1);
      });

      test('should continue request when CSRF token is null for write operation',
          () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'POST');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Request continues without CSRF token (backend may reject)
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockHandler.next(options)).called(1);
      });
    });

    group('HTTP method case sensitivity', () {
      test('should handle lowercase method names', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_lowercase',
        );
        final options = RequestOptions(path: '/api/orders', method: 'post');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_lowercase');
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle mixed case method names', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_mixedcase',
        );
        final options = RequestOptions(path: '/api/orders', method: 'PoSt');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['X-CSRF-Token'], 'csrf_mixedcase');
        verify(mockHandler.next(options)).called(1);
      });
    });

    group('edge cases', () {
      test('should handle empty CSRF token string', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_token',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => '',
        );
        final options = RequestOptions(path: '/api/orders', method: 'POST');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Empty string should not be added
        expect(options.headers.containsKey('X-CSRF-Token'), false);
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle token with custom type (not Bearer)', () {
        // Arrange
        final customToken = JwtToken(
          token: 'custom_token',
          type: 'Custom',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => customToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert
        expect(options.headers['Authorization'], 'Custom custom_token');
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle both JWT and CSRF tokens together', () {
        // Arrange
        final token = JwtToken(
          token: 'jwt_combined',
          type: 'Bearer',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => token,
          getCsrfToken: () => 'csrf_combined',
        );
        final options = RequestOptions(path: '/api/orders', method: 'POST');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Both headers should be added
        expect(options.headers['Authorization'], 'Bearer jwt_combined');
        expect(options.headers['X-CSRF-Token'], 'csrf_combined');
        verify(mockHandler.next(options)).called(1);
      });

      test('should handle token at exact expiry boundary', () {
        // Arrange - Token expires right now
        final now = DateTime.now();
        final boundaryToken = JwtToken(
          token: 'boundary_token',
          type: 'Bearer',
          issuedAt: now.subtract(const Duration(hours: 1)),
          expiresAt: now,
        );
        final interceptor = AuthInterceptor(
          getAuthToken: () => boundaryToken,
          getCsrfToken: () => null,
        );
        final options = RequestOptions(path: '/api/orders', method: 'GET');

        // Act
        interceptor.onRequest(options, mockHandler);

        // Assert - Should still add header (token.isExpired uses isAfter)
        expect(options.headers['Authorization'], 'Bearer boundary_token');
        verify(mockHandler.next(options)).called(1);
      });
    });
  });
}
