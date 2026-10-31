import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../music_search/data/models/song_model.dart';
import '../domain/queue_item.dart';
import '../domain/queue_repository.dart';

class QueueRepositoryImpl implements QueueRepository {
  QueueRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<QueueItem>> fetchQueue(String roomId) async {
    try {
      final rows = await _client
          .from('queue')
          .select(
            'id, position, status, songs(*), '
            'recommendations(participants(display_name))',
          )
          .eq('room_id', roomId)
          .inFilter('status', ['queued', 'playing'])
          .order('position', ascending: true);
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  Future<void> removeItem(String queueId) async {
    try {
      await _client.rpc('remove_queue_item', params: {'p_queue_id': queueId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  QueueItem _fromRow(Map<String, dynamic> j) {
    final rec = j['recommendations'] as Map<String, dynamic>?;
    final participant = rec?['participants'] as Map<String, dynamic>?;
    return QueueItem(
      id: j['id'] as String,
      position: (j['position'] as num).toInt(),
      song: songFromJson(j['songs'] as Map<String, dynamic>),
      isPlaying: j['status'] == 'playing',
      recommendedBy: participant?['display_name'] as String?,
    );
  }
}
