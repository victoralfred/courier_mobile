import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';

void main() {
  group('EntityID', () {
    group('validation', () {
      test('should create EntityID with valid UUID', () {
        // Arrange
        const validUuid = '123e4567-e89b-12d3-a456-426614174000';

        // Act
        final entityId = EntityID(validUuid);

        // Assert
        expect(entityId.value, equals(validUuid));
      });

      test('should throw ArgumentError for invalid UUID format', () {
        // Arrange
        const invalidUuid = 'not-a-valid-uuid';

        // Act & Assert
        expect(
          () => EntityID(invalidUuid),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for empty string', () {
        // Arrange
        const emptyString = '';

        // Act & Assert
        expect(
          () => EntityID(emptyString),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should accept UUID in uppercase', () {
        // Arrange
        const uppercaseUuid = '123E4567-E89B-12D3-A456-426614174000';

        // Act
        final entityId = EntityID(uppercaseUuid);

        // Assert
        expect(entityId.value, equals(uppercaseUuid.toLowerCase()));
      });
    });

    group('generation', () {
      test('should generate valid UUID', () {
        // Act
        final entityId = EntityID.generate();

        // Assert
        expect(entityId.value, matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        )));
      });

      test('should generate unique UUIDs', () {
        // Act
        final entityId1 = EntityID.generate();
        final entityId2 = EntityID.generate();

        // Assert
        expect(entityId1.value, isNot(equals(entityId2.value)));
      });
    });

    group('equality', () {
      test('should be equal for same UUID value', () {
        // Arrange
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        final entityId1 = EntityID(uuid);
        final entityId2 = EntityID(uuid);

        // Assert
        expect(entityId1, equals(entityId2));
        expect(entityId1.hashCode, equals(entityId2.hashCode));
      });

      test('should not be equal for different UUID values', () {
        // Arrange
        final entityId1 = EntityID('123e4567-e89b-12d3-a456-426614174000');
        final entityId2 = EntityID('987e6543-e21b-12d3-a456-426614174999');

        // Assert
        expect(entityId1, isNot(equals(entityId2)));
      });
    });

    group('string representation', () {
      test('should return UUID value as string', () {
        // Arrange
        const uuid = '123e4567-e89b-12d3-a456-426614174000';
        final entityId = EntityID(uuid);

        // Act
        final stringValue = entityId.toString();

        // Assert
        expect(stringValue, equals(uuid));
      });
    });
  });
}