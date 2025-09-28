import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:delivery_app/features/auth/domain/usecases/generate_pkce_challenge.dart';
import 'package:delivery_app/features/auth/domain/entities/pkce_challenge.dart';
import 'package:delivery_app/core/usecases/usecase.dart';

void main() {
  late GeneratePKCEChallenge usecase;

  setUp(() {
    usecase = GeneratePKCEChallenge();
  });

  group('GeneratePKCEChallenge', () {
    test('should generate a valid PKCE challenge', () async {
      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (challenge) {
          expect(challenge, isA<PKCEChallenge>());
          expect(challenge.codeVerifier.length, greaterThanOrEqualTo(43));
          expect(challenge.codeVerifier.length, lessThanOrEqualTo(128));
          expect(challenge.codeChallenge, isNotEmpty);
          expect(challenge.method, equals('S256'));
          expect(challenge.createdAt, isA<DateTime>());
          expect(challenge.isExpired, isFalse);
        },
      );
    });

    test('should generate unique PKCE challenges', () async {
      // Act
      final result1 = await usecase(NoParams());
      final result2 = await usecase(NoParams());

      // Assert
      expect(result1, isA<Right>());
      expect(result2, isA<Right>());

      final challenge1 = (result1 as Right).value as PKCEChallenge;
      final challenge2 = (result2 as Right).value as PKCEChallenge;

      expect(challenge1.codeVerifier, isNot(equals(challenge2.codeVerifier)));
      expect(challenge1.codeChallenge, isNot(equals(challenge2.codeChallenge)));
    });

    test('should use S256 method for code challenge', () async {
      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (challenge) {
          expect(challenge.method, equals('S256'));
        },
      );
    });

    test('should set createdAt to current time', () async {
      // Arrange
      final before = DateTime.now();

      // Act
      final result = await usecase(NoParams());
      final after = DateTime.now();

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (challenge) {
          expect(challenge.createdAt.isAfter(before) ||
                 challenge.createdAt.isAtSameMomentAs(before), isTrue);
          expect(challenge.createdAt.isBefore(after) ||
                 challenge.createdAt.isAtSameMomentAs(after), isTrue);
        },
      );
    });

    test('generated code verifier should follow RFC 7636 spec', () async {
      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (challenge) {
          // RFC 7636: code_verifier = high-entropy cryptographic random STRING using the
          // unreserved characters [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
          final regex = RegExp(r'^[A-Za-z0-9\-._~]+$');
          expect(regex.hasMatch(challenge.codeVerifier), isTrue);
        },
      );
    });

    test('generated code challenge should be base64url without padding', () async {
      // Act
      final result = await usecase(NoParams());

      // Assert
      expect(result, isA<Right>());
      result.fold(
        (failure) => fail('Should not return failure'),
        (challenge) {
          // Base64url without padding should not contain = + or /
          expect(challenge.codeChallenge.contains('='), isFalse);
          expect(challenge.codeChallenge.contains('+'), isFalse);
          expect(challenge.codeChallenge.contains('/'), isFalse);

          // Should only contain base64url characters
          final regex = RegExp(r'^[A-Za-z0-9\-_]+$');
          expect(regex.hasMatch(challenge.codeChallenge), isTrue);
        },
      );
    });
  });
}