import '../../music_search/domain/song.dart';

class QueueItem {
  const QueueItem({
    required this.id,
    required this.position,
    required this.song,
    required this.isPlaying,
    this.recommendedBy,
  });

  final String id;
  final int position;
  final Song song;
  final bool isPlaying;
  final String? recommendedBy;
}
