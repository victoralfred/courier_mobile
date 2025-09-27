import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Value object representing a unique entity identifier (UUID)
class EntityID extends Equatable {
  final String value;

  /// Creates an EntityID from a valid UUID string
  EntityID(String id) : value = _validate(id);

  /// Generates a new random UUID
  factory EntityID.generate() {
    return EntityID(const Uuid().v4());
  }

  /// Validates and normalizes the UUID string
  static String _validate(String id) {
    if (id.isEmpty) {
      throw ArgumentError('EntityID cannot be empty');
    }

    // Normalize to lowercase
    final normalized = id.toLowerCase();

    // UUID regex pattern
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );

    if (!uuidRegex.hasMatch(normalized)) {
      throw ArgumentError('Invalid UUID format: $id');
    }

    return normalized;
  }

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}