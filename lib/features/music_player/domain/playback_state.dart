enum PlaybackStatus {
  stopped,
  playing,
  paused;

  static PlaybackStatus parse(String? value) => switch (value) {
    'playing' => PlaybackStatus.playing,
    'paused' => PlaybackStatus.paused,
    _ => PlaybackStatus.stopped,
  };
}

/// Authoritative playback snapshot stored on the room row. The host's player is
/// the source of truth; guests only extrapolate the position from it.
class PlaybackState {
  const PlaybackState({
    required this.status,
    required this.positionMs,
    required this.updatedAt,
    required this.version,
  });

  const PlaybackState.stopped()
    : status = PlaybackStatus.stopped,
      positionMs = 0,
      updatedAt = null,
      version = 0;

  final PlaybackStatus status;
  final int positionMs;
  final DateTime? updatedAt;
  final int version;

  bool get isPlaying => status == PlaybackStatus.playing;

  /// How long a "playing" snapshot is trusted without a newer one. The host
  /// republishes every 30s while playing, so beyond this the DJ is probably
  /// gone and guests stop extrapolating instead of running past the real song.
  static const staleAfter = Duration(seconds: 45);

  /// Approximate current position. While playing, adds the time elapsed since
  /// the snapshot was written (at most [staleAfter]); clamped to
  /// [0, durationMs]. Informational only: the host player is the truth.
  int estimatedPositionMs(DateTime now, {int? durationMs}) {
    var position = positionMs;
    final at = updatedAt;
    if (isPlaying && at != null) {
      var elapsed = now.difference(at).inMilliseconds;
      if (elapsed > staleAfter.inMilliseconds) {
        elapsed = staleAfter.inMilliseconds;
      }
      if (elapsed > 0) position += elapsed;
    }
    if (durationMs != null && position > durationMs) position = durationMs;
    return position < 0 ? 0 : position;
  }
}
