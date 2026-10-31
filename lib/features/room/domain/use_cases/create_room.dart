import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/session_provider.dart';
import '../entities/room.dart';
import '../room_repository.dart';
import '../room_validator.dart';

class CreateRoom {
  const CreateRoom(this._sessions, this._rooms);

  final SessionProvider _sessions;
  final RoomRepository _rooms;

  Future<RoomSession> call(CreateRoomParams params) async {
    final error =
        RoomValidator.displayName(params.hostName) ??
        RoomValidator.roomName(params.roomName) ??
        RoomValidator.description(params.description);
    if (error != null) throw AppFailure(error);

    await _sessions.ensureSignedIn();
    return _rooms.createRoom(params);
  }
}
