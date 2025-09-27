import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set development environment
  AppConfig.setEnvironment(Environment.development);

  runApp(const CourierApp());
}