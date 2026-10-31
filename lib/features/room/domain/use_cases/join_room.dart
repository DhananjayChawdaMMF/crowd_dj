import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/session_provider.dart';
import '../entities/room.dart';
import '../room_repository.dart';
import '../room_validator.dart';

class JoinRoom {
  const JoinRoom(this._sessions, this._rooms);

  final SessionProvider _sessions;
  final RoomRepository _rooms;

  Future<RoomSession> call(String code, String displayName) async {
    final error = RoomValidator.displayName(displayName);
    if (error != null) throw AppFailure(error);
    await _sessions.ensureSignedIn();
    return _rooms.joinRoom(code, displayName.trim());
  }
}
