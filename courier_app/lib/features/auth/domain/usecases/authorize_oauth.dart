import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/authorization_request.dart';
import '../entities/oauth_provider.dart';
import '../repositories/oauth_repository.dart';

/// Parameters for the AuthorizeOAuth use case.
class AuthorizeOAuthParams extends Equatable {
  final OAuthProvider provider;

  const AuthorizeOAuthParams({required this.provider});

  @override
  List<Object?> get props => [provider];
}

/// Use case for initiating an OAuth2 authorization flow.
/// Generates an authorization URL with PKCE challenge.
class AuthorizeOAuth
    implements UseCase<AuthorizationRequest, AuthorizeOAuthParams> {
  final OAuthRepository repository;

  const AuthorizeOAuth(this.repository);

  @override
  Future<Either<Failure, AuthorizationRequest>> call(
    AuthorizeOAuthParams params,
  ) async {
    // Validate provider configuration
    if (params.provider.clientId.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthClientIdRequired),
      );
    }

    if (params.provider.redirectUri.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthRedirectUriRequired),
      );
    }

    // Generate authorization request with PKCE
    final result = await repository.generateAuthorizationRequest(
      params.provider,
    );

    return result.fold(
      (failure) => Left(failure),
      (request) async {
        // Store the request for later validation
        final storeResult = await repository.storeAuthorizationRequest(request);

        return storeResult.fold(
          (failure) => Left(failure),
          (_) => Right(request),
        );
      },
    );
  }
}
