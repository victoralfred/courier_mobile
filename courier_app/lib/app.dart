import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/routing/app_router.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'core/config/app_config.dart';

class CourierApp extends StatefulWidget {
  const CourierApp({super.key});

  @override
  State<CourierApp> createState() => _CourierAppState();
}

class _CourierAppState extends State<CourierApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // Initialize router with auth repository from DI
    _appRouter = AppRouter(
      authRepository: GetIt.instance<AuthRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
        designSize: const Size(375, 812), // iPhone X size as base
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => RepositoryProvider<AuthRepository>(
          create: (_) => GetIt.instance<AuthRepository>(),
          child: MaterialApp.router(
            title: AppStrings.appTitle,
            debugShowCheckedModeBanner: AppConfig.isDebug,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            routerConfig: _appRouter.router,
          ),
        ),
      );
}
