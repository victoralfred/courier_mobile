import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:delivery_app/core/network/offline_request_queue.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';

@GenerateMocks([
  AppDatabase,
  SyncQueueDao,
  ConnectivityService,
])
import 'offline_request_queue_test.mocks.dart';

void main() {
  late OfflineRequestQueue queue;
  late MockAppDatabase mockDatabase;
  late MockSyncQueueDao mockSyncQueueDao;
  late MockConnectivityService mockConnectivityService;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockSyncQueueDao = MockSyncQueueDao();
    mockConnectivityService = MockConnectivityService();

    when(mockDatabase.syncQueueDao).thenReturn(mockSyncQueueDao);

    // Create Dio with mock adapter for testing
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    dioAdapter = DioAdapter(dio: dio);

    queue = OfflineRequestQueue(
      database: mockDatabase,
      connectivityService: mockConnectivityService,
      maxQueueSize: 10,
      maxRetries: 3,
      dio: dio,
    );
  });

  group('enqueue', () {
    test('should enqueue request successfully', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
        extra: {'request_id': 'req-123'},
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async => 1);

      // Act
      final queueId = await queue.enqueue(
        requestOptions: options,
        priority: RequestPriority.high,
      );

      // Assert
      expect(queueId, 1);
      verify(mockSyncQueueDao.addToQueue(
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: anyNamed('payload'),
      )).called(1);
    });

    test('should throw QueueFullException when queue is full', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      // Create 10 mock queue items (maxQueueSize = 10)
      final mockItems = List.generate(
        10,
        (i) => SyncQueueTableData(
          id: i,
          entityType: 'order',
          entityId: 'id-$i',
          operation: 'create',
          payload: '{}',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          lastAttemptAt: null,
          completedAt: null,
        ),
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => mockItems);

      // Act & Assert
      expect(
        () => queue.enqueue(requestOptions: options),
        throwsA(isA<QueueFullException>()),
      );
    });

    test('should set correct priority in payload', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
        data: {'item': 'test'},
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      String? capturedPayload;
      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((invocation) async {
        capturedPayload = invocation.namedArguments[#payload] as String;
        return 1;
      });

      // Act
      await queue.enqueue(
        requestOptions: options,
        priority: RequestPriority.critical,
      );

      // Assert
      expect(capturedPayload, isNotNull);
      expect(capturedPayload, contains('"priority":3'));
    });

    test('should set TTL in payload', () async {
      // Arrange
      final options = RequestOptions(
        method: 'POST',
        path: '/api/v1/orders',
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      String? capturedPayload;
      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((invocation) async {
        capturedPayload = invocation.namedArguments[#payload] as String;
        return 1;
      });

      // Act
      await queue.enqueue(
        requestOptions: options,
        ttl: const Duration(hours: 12),
      );

      // Assert
      expect(capturedPayload, isNotNull);
      expect(capturedPayload, contains('"expiresAt"'));
    });
  });

  group('processQueue', () {
    test('should skip processing when offline', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);

      // Act
      final processed = await queue.processQueue();

      // Assert
      expect(processed, 0);
      verifyNever(mockSyncQueueDao.getPendingOperations());
    });

    test('should skip processing when already processing', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);
      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      // Act - Start two processes concurrently
      final future1 = queue.processQueue();
      final future2 = queue.processQueue();

      final results = await Future.wait([future1, future2]);

      // Assert - One should process, one should skip
      expect(results.where((r) => r == 0).length, greaterThanOrEqualTo(1));
    });

    test('should process pending requests successfully', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      // Mock HTTP response
      dioAdapter.onPost(
        '/api/v1/orders',
        (server) => server.reply(200, {'success': true}),
        data: {"item": "test"},
      );

      final now = DateTime.now();
      final mockItem = SyncQueueTableData(
        id: 1,
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/api/v1/orders",
          "headers": {},
          "data": {"item": "test"},
          "queryParameters": {},
          "extra": {},
          "priority": 2,
          "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
        }''',
        status: 'pending',
        retryCount: 0,
        lastError: null,
        createdAt: now,
        lastAttemptAt: null,
        completedAt: null,
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => [mockItem]);

      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.markAsCompleted(any)).thenAnswer((_) async {});

      // Act
      final processed = await queue.processQueue();

      // Assert
      expect(processed, 1);
      verify(mockSyncQueueDao.markAsSyncing(1)).called(1);
      verify(mockSyncQueueDao.markAsCompleted(1)).called(1);
    });

    test('should remove expired requests', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      final now = DateTime.now();
      final expiredItem = SyncQueueTableData(
        id: 1,
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/api/v1/orders",
          "expiresAt": "${now.subtract(const Duration(hours: 1)).toIso8601String()}"
        }''',
        status: 'pending',
        retryCount: 0,
        lastError: null,
        createdAt: now.subtract(const Duration(hours: 25)),
        lastAttemptAt: null,
        completedAt: null,
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => [expiredItem]);

      when(mockSyncQueueDao.deleteOperation(any)).thenAnswer((_) async => 1);

      // Act
      final processed = await queue.processQueue();

      // Assert
      expect(processed, 0);
      verify(mockSyncQueueDao.deleteOperation(1)).called(1);
    });

    test('should remove requests that exceed max retries', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      final now = DateTime.now();
      final maxRetriedItem = SyncQueueTableData(
        id: 1,
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/api/v1/orders",
          "headers": {},
          "data": {},
          "queryParameters": {},
          "extra": {},
          "priority": 1,
          "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
        }''',
        status: 'pending',
        retryCount: 3, // maxRetries = 3
        lastError: 'Previous error',
        createdAt: now,
        lastAttemptAt: now,
        completedAt: null,
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => [maxRetriedItem]);

      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.deleteOperation(any)).thenAnswer((_) async => 1);

      // Act
      final processed = await queue.processQueue();

      // Assert
      expect(processed, 0);
      verify(mockSyncQueueDao.deleteOperation(1)).called(1);
    });

    test('should process requests in priority order', () async {
      // Arrange
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      // Mock HTTP responses for both routes
      dioAdapter.onPost(
        '/api/v1/orders',
        (server) => server.reply(200, {'success': true}),
        data: {},
      );
      dioAdapter.onPost(
        '/api/v1/analytics',
        (server) => server.reply(200, {'success': true}),
        data: {},
      );

      final now = DateTime.now();
      final lowPriorityItem = SyncQueueTableData(
        id: 1,
        entityType: 'order',
        entityId: 'low',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/api/v1/analytics",
          "headers": {},
          "data": {},
          "queryParameters": {},
          "extra": {},
          "priority": 0,
          "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
        }''',
        status: 'pending',
        retryCount: 0,
        lastError: null,
        createdAt: now,
        lastAttemptAt: null,
        completedAt: null,
      );

      final highPriorityItem = SyncQueueTableData(
        id: 2,
        entityType: 'order',
        entityId: 'high',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/api/v1/orders",
          "headers": {},
          "data": {},
          "queryParameters": {},
          "extra": {},
          "priority": 3,
          "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
        }''',
        status: 'pending',
        retryCount: 0,
        lastError: null,
        createdAt: now.add(const Duration(seconds: 10)),
        lastAttemptAt: null,
        completedAt: null,
      );

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => [lowPriorityItem, highPriorityItem]);

      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.markAsCompleted(any)).thenAnswer((_) async {});

      final List<int> processedOrder = [];
      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((invocation) {
        processedOrder.add(invocation.positionalArguments[0] as int);
        return Future.value();
      });

      // Act
      await queue.processQueue();

      // Assert - High priority should be processed first
      expect(processedOrder, [2, 1]);
    });
  });

  group('getStats', () {
    test('should return correct queue statistics', () async {
      // Arrange
      final now = DateTime.now();
      final items = [
        SyncQueueTableData(
          id: 1,
          entityType: 'order',
          entityId: 'critical-1',
          operation: 'post',
          payload: '''{
            "priority": 3,
            "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now,
          lastAttemptAt: null,
          completedAt: null,
        ),
        SyncQueueTableData(
          id: 2,
          entityType: 'order',
          entityId: 'high-1',
          operation: 'post',
          payload: '''{
            "priority": 2,
            "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now,
          lastAttemptAt: null,
          completedAt: null,
        ),
        SyncQueueTableData(
          id: 3,
          entityType: 'order',
          entityId: 'expired-1',
          operation: 'post',
          payload: '''{
            "priority": 1,
            "expiresAt": "${now.subtract(const Duration(hours: 1)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now,
          lastAttemptAt: null,
          completedAt: null,
        ),
      ];

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => items);

      // Act
      final stats = await queue.getStats();

      // Assert
      expect(stats.totalPending, 3);
      expect(stats.criticalCount, 1);
      expect(stats.highCount, 1);
      expect(stats.expiredCount, 1);
    });
  });

  group('clearQueue', () {
    test('should delete all pending requests', () async {
      // Arrange
      final mockItems = [
        SyncQueueTableData(
          id: 1,
          entityType: 'order',
          entityId: 'id-1',
          operation: 'post',
          payload: '{}',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          lastAttemptAt: null,
          completedAt: null,
        ),
        SyncQueueTableData(
          id: 2,
          entityType: 'order',
          entityId: 'id-2',
          operation: 'post',
          payload: '{}',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          lastAttemptAt: null,
          completedAt: null,
        ),
      ];

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => mockItems);

      when(mockSyncQueueDao.deleteOperation(any)).thenAnswer((_) async => 1);

      // Act
      await queue.clearQueue();

      // Assert
      verify(mockSyncQueueDao.deleteOperation(1)).called(1);
      verify(mockSyncQueueDao.deleteOperation(2)).called(1);
    });
  });
}
