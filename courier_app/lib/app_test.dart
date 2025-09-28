import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/presentation/screens/login_screen.dart';
import 'package:delivery_app/features/auth/presentation/screens/registration_screen.dart';
import 'package:delivery_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:delivery_app/features/customer/presentation/screens/customer_home_screen.dart';
import 'package:delivery_app/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:flutter/material.dart';
import 'core/config/app_config.dart';

/// Test version of the app with simple routing
class TestCourierApp extends StatelessWidget {
  const TestCourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const Scaffold(body: Center(child: Text('Login'))),
        '/register': (context) => const Scaffold(body: Center(child: Text('Register'))),
        '/forgot-password': (context) => const Scaffold(body: Center(child: Text('Forgot Password'))),
        '/home': (context) => const Scaffold(body: Center(child: Text('Home'))),
        '/driver-home': (context) => const Scaffold(body: Center(child: Text('Driver Home'))),
      },
    );
  }
}