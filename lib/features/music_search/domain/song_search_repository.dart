import 'song_candidate.dart';

abstract interface class SongSearchRepository {
  /// Name of the underlying catalog, for display.
  String get catalogName;

  bool get isDemoCatalog;

  Future<List<SongCandidate>> searchSongs(String query);
}
