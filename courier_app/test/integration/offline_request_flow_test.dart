import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:delivery_app/core/network/offline_request_queue.dart';
import 'package:delivery_app/core/network/interceptors/offline_request_interceptor.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';

@GenerateMocks([
  AppDatabase,
  SyncQueueDao,
  ConnectivityService,
])
import '../unit/core/network/offline_request_queue_test.mocks.dart';

void main() {
  group('Offline Request Flow Integration Tests', () {
    late OfflineRequestQueue queue;
    late OfflineRequestInterceptor interceptor;
    late Dio dio;
    late MockAppDatabase mockDatabase;
    late MockSyncQueueDao mockSyncQueueDao;
    late MockConnectivityService mockConnectivityService;

    setUp(() {
      mockDatabase = MockAppDatabase();
      mockSyncQueueDao = MockSyncQueueDao();
      mockConnectivityService = MockConnectivityService();

      when(mockDatabase.syncQueueDao).thenReturn(mockSyncQueueDao);

      queue = OfflineRequestQueue(
        database: mockDatabase,
        connectivityService: mockConnectivityService,
      );

      interceptor = OfflineRequestInterceptor(
        connectivityService: mockConnectivityService,
        offlineQueue: queue,
      );

      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(interceptor);
    });

    test('should queue request when offline and process when online', () async {
      // Arrange - Start offline
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      int queueId = 0;
      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((invocation) async {
        queueId = 1;
        return queueId;
      });

      // Act 1: Make request while offline
      final response = await dio.post(
        '/orders',
        data: {'item': 'test'},
        options: Options(extra: {'request_id': 'req-123'}),
      );

      // Assert 1: Request was queued
      expect(response.statusCode, 202);
      expect(response.data['offline'], true);
      expect(response.data['queueId'], 1);
      verify(mockSyncQueueDao.addToQueue(
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: anyNamed('payload'),
      )).called(1);

      // Arrange - Go online
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      final now = DateTime.now();
      final queuedItem = SyncQueueData(
        id: queueId,
        entityType: 'order',
        entityId: 'req-123',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/orders",
          "headers": {"content-type": "application/json"},
          "data": {"item": "test"},
          "queryParameters": {},
          "extra": {"request_id": "req-123"},
          "priority": 3,
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
          .thenAnswer((_) async => [queuedItem]);

      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.markAsCompleted(any)).thenAnswer((_) async {});

      // Act 2: Process queue when online
      final processed = await queue.processQueue();

      // Assert 2: Request was processed
      expect(processed, 1);
      verify(mockSyncQueueDao.markAsSyncing(queueId)).called(1);
      verify(mockSyncQueueDao.markAsCompleted(queueId)).called(1);
    });

    test('should handle multiple queued requests in priority order', () async {
      // Arrange - Offline
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      int nextQueueId = 1;
      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async => nextQueueId++);

      // Act 1: Queue low priority request
      await dio.post(
        '/analytics/events',
        data: {'event': 'click'},
        options: Options(extra: {'request_id': 'req-low'}),
      );

      // Act 2: Queue critical priority request
      await dio.post(
        '/orders',
        data: {'item': 'urgent'},
        options: Options(extra: {'request_id': 'req-critical'}),
      );

      // Act 3: Queue normal priority request
      await dio.put(
        '/users/profile',
        data: {'name': 'Test'},
        options: Options(extra: {'request_id': 'req-normal'}),
      );

      // Assert: All queued
      verify(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).called(3);

      // Arrange - Go online and prepare queue items
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      final now = DateTime.now();
      final queueItems = [
        // Low priority (created first)
        SyncQueueData(
          id: 1,
          entityType: 'unknown',
          entityId: 'req-low',
          operation: 'post',
          payload: '''{
            "method": "POST",
            "path": "/analytics/events",
            "headers": {},
            "data": {"event": "click"},
            "queryParameters": {},
            "extra": {"request_id": "req-low"},
            "priority": 0,
            "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now,
          lastAttemptAt: null,
          completedAt: null,
        ),
        // Critical priority (created second)
        SyncQueueData(
          id: 2,
          entityType: 'order',
          entityId: 'req-critical',
          operation: 'post',
          payload: '''{
            "method": "POST",
            "path": "/orders",
            "headers": {},
            "data": {"item": "urgent"},
            "queryParameters": {},
            "extra": {"request_id": "req-critical"},
            "priority": 3,
            "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now.add(const Duration(seconds: 1)),
          lastAttemptAt: null,
          completedAt: null,
        ),
        // Normal priority (created third)
        SyncQueueData(
          id: 3,
          entityType: 'user',
          entityId: 'req-normal',
          operation: 'put',
          payload: '''{
            "method": "PUT",
            "path": "/users/profile",
            "headers": {},
            "data": {"name": "Test"},
            "queryParameters": {},
            "extra": {"request_id": "req-normal"},
            "priority": 1,
            "expiresAt": "${now.add(const Duration(hours: 24)).toIso8601String()}"
          }''',
          status: 'pending',
          retryCount: 0,
          lastError: null,
          createdAt: now.add(const Duration(seconds: 2)),
          lastAttemptAt: null,
          completedAt: null,
        ),
      ];

      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => queueItems);

      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.markAsCompleted(any)).thenAnswer((_) async {});

      final List<int> processedOrder = [];
      when(mockSyncQueueDao.markAsSyncing(any)).thenAnswer((invocation) {
        processedOrder.add(invocation.positionalArguments[0] as int);
        return Future.value();
      });

      // Act: Process queue
      final processed = await queue.processQueue();

      // Assert: All processed in priority order (critical, normal, low)
      expect(processed, 3);
      expect(processedOrder, [2, 3, 1]); // Critical -> Normal -> Low
    });

    test('should handle expired requests correctly', () async {
      // Arrange - Offline
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);
      when(mockSyncQueueDao.getPendingOperations())
          .thenAnswer((_) async => []);

      when(mockSyncQueueDao.addToQueue(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        operation: anyNamed('operation'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async => 1);

      // Act 1: Queue request
      await dio.post(
        '/orders',
        data: {'item': 'test'},
        options: Options(extra: {'request_id': 'req-expired'}),
      );

      // Arrange - Go online with expired request
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => true);

      final now = DateTime.now();
      final expiredItem = SyncQueueData(
        id: 1,
        entityType: 'order',
        entityId: 'req-expired',
        operation: 'post',
        payload: '''{
          "method": "POST",
          "path": "/orders",
          "headers": {},
          "data": {"item": "test"},
          "queryParameters": {},
          "extra": {"request_id": "req-expired"},
          "priority": 3,
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

      // Act: Process queue
      final processed = await queue.processQueue();

      // Assert: Expired request was removed, not processed
      expect(processed, 0);
      verify(mockSyncQueueDao.deleteOperation(1)).called(1);
      verifyNever(mockSyncQueueDao.markAsSyncing(any));
      verifyNever(mockSyncQueueDao.markAsCompleted(any));
    });

    test('should handle queue full scenario', () async {
      // Arrange - Offline with full queue
      when(mockConnectivityService.isOnline()).thenAnswer((_) async => false);

      // Create 1000 mock items (maxQueueSize = 1000)
      final fullQueue = List.generate(
        1000,
        (i) => SyncQueueData(
          id: i,
          entityType: 'order',
          entityId: 'id-$i',
          operation: 'post',
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
          .thenAnswer((_) async => fullQueue);

      // Act & Assert: Request should fail with queue full exception
      try {
        await dio.post(
          '/orders',
          data: {'item': 'test'},
        );
        fail('Should have thrown exception');
      } on DioException catch (e) {
        expect(e.error, isA<QueueFullException>());
      }
    });
  });
}
