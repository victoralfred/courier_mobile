import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/di/injection.dart' as di;
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set staging environment
  AppConfig.setEnvironment(Environment.staging);

  // Initialize dependency injection
  await di.init();

  runApp(const CourierApp());
}