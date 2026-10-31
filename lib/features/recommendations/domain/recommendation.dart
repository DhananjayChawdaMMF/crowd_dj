import '../../music_search/domain/song.dart';

enum RecommendationStatus {
  pending,
  approved,
  rejected;

  static RecommendationStatus parse(String? v) => switch (v) {
    'approved' => RecommendationStatus.approved,
    'rejected' => RecommendationStatus.rejected,
    _ => RecommendationStatus.pending,
  };
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.song,
    required this.participantId,
    required this.guestName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final Song song;
  final String participantId;
  final String guestName;
  final RecommendationStatus status;
  final DateTime createdAt;
}
