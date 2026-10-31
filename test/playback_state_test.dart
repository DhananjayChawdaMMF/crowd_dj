import 'package:crowd_dj/core/utils/formatters.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  group('PlaybackState.estimatedPositionMs', () {
    test('playing extrapolates from the snapshot time', () {
      final s = PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 10000,
        updatedAt: t0,
        version: 3,
      );
      expect(s.estimatedPositionMs(t0.add(const Duration(seconds: 5))), 15000);
    });

    test('paused and stopped do not advance', () {
      for (final status in [PlaybackStatus.paused, PlaybackStatus.stopped]) {
        final s = PlaybackState(
          status: status,
          positionMs: 4200,
          updatedAt: t0,
          version: 1,
        );
        expect(s.estimatedPositionMs(t0.add(const Duration(minutes: 5))), 4200);
      }
    });

    test('clamps to the song duration', () {
      final s = PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 170000,
        updatedAt: t0,
        version: 1,
      );
      expect(
        s.estimatedPositionMs(
          t0.add(const Duration(minutes: 1)),
          durationMs: 185000,
        ),
        185000,
      );
    });

    test('client clock behind the server never goes backwards', () {
      final s = PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 8000,
        updatedAt: t0,
        version: 1,
      );
      expect(
        s.estimatedPositionMs(t0.subtract(const Duration(seconds: 3))),
        8000,
      );
    });

    test('stopped default and unknown status parse safely', () {
      expect(const PlaybackState.stopped().estimatedPositionMs(t0), 0);
      expect(PlaybackStatus.parse('weird'), PlaybackStatus.stopped);
      expect(PlaybackStatus.parse('playing'), PlaybackStatus.playing);
    });
  });

  group('Formatters', () {
    test('duration', () {
      expect(Formatters.duration(185000), '3:05');
      expect(Formatters.duration(0), '0:00');
      expect(Formatters.duration(null), '--:--');
    });

    test('timeAgo', () {
      expect(
        Formatters.timeAgo(t0, t0.add(const Duration(seconds: 10))),
        'just now',
      );
      expect(
        Formatters.timeAgo(t0, t0.add(const Duration(minutes: 5))),
        '5m ago',
      );
      expect(
        Formatters.timeAgo(t0, t0.add(const Duration(hours: 3))),
        '3h ago',
      );
    });
  });
}
