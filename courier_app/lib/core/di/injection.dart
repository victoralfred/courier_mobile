import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:delivery_app/core/network/api_client.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_local_data_source.dart';
import 'package:delivery_app/features/auth/data/datasources/oauth_remote_data_source.dart';
import 'package:delivery_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:delivery_app/features/auth/data/repositories/oauth_repository_impl.dart';
import 'package:delivery_app/features/auth/data/services/biometric_service.dart';
import 'package:delivery_app/features/auth/data/services/token_manager.dart';
import 'package:delivery_app/features/auth/data/services/token_manager_impl.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/auth/domain/repositories/oauth_repository.dart';
import 'package:delivery_app/features/auth/domain/usecases/login.dart';
import 'package:delivery_app/features/auth/domain/usecases/register.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_bloc.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  // External dependencies
  getIt.registerLazySingleton(() => const FlutterSecureStorage());
  getIt.registerLazySingleton(() => LocalAuthentication());
  getIt.registerLazySingleton(() => Dio());

  // Core
  getIt.registerLazySingleton(() => ApiClient(getIt()));

  // Auth - Data Sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(storage: getIt()),
  );

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: getIt()),
  );

  getIt.registerLazySingleton<OAuthLocalDataSource>(
    () => OAuthLocalDataSourceImpl(storage: getIt()),
  );

  getIt.registerLazySingleton<OAuthRemoteDataSource>(
    () => OAuthRemoteDataSourceImpl(client: getIt()),
  );

  // Auth - Services
  getIt.registerLazySingleton<TokenManager>(
    () => TokenManagerImpl(
      localDataSource: getIt(),
      apiClient: getIt(),
    ),
  );

  getIt.registerLazySingleton<BiometricService>(
    () => BiometricServiceImpl(
      localAuth: getIt(),
      storage: getIt(),
    ),
  );

  // Auth - Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
    ),
  );

  getIt.registerLazySingleton<OAuthRepository>(
    () => OAuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
    ),
  );

  // Auth - Use Cases
  getIt.registerLazySingleton(() => Login(getIt()));
  getIt.registerLazySingleton(() => Register(getIt()));

  // Auth - BLoCs
  getIt.registerFactory(
    () => LoginBloc(
      loginUseCase: getIt(),
      oauthRepository: getIt(),
      biometricService: getIt(),
    ),
  );

  getIt.registerFactory(
    () => RegistrationBloc(
      registerUseCase: getIt(),
    ),
  );
}