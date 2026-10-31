import '../domain/entities/room.dart';
import '../domain/room_repository.dart';
import 'room_remote_data_source.dart';

class RoomRepositoryImpl implements RoomRepository {
  RoomRepositoryImpl(this._remote);

  final RoomRemoteDataSource _remote;

  @override
  Future<RoomSession> createRoom(CreateRoomParams params) =>
      _remote.createRoom(params);

  @override
  Future<RoomPreview> getPreview(String code) => _remote.getPreview(code);

  @override
  Future<RoomSession> joinRoom(String code, String displayName) =>
      _remote.joinRoom(code, displayName);

  @override
  Future<Room> fetchRoom(String code) => _remote.fetchRoom(code);

  @override
  Future<List<Participant>> fetchParticipants(String roomId) =>
      _remote.fetchParticipants(roomId);

  @override
  Future<void> closeRoom(String roomId) => _remote.closeRoom(roomId);
}
