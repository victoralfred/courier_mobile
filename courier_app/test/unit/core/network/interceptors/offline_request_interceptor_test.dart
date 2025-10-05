import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:delivery_app/core/network/interceptors/offline_request_interceptor.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';
import 'package:delivery_app/core/network/offline_request_queue.dart';

@GenerateMocks([
  ConnectivityService,
  OfflineRequestQueue,
  RequestInterceptorHandler,
])
import 'offline_request_interceptor_test.mocks.dart';

void main() {
  late OfflineRequestInterceptor interceptor;
  late MockConnectivityService mockConnectivityService;
  late MockOfflineRequestQueue mockOfflineQueue;
  late MockRequestInterceptorHandler mockHandler;

  setUp(() {
    mockConnectivityService = MockConnectivityService();
    mockOfflineQueue = MockOfflineRequestQueue();
    mockHandler = MockRequestInterceptorHandler();

    interceptor = OfflineRequestInterceptor(
      connectivityService: mockConnectivityService,
      offlineQueue: mockOfflineQueue,
    );
  });

  group('onRequest - Online', () {
    test('should pass through request when online', () async {
      // Arrange
      final options = RequestOptions(
        method: 'GET',
        path: '/api/v1/orders',
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockHandler.next(options)).called(1);
      verifyNever(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      ));
    });
  });

  group('onRequest - Offline - Write Operations', () {
    test('should queue POST request when offline', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
        extra: {'request_id': 'req-123'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: anyNamed('priority'),
      )).called(1);

      verify(mockHandler.resolve(any)).called(1);
    });

    test('should queue PUT request when offline', () async {
      // Arrange
      final options = RequestOptions(
        method: 'PUT',
        path: '/api/v1/orders/123',
        data: {'status': 'completed'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 2);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: anyNamed('priority'),
      )).called(1);
    });

    test('should queue PATCH request when offline', () async {
      // Arrange
      final options = RequestOptions(
        method: 'PATCH',
        path: '/api/v1/users/profile',
        data: {'name': 'Updated Name'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 3);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: anyNamed('priority'),
      )).called(1);
    });

    test('should queue DELETE request when offline', () async {
      // Arrange
      final options = RequestOptions(
        method: 'DELETE',
        path: '/api/v1/orders/123',
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 4);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: anyNamed('priority'),
      )).called(1);
    });

    test('should return 202 Accepted response when request queued', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 42);

      Response? resolvedResponse;
      when(mockHandler.resolve(any)).thenAnswer((invocation) {
        resolvedResponse = invocation.positionalArguments[0] as Response;
      });

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      expect(resolvedResponse, isNotNull);
      expect(resolvedResponse!.statusCode, 202);
      expect(resolvedResponse!.data['offline'], true);
      expect(resolvedResponse!.data['queueId'], 42);
    });
  });

  group('onRequest - Offline - Read Operations', () {
    test('should reject GET request when offline', () async {
      // Arrange
      final options = RequestOptions(
        method: 'GET',
        path: '/api/v1/orders',
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);

      DioException? rejectedException;
      when(mockHandler.reject(any)).thenAnswer((invocation) {
        rejectedException = invocation.positionalArguments[0] as DioException;
      });

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      expect(rejectedException, isNotNull);
      expect(rejectedException!.type, DioExceptionType.connectionError);
      expect(rejectedException!.response?.statusCode, 0);
      verifyNever(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      ));
    });

    test('should include offline error message in rejection', () async {
      // Arrange
      final options = RequestOptions(
        method: 'GET',
        path: '/api/v1/orders',
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);

      DioException? rejectedException;
      when(mockHandler.reject(any)).thenAnswer((invocation) {
        rejectedException = invocation.positionalArguments[0] as DioException;
      });

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      expect(rejectedException!.response?.data['error']['code'], 'OFFLINE');
      expect(
        rejectedException!.response?.data['error']['message'],
        contains('No internet connection'),
      );
    });
  });

  group('Priority Determination', () {
    test('should assign CRITICAL priority to order endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.critical,
      )).called(1);
    });

    test('should assign CRITICAL priority to payment endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/payments',
        data: {'amount': 100},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.critical,
      )).called(1);
    });

    test('should assign HIGH priority to location endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/drivers/location',
        data: {'lat': 1.0, 'lng': 2.0},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.high,
      )).called(1);
    });

    test('should assign HIGH priority to status endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'PUT',
        path: '/api/v1/orders/123/status',
        data: {'status': 'delivered'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.high,
      )).called(1);
    });

    test('should assign LOW priority to analytics endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/analytics/events',
        data: {'event': 'page_view'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.low,
      )).called(1);
    });

    test('should assign NORMAL priority to other endpoints', () async {
      // Arrange
      final options = RequestOptions(
        method: 'PUT',
        path: '/api/v1/users/profile',
        data: {'name': 'Test User'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 1);

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      verify(mockOfflineQueue.enqueue(
        requestOptions: options,
        priority: RequestPriority.normal,
      )).called(1);
    });
  });

  group('Error Handling', () {
    test('should reject request when queue fails', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      )).thenThrow(QueueFullException('Queue is full'));

      DioException? rejectedException;
      when(mockHandler.reject(any)).thenAnswer((invocation) {
        rejectedException = invocation.positionalArguments[0] as DioException;
      });

      // Act
      interceptor.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      expect(rejectedException, isNotNull);
      expect(rejectedException!.type, DioExceptionType.unknown);
      expect(rejectedException!.error, isA<QueueFullException>());
    });
  });

  group('queueWriteOperations flag', () {
    test('should reject write operations when queueWriteOperations is false',
        () async {
      // Arrange
      final interceptorNoQueue = OfflineRequestInterceptor(
        connectivityService: mockConnectivityService,
        offlineQueue: mockOfflineQueue,
        queueWriteOperations: false,
      );

      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);

      DioException? rejectedException;
      when(mockHandler.reject(any)).thenAnswer((invocation) {
        rejectedException = invocation.positionalArguments[0] as DioException;
      });

      // Act
      interceptorNoQueue.onRequest(options, mockHandler);
      await Future.delayed(Duration.zero);

      // Assert
      expect(rejectedException, isNotNull);
      expect(rejectedException!.type, DioExceptionType.connectionError);
      verifyNever(mockOfflineQueue.enqueue(
        requestOptions: anyNamed('requestOptions'),
        priority: anyNamed('priority'),
      ));
    });
  });
}
