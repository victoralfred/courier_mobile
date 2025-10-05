import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/di/injection.dart' as di;
import 'core/network/connectivity_service.dart';
import 'core/network/api_client.dart';
import 'core/sync/background_sync_service.dart';
import 'features/auth/data/datasources/token_local_data_source.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set production environment
  AppConfig.setEnvironment(Environment.production);

  // Initialize dependency injection
  await di.init();

  // Initialize background sync service
  await BackgroundSyncService.initialize();

  // Load stored auth token and set it on ApiClient
  final tokenDataSource = di.getIt<TokenLocalDataSource>();
  final storedToken = await tokenDataSource.getToken();
  if (storedToken != null) {
    final apiClient = di.getIt<ApiClient>();
    apiClient.setAuthToken(storedToken);

    // Register periodic background sync when user is authenticated
    await BackgroundSyncService.registerPeriodicSync();
  }

  // Start connectivity monitoring and sync service
  final connectivityService = di.getIt<ConnectivityService>();
  await connectivityService.startMonitoring();

  // Trigger initial sync if online
  await connectivityService.checkAndSync();

  runApp(const CourierApp());
}