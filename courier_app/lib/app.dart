import 'package:flutter/material.dart';
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
          title: 'Courier Delivery',
          debugShowCheckedModeBanner: AppConfig.isDebug,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 100,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Courier Delivery App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Environment: Development',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
