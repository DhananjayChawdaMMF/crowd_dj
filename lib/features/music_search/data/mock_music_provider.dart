import '../domain/music_provider.dart';
import '../domain/song_candidate.dart';

/// Development-only provider. Every title is a clearly labelled demo entry:
/// this is NOT a real music search integration and has no real artists,
/// artwork or audio.
class MockMusicProvider implements MusicProvider {
  const MockMusicProvider();

  static const providerId = 'mock';

  static const _catalog = <SongCandidate>[
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-001',
      title: 'Neon Skyline (Demo)',
      artist: 'Demo Artist Alpha',
      albumName: 'Demo Album One',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-002',
      title: 'Midnight Drive (Demo)',
      artist: 'Demo Artist Alpha',
      albumName: 'Demo Album One',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-003',
      title: 'Golden Hour (Demo)',
      artist: 'Demo Artist Beta',
      albumName: 'Demo Album Two',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-004',
      title: 'Dancefloor Echo (Demo)',
      artist: 'Demo Artist Beta',
      albumName: 'Demo Album Two',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-005',
      title: 'Paper Planes (Demo)',
      artist: 'Demo Artist Gamma',
      albumName: 'Demo Album Three',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-006',
      title: 'Summer Static (Demo)',
      artist: 'Demo Artist Gamma',
      albumName: 'Demo Album Three',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-007',
      title: 'Low Tide (Demo)',
      artist: 'Demo Artist Delta',
      albumName: 'Demo Album Four',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-008',
      title: 'Afterglow (Demo)',
      artist: 'Demo Artist Delta',
      albumName: 'Demo Album Four',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-009',
      title: 'City Lights (Demo)',
      artist: 'Demo Artist Epsilon',
      albumName: 'Demo Album Five',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-010',
      title: 'Run It Back (Demo)',
      artist: 'Demo Artist Epsilon',
      albumName: 'Demo Album Five',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-011',
      title: 'Slow Motion (Demo)',
      artist: 'Demo Artist Zeta',
      albumName: 'Demo Album Six',
      durationMs: 24000,
    ),
    SongCandidate(
      provider: providerId,
      providerSongId: 'demo-012',
      title: 'Last Call (Demo)',
      artist: 'Demo Artist Zeta',
      albumName: 'Demo Album Six',
      durationMs: 24000,
    ),
  ];

  @override
  String get id => providerId;

  @override
  String get displayName => 'Demo catalog (sample data)';

  @override
  bool get isDemo => true;

  @override
  Future<List<SongCandidate>> searchSongs(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _catalog
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              (s.albumName?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Future<SongCandidate?> getSongDetails(String songId) async {
    for (final s in _catalog) {
      if (s.providerSongId == songId) return s;
    }
    return null;
  }

  /// Original 24-second tracks synthesised for this project (see
  /// DEVELOPMENT.md), bundled as assets: no third-party licence, no CORS.
  @override
  Future<PlayableSource?> getPlayableSource(String songId) async {
    final known = _catalog.any((s) => s.providerSongId == songId);
    return known ? PlayableSource.asset('assets/audio/$songId.mp3') : null;
  }
}
