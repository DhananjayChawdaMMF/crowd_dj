/// Pure parsing/validation of user-entered room identifiers.
abstract final class RoomCodeValidator {
  static final _code = RegExp(r'^[A-Za-z0-9]{6,12}$');

  /// Returns the room code from a bare code or a `/room/<code>[/...]` URL,
  /// or null when the input is not recognisable.
  static String? extract(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    final segments = uri?.pathSegments ?? const <String>[];
    final roomIndex = segments.indexOf('room');
    if (roomIndex != -1 && roomIndex + 1 < segments.length) {
      final candidate = segments[roomIndex + 1];
      return _code.hasMatch(candidate) ? candidate.toUpperCase() : null;
    }
    return _code.hasMatch(value) ? value.toUpperCase() : null;
  }
}
