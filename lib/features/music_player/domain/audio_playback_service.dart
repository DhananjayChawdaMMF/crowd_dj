import '../../music_search/domain/song_candidate.dart';

enum AudioState { idle, loading, ready, playing, paused, completed }

/// Thrown by [AudioPlaybackService.play] when the browser blocks playback
/// because the user has not interacted with the page yet.
class AutoplayBlockedException implements Exception {
  const AutoplayBlockedException();

  @override
  String toString() => 'Autoplay blocked by the browser.';
}

/// Host-side audio engine. Guests never instantiate one.
abstract interface class AudioPlaybackService {
  Future<void> load(PlayableSource source);

  /// Throws [AutoplayBlockedException] if the browser refuses to start audio.
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();

  Duration getPosition();
  Duration? getDuration();

  Stream<AudioState> get playbackStateStream;
  Stream<Duration> get positionStream;

  Future<void> dispose();
}
