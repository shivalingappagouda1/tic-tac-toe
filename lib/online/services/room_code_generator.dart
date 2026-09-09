import 'dart:math' as math;

/// Utility for generating short, easy-to-read, unambiguous 6-character room codes.
/// Excludes confusing characters like 0/O and 1/I/L.
class RoomCodeGenerator {
  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final math.Random _rng = math.Random.secure();

  /// Generates a new 6-character room code.
  static String generate([int length = 6]) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Normalizes room code for case-insensitive matching and whitespace removal.
  static String normalize(String code) {
    return code.trim().toUpperCase();
  }

  /// Validates whether a given string could be a valid room code.
  static bool isValid(String code) {
    final normalized = normalize(code);
    if (normalized.length != 6) return false;
    final regex = RegExp(r'^[A-Z0-9]{6}$');
    return regex.hasMatch(normalized);
  }
}
