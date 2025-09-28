import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/authorization_request.dart';
import '../../domain/entities/oauth_provider.dart';
import '../../domain/entities/token_response.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/oauth_repository.dart';
import '../datasources/oauth_local_data_source.dart';
import '../datasources/oauth_remote_data_source.dart';

/// Implementation of the OAuth repository
class OAuthRepositoryImpl implements OAuthRepository {
  final OAuthRemoteDataSource remoteDataSource;
  final OAuthLocalDataSource localDataSource;

  OAuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, AuthorizationRequest>> generateAuthorizationRequest(
    OAuthProvider provider,
  ) async {
    try {
      final request = await remoteDataSource.generateAuthorizationUrl(provider);

      // Store the request for later validation
      await localDataSource.storeAuthorizationRequest(request);

      return Right(request);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthProviderError,
            {
              'provider': provider.displayName,
              'error': e.toString(),
            },
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TokenResponse>> exchangeCodeForToken({
    required String code,
    required String state,
    required AuthorizationRequest request,
  }) async {
    try {
      // Validate state matches
      if (request.state != state) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthStateValidationFailed),
        );
      }

      // Validate request is still valid
      if (!request.isValid) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
        );
      }

      final tokenResponse = await remoteDataSource.exchangeCodeForToken(
        code: code,
        codeVerifier: request.pkceChallenge.codeVerifier,
        provider: request.provider,
      );

      // Mark request as used and delete it
      await localDataSource.deleteAuthorizationRequest(request.state);

      return Right(tokenResponse);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.errorOAuthTokenExchangeFailed,
          provider: request.provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TokenResponse>> refreshToken(
    String refreshToken,
    OAuthProvider provider,
  ) async {
    try {
      final tokenResponse = await remoteDataSource.refreshToken(
        refreshToken: refreshToken,
        provider: provider,
      );
      return Right(tokenResponse);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.errorOAuthRefreshTokenFailed,
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> revokeToken(
    String token,
    OAuthProvider provider,
  ) async {
    try {
      await remoteDataSource.revokeToken(
        token: token,
        provider: provider,
      );
      return const Right(unit);
    } catch (e) {
      // Revocation errors are often non-critical
      // Log but return success
      print('Token revocation warning: $e');
      return const Right(unit);
    }
  }

  @override
  Future<Either<Failure, User>> fetchUserInfo(
    String accessToken,
    OAuthProvider provider,
  ) async {
    try {
      final user = await remoteDataSource.fetchUserInfo(
        accessToken: accessToken,
        provider: provider,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthUserInfoFailed,
            {'provider': provider.displayName},
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, User>> linkOAuthAccount(
    String userId,
    OAuthProvider provider,
    String accessToken,
  ) async {
    try {
      // This would call a backend endpoint to link the OAuth account
      // For now, we'll fetch the user info and update linked providers
      final user = await remoteDataSource.fetchUserInfo(
        accessToken: accessToken,
        provider: provider,
      );

      // Add provider to linked list
      final providers = await localDataSource.getLinkedProviders(userId);
      if (!providers.contains(provider.type)) {
        providers.add(provider.type);
        await localDataSource.storeLinkedProviders(userId, providers);
      }

      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthLinkAccountFailed,
            {'provider': provider.displayName},
          ),
          provider: provider.type.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> unlinkOAuthAccount(
    String userId,
    OAuthProviderType providerType,
  ) async {
    try {
      // This would call a backend endpoint to unlink the OAuth account
      // For now, we'll just remove from linked providers list
      final providers = await localDataSource.getLinkedProviders(userId);
      providers.remove(providerType);
      await localDataSource.storeLinkedProviders(userId, providers);
      return const Right(unit);
    } catch (e) {
      return Left(
        OAuthFailure(
          AppStrings.format(
            AppStrings.errorOAuthUnlinkAccountFailed,
            {'provider': _getProviderName(providerType)},
          ),
          provider: providerType.name,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<OAuthProviderType>>> getLinkedProviders(
    String userId,
  ) async {
    try {
      final providers = await localDataSource.getLinkedProviders(userId);
      return Right(providers);
    } catch (e) {
      return Left(
        UnknownFailure(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> storeAuthorizationRequest(
    AuthorizationRequest request,
  ) async {
    try {
      await localDataSource.storeAuthorizationRequest(request);
      return const Right(unit);
    } catch (e) {
      return Left(
        CacheFailure(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<Failure, AuthorizationRequest>> getAuthorizationRequest(
    String state,
  ) async {
    try {
      final request = await localDataSource.getAuthorizationRequest(state);

      if (request == null) {
        return const Left(
          OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
        );
      }

      return Right(request);
    } catch (e) {
      return const Left(
        OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> cleanupExpiredRequests() async {
    try {
      await localDataSource.cleanupExpiredRequests();
      return const Right(unit);
    } catch (e) {
      // Cleanup errors are non-critical
      print('Cleanup warning: $e');
      return const Right(unit);
    }
  }

  // Helper method
  String _getProviderName(OAuthProviderType type) {
    switch (type) {
      case OAuthProviderType.google:
        return AppStrings.oauthProviderGoogle;
      case OAuthProviderType.github:
        return AppStrings.oauthProviderGithub;
      case OAuthProviderType.microsoft:
        return AppStrings.oauthProviderMicrosoft;
      case OAuthProviderType.apple:
        return AppStrings.oauthProviderApple;
    }
  }
}
