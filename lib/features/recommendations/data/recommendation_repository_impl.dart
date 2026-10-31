import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../music_search/data/models/song_model.dart';
import '../../music_search/domain/song_candidate.dart';
import '../domain/recommendation.dart';
import '../domain/recommendation_repository.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  RecommendationRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Recommendation>> fetchRecommendations(String roomId) async {
    try {
      final rows = await _client
          .from('recommendations')
          .select(
            'id, status, created_at, participant_id, songs(*), '
            'participants(display_name)',
          )
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  Future<void> recommendSong(String roomId, SongCandidate song) async {
    try {
      await _client.rpc(
        'recommend_song',
        params: {
          'p_room_id': roomId,
          'p_provider': song.provider,
          'p_provider_song_id': song.providerSongId,
          'p_title': song.title,
          'p_artist': song.artist,
          'p_album_name': song.albumName,
          'p_artwork_url': song.artworkUrl,
          'p_duration_ms': song.durationMs,
        },
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  Future<void> review(String recommendationId, {required bool approve}) async {
    try {
      await _client.rpc(
        'review_recommendation',
        params: {'p_recommendation_id': recommendationId, 'p_approve': approve},
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Recommendation _fromRow(Map<String, dynamic> j) {
    final participant = j['participants'] as Map<String, dynamic>?;
    return Recommendation(
      id: j['id'] as String,
      song: songFromJson(j['songs'] as Map<String, dynamic>),
      participantId: j['participant_id'] as String,
      guestName: participant?['display_name'] as String? ?? 'Guest',
      status: RecommendationStatus.parse(j['status'] as String?),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}
