import '../domain/music_provider.dart';
import '../domain/song_candidate.dart';
import '../domain/song_search_repository.dart';

class SongSearchRepositoryImpl implements SongSearchRepository {
  const SongSearchRepositoryImpl(this._provider);

  final MusicProvider _provider;

  @override
  String get catalogName => _provider.displayName;

  @override
  bool get isDemoCatalog => _provider.isDemo;

  @override
  Future<List<SongCandidate>> searchSongs(String query) =>
      _provider.searchSongs(query);
}
