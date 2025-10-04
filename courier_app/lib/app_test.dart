import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

/// Test version of the app with simple routing
class TestCourierApp extends StatelessWidget {
  const TestCourierApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) =>
              const Scaffold(body: Center(child: Text('Login'))),
          '/register': (context) =>
              const Scaffold(body: Center(child: Text('Register'))),
          '/forgot-password': (context) =>
              const Scaffold(body: Center(child: Text('Forgot Password'))),
          '/home': (context) =>
              const Scaffold(body: Center(child: Text('Home'))),
          '/driver-home': (context) =>
              const Scaffold(body: Center(child: Text('Driver Home'))),
        },
      );
}
