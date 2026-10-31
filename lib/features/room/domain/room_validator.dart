/// Pure input validation shared by create/join flows. The backend re-validates.
abstract final class RoomValidator {
  static const maxRoomName = 80;
  static const maxDisplayName = 40;
  static const maxDescription = 500;

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a display name.';
    if (v.length > maxDisplayName) {
      return 'Keep it under $maxDisplayName characters.';
    }
    return null;
  }

  static String? roomName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a room name.';
    if (v.length > maxRoomName) return 'Keep it under $maxRoomName characters.';
    return null;
  }

  static String? description(String? value) {
    if ((value?.trim().length ?? 0) > maxDescription) {
      return 'Keep it under $maxDescription characters.';
    }
    return null;
  }
}
