import 'song_candidate.dart';

/// Contract for a catalog + playback source. Search UI, recommendations and the
/// player depend on this, never on a concrete vendor API.
///
/// Implementations that call a vendor API must do so server-side (an Edge
/// Function) so credentials never reach the Flutter client, and must only
/// return audio the vendor licenses for this use.
abstract interface class MusicProvider {
  /// Stable id stored in `songs.provider`.
  String get id;

  /// Human-readable name; surfaced in the UI so users know what they search.
  String get displayName;

  /// True when results are placeholders rather than a real catalog.
  bool get isDemo;

  Future<List<SongCandidate>> searchSongs(String query);

  Future<SongCandidate?> getSongDetails(String songId);

  /// Null when the provider has no licensed audio for the song.
  Future<PlayableSource?> getPlayableSource(String songId);
}
