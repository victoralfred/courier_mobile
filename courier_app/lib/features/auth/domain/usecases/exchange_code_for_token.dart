import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_response.dart';
import '../repositories/oauth_repository.dart';

/// Parameters for exchanging an authorization code for tokens.
class ExchangeCodeParams extends Equatable {
  final String code;
  final String state;

  const ExchangeCodeParams({
    required this.code,
    required this.state,
  });

  @override
  List<Object?> get props => [code, state];
}

/// Use case for exchanging an OAuth2 authorization code for tokens.
/// Validates the state parameter and uses PKCE verification.
class ExchangeCodeForToken
    implements UseCase<TokenResponse, ExchangeCodeParams> {
  final OAuthRepository repository;

  const ExchangeCodeForToken(this.repository);

  @override
  Future<Either<Failure, TokenResponse>> call(
    ExchangeCodeParams params,
  ) async {
    // Validate input parameters
    if (params.code.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthCodeRequired),
      );
    }

    if (params.state.isEmpty) {
      return const Left(
        ValidationFailure(message: AppStrings.errorOAuthStateRequired),
      );
    }

    // Retrieve the stored authorization request
    final requestResult = await repository.getAuthorizationRequest(
      params.state,
    );

    return requestResult.fold(
      (failure) => Left(failure),
      (request) async {
        // Validate the request
        if (!request.isValid) {
          return const Left(
            OAuthStateFailure(AppStrings.errorOAuthRequestInvalid),
          );
        }

        // Exchange code for tokens
        final tokenResult = await repository.exchangeCodeForToken(
          code: params.code,
          state: params.state,
          request: request,
        );

        // Clean up expired requests
        await repository.cleanupExpiredRequests();

        return tokenResult;
      },
    );
  }
}