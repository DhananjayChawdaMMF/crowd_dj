import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/playback_repository.dart';
import '../domain/playback_state.dart';
import 'models/playback_model.dart';

class PlaybackRepositoryImpl implements PlaybackRepository {
  PlaybackRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<PlaybackState> setPlayback(
    String roomId,
    PlaybackStatus status,
    int positionMs,
  ) async {
    try {
      final row = await _client.rpc(
        'set_playback',
        params: {
          'p_room_id': roomId,
          'p_status': status.name,
          'p_position_ms': positionMs,
        },
      );
      return playbackFromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  Future<PlaybackState> playNext(String roomId, int expectedVersion) async {
    try {
      final row = await _client.rpc(
        'play_next',
        params: {'p_room_id': roomId, 'p_expected_version': expectedVersion},
      );
      return playbackFromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
