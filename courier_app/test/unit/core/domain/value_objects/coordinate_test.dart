import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coordinate', () {
    group('constructor', () {
      test('should create Coordinate with valid Nigeria coordinates', () {
        // Arrange & Act - Lagos coordinates
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Assert
        expect(coordinate.latitude, 6.5244);
        expect(coordinate.longitude, 3.3792);
      });

      test('should create Coordinate for Abuja (FCT)', () {
        // Arrange & Act
        final coordinate = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Assert
        expect(coordinate.latitude, 9.0765);
        expect(coordinate.longitude, 7.3986);
      });

      test('should create Coordinate for Port Harcourt', () {
        // Arrange & Act
        final coordinate = Coordinate(latitude: 4.8156, longitude: 7.0498);

        // Assert
        expect(coordinate.latitude, 4.8156);
        expect(coordinate.longitude, 7.0498);
      });

      test('should create Coordinate for Kano', () {
        // Arrange & Act
        final coordinate = Coordinate(latitude: 12.0022, longitude: 8.5920);

        // Assert
        expect(coordinate.latitude, 12.0022);
        expect(coordinate.longitude, 8.5920);
      });

      test('should accept coordinates outside Nigeria bounds (global validation only)', () {
        // Act & Assert - Below 4°N (outside Nigeria but valid globally)
        final outsideNigeria1 = Coordinate(latitude: 3.5, longitude: 7.0);
        expect(outsideNigeria1.isWithinNigeria, false);

        // Above 14°N (outside Nigeria but valid globally)
        final outsideNigeria2 = Coordinate(latitude: 14.5, longitude: 7.0);
        expect(outsideNigeria2.isWithinNigeria, false);

        // Below 3°E (outside Nigeria but valid globally)
        final outsideNigeria3 = Coordinate(latitude: 9.0, longitude: 2.5);
        expect(outsideNigeria3.isWithinNigeria, false);

        // Above 15°E (outside Nigeria but valid globally)
        final outsideNigeria4 = Coordinate(latitude: 9.0, longitude: 15.5);
        expect(outsideNigeria4.isWithinNigeria, false);
      });

      test('should throw ValidationException for latitude NaN', () {
        // Act & Assert
        expect(
          () => Coordinate(latitude: double.nan, longitude: 7.0),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for longitude NaN', () {
        // Act & Assert
        expect(
          () => Coordinate(latitude: 9.0, longitude: double.nan),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for latitude infinity', () {
        // Act & Assert
        expect(
          () => Coordinate(latitude: double.infinity, longitude: 7.0),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for longitude infinity', () {
        // Act & Assert
        expect(
          () => Coordinate(latitude: 9.0, longitude: double.infinity),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should accept edge case at minimum latitude', () {
        // Arrange & Act - 4°N (southern edge)
        final coordinate = Coordinate(latitude: 4.0, longitude: 7.0);

        // Assert
        expect(coordinate.latitude, 4.0);
      });

      test('should accept edge case at maximum latitude', () {
        // Arrange & Act - 14°N (northern edge)
        final coordinate = Coordinate(latitude: 14.0, longitude: 7.0);

        // Assert
        expect(coordinate.latitude, 14.0);
      });

      test('should accept edge case at minimum longitude', () {
        // Arrange & Act - 3°E (western edge)
        final coordinate = Coordinate(latitude: 9.0, longitude: 3.0);

        // Assert
        expect(coordinate.longitude, 3.0);
      });

      test('should accept edge case at maximum longitude', () {
        // Arrange & Act - 15°E (eastern edge)
        final coordinate = Coordinate(latitude: 9.0, longitude: 15.0);

        // Assert
        expect(coordinate.longitude, 15.0);
      });
    });

    group('distanceTo', () {
      test('should calculate distance between Lagos and Abuja (approx 481 km)', () {
        // Arrange
        final lagos = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final abuja = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Act
        final distance = lagos.distanceTo(abuja);

        // Assert - Should be approximately 481 km (with 10% tolerance)
        expect(distance.inKilometers, greaterThan(430));
        expect(distance.inKilometers, lessThan(530));
      });

      test('should calculate distance between same location as zero', () {
        // Arrange
        final location = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final distance = location.distanceTo(location);

        // Assert
        expect(distance.inKilometers, lessThan(0.01)); // Essentially zero
      });

      test('should calculate distance between Port Harcourt and Kano', () {
        // Arrange
        final portHarcourt = Coordinate(latitude: 4.8156, longitude: 7.0498);
        final kano = Coordinate(latitude: 12.0022, longitude: 8.5920);

        // Act
        final distance = portHarcourt.distanceTo(kano);

        // Assert - Should be approximately 820 km
        expect(distance.inKilometers, greaterThan(750));
        expect(distance.inKilometers, lessThan(900));
      });
    });

    group('isWithinNigeria', () {
      test('should return true for Lagos coordinates', () {
        // Arrange
        final lagos = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(lagos.isWithinNigeria, true);
      });

      test('should return true for Abuja coordinates', () {
        // Arrange
        final abuja = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Act & Assert
        expect(abuja.isWithinNigeria, true);
      });

      test('should return true for coordinates at Nigeria edges', () {
        // Arrange - Edge cases
        final southWest = Coordinate(latitude: 4.0, longitude: 3.0);
        final northEast = Coordinate(latitude: 14.0, longitude: 15.0);

        // Act & Assert
        expect(southWest.isWithinNigeria, true);
        expect(northEast.isWithinNigeria, true);
      });
    });

    group('comparison', () {
      test('should return true when comparing equal coordinates', () {
        // Arrange
        final coord1 = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final coord2 = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(coord1 == coord2, true);
        expect(coord1.hashCode, coord2.hashCode);
      });

      test('should return false when comparing different coordinates', () {
        // Arrange
        final lagos = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final abuja = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Act & Assert
        expect(lagos == abuja, false);
      });

      test('should return false for coordinates with same latitude, different longitude', () {
        // Arrange
        final coord1 = Coordinate(latitude: 9.0, longitude: 7.0);
        final coord2 = Coordinate(latitude: 9.0, longitude: 8.0);

        // Act & Assert
        expect(coord1 == coord2, false);
      });

      test('should return false for coordinates with different latitude, same longitude', () {
        // Arrange
        final coord1 = Coordinate(latitude: 9.0, longitude: 7.0);
        final coord2 = Coordinate(latitude: 10.0, longitude: 7.0);

        // Act & Assert
        expect(coord1 == coord2, false);
      });
    });

    group('copyWith', () {
      test('should create a copy with new latitude', () {
        // Arrange
        final original = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final copy = original.copyWith(latitude: 9.0765);

        // Assert
        expect(copy.latitude, 9.0765);
        expect(copy.longitude, 3.3792);
        expect(original.latitude, 6.5244); // Original unchanged
      });

      test('should create a copy with new longitude', () {
        // Arrange
        final original = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final copy = original.copyWith(longitude: 7.3986);

        // Assert
        expect(copy.latitude, 6.5244);
        expect(copy.longitude, 7.3986);
        expect(original.longitude, 3.3792); // Original unchanged
      });

      test('should create identical copy when no parameters specified', () {
        // Arrange
        final original = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final copy = original.copyWith();

        // Assert
        expect(copy == original, true);
      });
    });

    group('toString', () {
      test('should format coordinate as lat,lng', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final string = coordinate.toString();

        // Assert
        expect(string, '6.5244, 3.3792');
      });
    });

    group('props', () {
      test('should include latitude and longitude in props', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(coordinate.props, [6.5244, 3.3792]);
      });
    });
  });
}
