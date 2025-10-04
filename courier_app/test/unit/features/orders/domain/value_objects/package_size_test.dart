import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PackageSize', () {
    group('values', () {
      test('should have all package size values', () {
        // Act & Assert
        expect(PackageSize.values.length, 4);
        expect(PackageSize.values, contains(PackageSize.small));
        expect(PackageSize.values, contains(PackageSize.medium));
        expect(PackageSize.values, contains(PackageSize.large));
        expect(PackageSize.values, contains(PackageSize.xlarge));
      });
    });

    group('fromString', () {
      test('should parse small from string', () {
        // Act
        final size = PackageSizeHelper.fromString('small');

        // Assert
        expect(size, PackageSize.small);
      });

      test('should parse medium from string', () {
        // Act
        final size = PackageSizeHelper.fromString('medium');

        // Assert
        expect(size, PackageSize.medium);
      });

      test('should parse large from string', () {
        // Act
        final size = PackageSizeHelper.fromString('large');

        // Assert
        expect(size, PackageSize.large);
      });

      test('should parse xlarge from string', () {
        // Act
        final size = PackageSizeHelper.fromString('xlarge');

        // Assert
        expect(size, PackageSize.xlarge);
      });

      test('should throw ArgumentError for invalid string', () {
        // Act & Assert
        expect(
          () => PackageSizeHelper.fromString('invalid'),
          throwsArgumentError,
        );
      });

      test('should be case-insensitive', () {
        // Act
        final size = PackageSizeHelper.fromString('SMALL');

        // Assert
        expect(size, PackageSize.small);
      });
    });

    group('toJson', () {
      test('should convert small to string', () {
        // Act
        final json = PackageSize.small.toJson();

        // Assert
        expect(json, 'small');
      });

      test('should convert medium to string', () {
        // Act
        final json = PackageSize.medium.toJson();

        // Assert
        expect(json, 'medium');
      });

      test('should convert large to string', () {
        // Act
        final json = PackageSize.large.toJson();

        // Assert
        expect(json, 'large');
      });

      test('should convert xlarge to string', () {
        // Act
        final json = PackageSize.xlarge.toJson();

        // Assert
        expect(json, 'xlarge');
      });
    });

    group('roundtrip conversion', () {
      test('should maintain value through fromString and toJson', () {
        // Arrange
        final sizes = PackageSize.values;

        for (final size in sizes) {
          // Act
          final json = size.toJson();
          final parsed = PackageSizeHelper.fromString(json);

          // Assert
          expect(parsed, size);
        }
      });
    });
  });
}
