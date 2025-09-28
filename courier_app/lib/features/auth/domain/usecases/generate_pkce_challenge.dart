import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/utils/pkce_utils.dart';
import '../entities/pkce_challenge.dart';

/// Use case for generating a PKCE challenge for OAuth2 flows.
/// This implements RFC 7636 for enhanced security in OAuth2.
class GeneratePKCEChallenge implements UseCase<PKCEChallenge, NoParams> {
  @override
  Future<Either<Failure, PKCEChallenge>> call(NoParams params) async {
    try {
      // Generate code verifier (43-128 characters)
      final codeVerifier = PKCEUtils.generateCodeVerifier();

      // Generate code challenge using SHA256
      final codeChallenge = PKCEUtils.generateCodeChallenge(codeVerifier);

      return Right(PKCEChallenge(
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        method: 'S256',
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(
        PKCEFailure(
          AppStrings.format(
            AppStrings.errorOAuthGeneratePKCE,
            {'error': e.toString()},
          ),
        ),
      );
    }
  }
}