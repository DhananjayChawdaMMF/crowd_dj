/// A song as returned by a [MusicProvider], before it is persisted in the
/// backend (which assigns the internal id). Identified by provider + id.
class SongCandidate {
  const SongCandidate({
    required this.provider,
    required this.providerSongId,
    required this.title,
    required this.artist,
    this.albumName,
    this.artworkUrl,
    this.durationMs,
  });

  final String provider;
  final String providerSongId;
  final String title;
  final String artist;
  final String? albumName;
  final String? artworkUrl;
  final int? durationMs;

  String get key => '$provider:$providerSongId';
}

/// A legally authorised audio source for host-only playback.
class PlayableSource {
  const PlayableSource({required this.url, this.mimeType}) : assetPath = null;

  /// Audio bundled with the app (same origin, so no CORS concerns).
  const PlayableSource.asset(String path)
    : url = null,
      mimeType = null,
      assetPath = path;

  final Uri? url;
  final String? assetPath;
  final String? mimeType;
}
