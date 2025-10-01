import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/domain/value_objects/location.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Location', () {
    group('constructor', () {
      test('should create Location with valid Nigerian address', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final location = Location(
          address: '23 Marina Road, Lagos Island',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Assert
        expect(location.address, '23 Marina Road, Lagos Island');
        expect(location.coordinate, coordinate);
        expect(location.city, 'Lagos');
        expect(location.state, 'Lagos');
        expect(location.country, 'Nigeria');
      });

      test('should create Location for Abuja (FCT)', () {
        // Arrange
        final coordinate = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Act
        final location = Location(
          address: 'Central Business District',
          coordinate: coordinate,
          city: 'Abuja',
          state: 'Federal Capital Territory',
        );

        // Assert
        expect(location.city, 'Abuja');
        expect(location.state, 'Federal Capital Territory');
        expect(location.country, 'Nigeria');
      });

      test('should create Location with postcode', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
          postcode: '101001',
        );

        // Assert
        expect(location.postcode, '101001');
      });

      test('should throw ValidationException for empty address', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(
          () => Location(
            address: '',
            coordinate: coordinate,
            city: 'Lagos',
            state: 'Lagos',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty city', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(
          () => Location(
            address: '23 Marina Road',
            coordinate: coordinate,
            city: '',
            state: 'Lagos',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty state', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act & Assert
        expect(
          () => Location(
            address: '23 Marina Road',
            coordinate: coordinate,
            city: 'Lagos',
            state: '',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should accept whitespace-trimmed address', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

        // Act
        final location = Location(
          address: '  23 Marina Road  ',
          coordinate: coordinate,
          city: '  Lagos  ',
          state: '  Lagos  ',
        );

        // Assert
        expect(location.address, '23 Marina Road');
        expect(location.city, 'Lagos');
        expect(location.state, 'Lagos');
      });
    });

    group('fullAddress', () {
      test('should format full address without postcode', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act
        final fullAddress = location.fullAddress;

        // Assert
        expect(fullAddress, '23 Marina Road, Lagos, Lagos, Nigeria');
      });

      test('should format full address with postcode', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
          postcode: '101001',
        );

        // Act
        final fullAddress = location.fullAddress;

        // Assert
        expect(fullAddress, '23 Marina Road, Lagos, Lagos 101001, Nigeria');
      });

      test('should format full address for FCT', () {
        // Arrange
        final coordinate = Coordinate(latitude: 9.0765, longitude: 7.3986);
        final location = Location(
          address: 'Plot 123 CBD',
          coordinate: coordinate,
          city: 'Abuja',
          state: 'Federal Capital Territory',
          postcode: '900001',
        );

        // Act
        final fullAddress = location.fullAddress;

        // Assert
        expect(
          fullAddress,
          'Plot 123 CBD, Abuja, Federal Capital Territory 900001, Nigeria',
        );
      });
    });

    group('distanceTo', () {
      test('should calculate distance to another location', () {
        // Arrange
        final lagos = Location(
          address: '23 Marina Road',
          coordinate: Coordinate(latitude: 6.5244, longitude: 3.3792),
          city: 'Lagos',
          state: 'Lagos',
        );

        final abuja = Location(
          address: 'Central Business District',
          coordinate: Coordinate(latitude: 9.0765, longitude: 7.3986),
          city: 'Abuja',
          state: 'Federal Capital Territory',
        );

        // Act
        final distance = lagos.distanceTo(abuja);

        // Assert - Approximately 481 km
        expect(distance.inKilometers, greaterThan(430));
        expect(distance.inKilometers, lessThan(530));
      });

      test('should return zero distance for same location', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act
        final distance = location.distanceTo(location);

        // Assert
        expect(distance.inKilometers, lessThan(0.01));
      });
    });

    group('comparison', () {
      test('should return true for equal locations', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location1 = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );
        final location2 = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act & Assert
        expect(location1 == location2, true);
        expect(location1.hashCode, location2.hashCode);
      });

      test('should return false for different addresses', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location1 = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );
        final location2 = Location(
          address: '45 Broad Street',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act & Assert
        expect(location1 == location2, false);
      });

      test('should return false for different coordinates', () {
        // Arrange
        final location1 = Location(
          address: '23 Marina Road',
          coordinate: Coordinate(latitude: 6.5244, longitude: 3.3792),
          city: 'Lagos',
          state: 'Lagos',
        );
        final location2 = Location(
          address: '23 Marina Road',
          coordinate: Coordinate(latitude: 9.0765, longitude: 7.3986),
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act & Assert
        expect(location1 == location2, false);
      });
    });

    group('copyWith', () {
      test('should create copy with new address', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final original = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act
        final copy = original.copyWith(address: '45 Broad Street');

        // Assert
        expect(copy.address, '45 Broad Street');
        expect(copy.city, 'Lagos');
        expect(original.address, '23 Marina Road'); // Original unchanged
      });

      test('should create copy with new coordinate', () {
        // Arrange
        final original = Location(
          address: '23 Marina Road',
          coordinate: Coordinate(latitude: 6.5244, longitude: 3.3792),
          city: 'Lagos',
          state: 'Lagos',
        );

        final newCoordinate = Coordinate(latitude: 9.0765, longitude: 7.3986);

        // Act
        final copy = original.copyWith(coordinate: newCoordinate);

        // Assert
        expect(copy.coordinate, newCoordinate);
        expect(copy.address, '23 Marina Road');
      });

      test('should create identical copy when no parameters specified', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final original = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act
        final copy = original.copyWith();

        // Assert
        expect(copy == original, true);
      });
    });

    group('toString', () {
      test('should return full address as string', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
        );

        // Act
        final string = location.toString();

        // Assert
        expect(string, '23 Marina Road, Lagos, Lagos, Nigeria');
      });
    });

    group('props', () {
      test('should include all fields in props', () {
        // Arrange
        final coordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);
        final location = Location(
          address: '23 Marina Road',
          coordinate: coordinate,
          city: 'Lagos',
          state: 'Lagos',
          postcode: '101001',
        );

        // Act & Assert
        expect(
          location.props,
          ['23 Marina Road', coordinate, 'Lagos', 'Lagos', 'Nigeria', '101001'],
        );
      });
    });
  });
}
