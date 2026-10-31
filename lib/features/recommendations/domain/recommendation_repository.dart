import '../../music_search/domain/song_candidate.dart';
import 'recommendation.dart';

abstract interface class RecommendationRepository {
  /// Most recent recommendations in the room, newest first.
  Future<List<Recommendation>> fetchRecommendations(String roomId);

  /// Guest action. The backend validates membership, room state and rate limits.
  Future<void> recommendSong(String roomId, SongCandidate song);

  /// Host action. Approving also enqueues the song atomically in the backend.
  Future<void> review(String recommendationId, {required bool approve});
}
