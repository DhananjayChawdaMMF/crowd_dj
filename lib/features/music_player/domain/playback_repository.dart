import 'playback_state.dart';

/// Host-only persistence of playback state. The backend rejects anyone who is
/// not the room's host, so a guest calling these gets `forbidden`.
abstract interface class PlaybackRepository {
  Future<PlaybackState> setPlayback(
    String roomId,
    PlaybackStatus status,
    int positionMs,
  );

  /// Advances to the next queued song (or stops if the queue is empty).
  /// [expectedVersion] must match the stored version, otherwise the call fails
  /// with code `stale_playback_version`: that is how duplicate "song ended" or
  /// "skip" transitions are rejected.
  Future<PlaybackState> playNext(String roomId, int expectedVersion);
}
