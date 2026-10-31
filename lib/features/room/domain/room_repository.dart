import 'entities/room.dart';

abstract interface class RoomRepository {
  Future<RoomSession> createRoom(CreateRoomParams params);
  Future<RoomPreview> getPreview(String code);
  Future<RoomSession> joinRoom(String code, String displayName);

  /// Reads the room by code. Row-level security hides rooms the caller has not
  /// joined, so a missing room here means "not a member (or no such room)".
  Future<Room> fetchRoom(String code);
  Future<List<Participant>> fetchParticipants(String roomId);

  /// Host action: closes the room for everyone.
  Future<void> closeRoom(String roomId);
}
