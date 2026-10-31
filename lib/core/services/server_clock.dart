/// Wall clock corrected by the offset to the server, so playback positions
/// extrapolated from server timestamps are not skewed by a wrong local clock.
class ServerClock {
  ServerClock({
    Future<DateTime> Function()? fetchServerTime,
    DateTime Function()? localNow,
  }) : _fetch = fetchServerTime,
       _localNow = localNow ?? DateTime.now;

  final Future<DateTime> Function()? _fetch;
  final DateTime Function() _localNow;

  Duration _offset = Duration.zero;

  Duration get offset => _offset;

  DateTime now() => _localNow().add(_offset);

  /// Best effort: on failure the clock keeps the previous offset (initially 0).
  Future<void> sync() async {
    final fetch = _fetch;
    if (fetch == null) return;
    try {
      final sentAt = _localNow();
      final server = await fetch();
      final receivedAt = _localNow();
      final roundTrip = receivedAt.difference(sentAt);
      // Assume the server stamped the time halfway through the round trip.
      final localAtStamp = sentAt.add(roundTrip ~/ 2);
      _offset = server.difference(localAtStamp);
    } catch (_) {}
  }
}
