import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set production environment
  AppConfig.setEnvironment(Environment.production);

  runApp(const CourierApp());
}