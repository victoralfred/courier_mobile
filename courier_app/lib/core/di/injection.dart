import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/network/api_client.dart';
import 'package:delivery_app/core/network/csrf_token_manager.dart';
import 'package:delivery_app/core/security/certificate_pinner.dart';
import 'package:delivery_app/core/security/data_obfuscator.dart';
import 'package:delivery_app/core/security/encryption_service.dart';
import 'package:delivery_app/core/security/session_manager.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_remote_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/token_local_data_source.dart';
import 'package:delivery_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:delivery_app/features/auth/data/repositories/oauth_repository_impl.dart';
import 'package:delivery_app/features/auth/data/services/biometric_service.dart';
import 'package:delivery_app/features/auth/data/services/token_manager_impl.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';
import 'package:delivery_app/features/auth/domain/services/token_manager.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/repositories/oauth_repository.dart';
import 'package:delivery_app/features/auth/domain/usecases/login.dart';
import 'package:delivery_app/features/auth/domain/usecases/register.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:delivery_app/features/drivers/data/repositories/driver_repository_impl.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';
import 'package:delivery_app/features/orders/data/repositories/order_repository_impl.dart';
import 'package:delivery_app/features/orders/domain/repositories/order_repository.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  // External dependencies - Register SharedPreferences as a future singleton
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  getIt.registerLazySingleton(() => const FlutterSecureStorage());
  getIt.registerLazySingleton(() => LocalAuthentication());
  getIt.registerLazySingleton(() => Dio());

  // Core - Database
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Core - Security Services
  getIt.registerLazySingleton<EncryptionService>(
    () => EncryptionServiceImpl(storage: getIt<FlutterSecureStorage>()),
  );

  getIt.registerLazySingleton<DataObfuscator>(
    () => DataObfuscatorImpl(),
  );

  getIt.registerLazySingleton<CertificatePinner>(
    () => CertificatePinnerImpl(
      certificates: CertificatePinningConfig.development().certificates,
    ),
  );

  getIt.registerLazySingleton<SessionManager>(
    () => SessionManagerImpl(
      storage: getIt<FlutterSecureStorage>(),
      sessionTimeout: SessionConfig.development.sessionTimeout,
      warningThreshold: SessionConfig.development.warningThreshold,
    ),
  );

  // Core - Network
  // Create a separate Dio instance for CSRF token manager
  final csrfDio = Dio();
  getIt.registerLazySingleton<CsrfTokenManager>(
    () => CsrfTokenManager(dio: csrfDio),
  );

  // API Client with CSRF support
  getIt.registerLazySingleton(
    () => ApiClient.development(
      certificatePinner: getIt<CertificatePinner>(),
      csrfTokenManager: getIt<CsrfTokenManager>(),
    ),
  );

  // Auth - Data Sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      secureStorage: getIt<FlutterSecureStorage>(),
      preferences: getIt<SharedPreferences>(),
    ),
  );

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<OAuthLocalDataSource>(
    () => OAuthLocalDataSourceImpl(secureStorage: getIt<FlutterSecureStorage>()),
  );

  getIt.registerLazySingleton<OAuthRemoteDataSource>(
    () => OAuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<TokenLocalDataSource>(
    () => TokenLocalDataSourceImpl(secureStorage: getIt<FlutterSecureStorage>()),
  );

  // Auth - Services
  getIt.registerLazySingleton<TokenManager>(
    () => TokenManagerImpl(
      localDataSource: getIt<TokenLocalDataSource>(),
      apiClient: getIt<ApiClient>(),
    ),
  );

  getIt.registerLazySingleton<BiometricService>(
    () => BiometricServiceImpl(
      localAuth: getIt<LocalAuthentication>(),
      storage: getIt<FlutterSecureStorage>(),
    ),
  );

  // Auth - Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      biometricService: getIt(),
    ),
  );

  getIt.registerLazySingleton<OAuthRepository>(
    () => OAuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
    ),
  );

  // Driver - Repositories
  getIt.registerLazySingleton<DriverRepository>(
    () => DriverRepositoryImpl(database: getIt<AppDatabase>()),
  );

  // Order - Repositories
  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(database: getIt<AppDatabase>()),
  );

  // Auth - Use Cases
  getIt.registerLazySingleton(() => Login(getIt()));
  getIt.registerLazySingleton(() => Register(getIt()));

  // Auth - BLoCs
  getIt.registerFactory(
    () => LoginBloc(
      authRepository: getIt<AuthRepository>(),
      oauthRepository: getIt<OAuthRepository>(),
      localAuth: getIt<LocalAuthentication>(),
      loginUseCase: getIt<Login>(),
    ),
  );

  getIt.registerFactory(
    () => RegistrationBloc(
      authRepository: getIt<AuthRepository>(),
      registerUseCase: getIt<Register>(),
    ),
  );
}