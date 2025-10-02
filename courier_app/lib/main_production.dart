import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/di/injection.dart' as di;
import 'core/network/connectivity_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set production environment
  AppConfig.setEnvironment(Environment.production);

  // Initialize dependency injection
  await di.init();

  // Start connectivity monitoring and sync service
  final connectivityService = di.getIt<ConnectivityService>();
  await connectivityService.startMonitoring();

  // Trigger initial sync if online
  await connectivityService.checkAndSync();

  runApp(const CourierApp());
}