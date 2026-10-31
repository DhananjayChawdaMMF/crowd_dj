import '../../../../core/services/session_provider.dart';
import '../entities/room.dart';
import '../room_repository.dart';

class GetRoomPreview {
  const GetRoomPreview(this._sessions, this._rooms);

  final SessionProvider _sessions;
  final RoomRepository _rooms;

  Future<RoomPreview> call(String code) async {
    await _sessions.ensureSignedIn();
    return _rooms.getPreview(code);
  }
}
