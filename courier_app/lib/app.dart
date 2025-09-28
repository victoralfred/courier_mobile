import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/presentation/screens/login_screen.dart';
import 'package:delivery_app/features/auth/presentation/screens/registration_screen.dart';
import 'package:delivery_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:delivery_app/features/customer/presentation/screens/customer_home_screen.dart';
import 'package:delivery_app/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/config/app_config.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
        designSize: const Size(375, 812), // iPhone X size as base
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: AppConfig.isDebug,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegistrationScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/home': (context) => const CustomerHomeScreen(),
            '/driver-home': (context) => const DriverHomeScreen(),
          },
        ),
      );
}
