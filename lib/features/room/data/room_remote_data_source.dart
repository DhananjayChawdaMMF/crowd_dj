import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/entities/room.dart';
import 'models/room_models.dart';

/// Talks to the trusted RPCs only; the client never writes room tables directly.
class RoomRemoteDataSource {
  RoomRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<RoomSession> createRoom(CreateRoomParams p) => _guard(() async {
    final data = await _client.rpc(
      'create_room',
      params: {
        'p_room_name': p.roomName.trim(),
        'p_description': p.description?.trim(),
        'p_host_name': p.hostName.trim(),
        'p_is_public': p.isPublic,
        'p_allow_recommendations': p.allowRecommendations,
        'p_enable_voting': p.enableVoting,
      },
    );
    return roomSessionFromJson(data as Map<String, dynamic>);
  });

  Future<RoomPreview> getPreview(String code) => _guard(() async {
    final data = await _client.rpc(
      'get_room_preview',
      params: {'p_code': code},
    );
    return roomPreviewFromJson(data as Map<String, dynamic>);
  });

  Future<RoomSession> joinRoom(String code, String displayName) =>
      _guard(() async {
        final data = await _client.rpc(
          'join_room',
          params: {'p_code': code, 'p_display_name': displayName},
        );
        return roomSessionFromJson(data as Map<String, dynamic>);
      });

  Future<Room> fetchRoom(String code) => _guard(() async {
    final row = await _client
        .from('rooms')
        .select('*, current_song:songs!rooms_current_song_fk(*)')
        .eq('room_code', code.toUpperCase())
        .maybeSingle();
    if (row == null) {
      throw const AppFailure(
        'That room does not exist.',
        code: 'room_not_found',
      );
    }
    return roomFromJson(row);
  });

  Future<List<Participant>> fetchParticipants(String roomId) =>
      _guard(() async {
        final rows = await _client
            .from('participants')
            .select()
            .eq('room_id', roomId)
            .order('joined_at', ascending: true);
        return rows.map(participantFromJson).toList();
      });

  Future<void> closeRoom(String roomId) => _guard(() async {
    await _client.rpc('close_room', params: {'p_room_id': roomId});
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
