import 'package:crowd_dj/core/routes/app_router.dart';
import 'package:crowd_dj/core/services/session_provider.dart';
import 'package:crowd_dj/features/room/domain/room_repository.dart';
import 'package:crowd_dj/features/audience/presentation/audience_controller.dart';
import 'package:crowd_dj/features/audience/presentation/audience_screen.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_controller.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_screen.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
import 'package:crowd_dj/features/music_search/domain/song.dart';
import 'package:crowd_dj/features/music_search/data/mock_music_provider.dart';
import 'package:crowd_dj/features/music_search/data/song_search_repository_impl.dart';
import 'package:crowd_dj/features/music_search/presentation/music_search_controller.dart';
import 'package:crowd_dj/features/queue/domain/queue_item.dart';
import 'package:crowd_dj/features/queue/presentation/queue_controller.dart';
import 'package:crowd_dj/features/recommendations/domain/recommendation.dart';
import 'package:crowd_dj/features/recommendations/presentation/recommendation_controller.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/presentation/room_controller.dart';
import 'package:crowd_dj/features/room/presentation/room_controllers_binding.dart';
import 'package:crowd_dj/main.dart';
import 'package:crowd_dj/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

/// Every screen must lay out without overflow or other framework errors from
/// small phones up to large desktops (and with long names / many items).
const widths = <double>[320, 360, 390, 430, 600, 768, 1024, 1280, 1440, 1920];

class _Sessions extends FakeSessions {
  _Sessions(this.id);
  final String id;
  @override
  Future<String> ensureSignedIn() async => id;
}

Future<void> _size(WidgetTester tester, double w, [double h = 900]) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    // Tests default to the "Ahem" font (every glyph is a full-width square),
    // which makes text about twice as wide as reality. Use the real font.
    final loader = FontLoader(AppTheme.fontFamily);
    for (final w in [400, 700]) {
      loader.addFont(rootBundle.load('assets/fonts/InterTight-$w.ttf'));
    }
    await loader.load();
  });

  setUp(() {
    Get.reset();
    // The router is a process-wide singleton: start every test from the home page.
    AppRouter.router.go('/');
  });

  group('landing and create-room', () {
    for (final w in widths) {
      testWidgets('landing at ${w.toInt()}px', (tester) async {
        await _size(tester, w);
        await tester.pumpWidget(const CrowdDjApp());
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Your Music. Your Crowd. Your Vibe.'), findsOneWidget);
      });
    }

    for (final w in [320.0, 390.0, 768.0, 1440.0]) {
      testWidgets('create room at ${w.toInt()}px', (tester) async {
        await _size(tester, w);
        Get.put<SessionProvider>(FakeSessions());
        Get.put<RoomRepository>(FakeRoomRepository());
        await tester.pumpWidget(const CrowdDjApp());
        AppRouter.router.go('/create-room');
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('unknown URL shows a not-found page with a way home', (
      tester,
    ) async {
      await _size(tester, 390);
      await tester.pumpWidget(const CrowdDjApp());
      AppRouter.router.go('/definitely/not/a/page');
      await _settle(tester);
      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
      await tester.tap(find.text('Back to home'));
      await _settle(tester);
      expect(find.text('Your Music. Your Crowd. Your Vibe.'), findsOneWidget);
    });
  });

  group('dashboards', () {
    late FakeRoomRepository rooms;
    late FakeQueueRepository queue;
    late FakeRecommendationRepository recs;

    const longName =
        'A very long room name that keeps going and going well past any sensible width';

    setUp(() {
      rooms = FakeRoomRepository()
        ..room = Room(
          id: 'room-1',
          code: 'ABC1234567',
          name: longName,
          description: null,
          hostUserId: 'u-host',
          isActive: true,
          isPublic: false,
          allowRecommendations: true,
          enableVoting: false,
          currentSong: const Song(
            id: 's1',
            provider: 'mock',
            providerSongId: 'demo-001',
            title: 'An extremely long song title that should be ellipsized somewhere sensible',
            artist: 'An equally long artist name feat. several other people',
            durationMs: 24000,
          ),
          playback: const PlaybackState(
            status: PlaybackStatus.paused,
            positionMs: 9000,
            updatedAt: null,
            version: 3,
          ),
        )
        ..participants = [
          for (var i = 0; i < 12; i++)
            Participant(
              id: 'p$i',
              roomId: 'room-1',
              userId: i == 0 ? 'u-host' : 'u$i',
              displayName: i == 0
                  ? 'DJ With A Really Long Display Name Indeed'
                  : 'Guest number $i',
              role: i == 0 ? ParticipantRole.host : ParticipantRole.guest,
            ),
        ];
      queue = FakeQueueRepository()
        ..items = [
          for (var i = 0; i < 8; i++)
            QueueItem(
              id: 'q$i',
              position: i,
              song: Song(
                id: 'qs$i',
                title: 'Queued track number $i with a long title',
                artist: 'Artist $i',
                durationMs: 24000,
              ),
              isPlaying: false,
              recommendedBy: 'Guest number ${i + 1}',
            ),
        ];
      recs = FakeRecommendationRepository()
        ..items = [
          for (var i = 0; i < 6; i++)
            Recommendation(
              id: 'r$i',
              song: Song(
                id: 'rs$i',
                title: 'Recommended song $i with a rather long title',
                artist: 'Some Artist $i',
                durationMs: 24000,
              ),
              participantId: 'p${i + 1}',
              guestName: 'Guest number ${i + 1}',
              status: RecommendationStatus.pending,
              createdAt: DateTime.now(),
            ),
        ];
    });

    for (final w in widths) {
      testWidgets('DJ console at ${w.toInt()}px', (tester) async {
        await _size(tester, w);
        final tag = roomTag(ParticipantRole.host, 'ABC1234567');
        final room = Get.put(
          RoomController(
            code: 'ABC1234567',
            expectedRole: ParticipantRole.host,
            sessions: _Sessions('u-host'),
            rooms: rooms,
          ),
          tag: tag,
        );
        final q = Get.put(QueueController(queue, room), tag: tag);
        final r = Get.put(RecommendationController(recs, room), tag: tag);
        final dj = Get.put(
          DJDashboardController(room, q, r, makePlayer(room, q, rooms)),
          tag: tag,
        );
        await tester.runAsync(room.load);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: DJDashboardScreen(code: 'ABC1234567'),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);

        // On phones every tab must lay out too.
        if (w < 700) {
          for (final tab in DjTab.values) {
            dj.tab.value = tab;
            await _settle(tester);
            expect(tester.takeException(), isNull, reason: 'tab $tab at $w');
          }
        }
      });

      testWidgets('audience view at ${w.toInt()}px', (tester) async {
        await _size(tester, w);
        final tag = roomTag(ParticipantRole.guest, 'ABC1234567');
        final room = Get.put(
          RoomController(
            code: 'ABC1234567',
            expectedRole: ParticipantRole.guest,
            sessions: _Sessions('u1'),
            rooms: rooms,
          ),
          tag: tag,
        );
        final q = Get.put(QueueController(queue, room), tag: tag);
        final r = Get.put(RecommendationController(recs, room), tag: tag);
        final s = Get.put(
          MusicSearchController(
            const SongSearchRepositoryImpl(MockMusicProvider()),
          ),
          tag: tag,
        );
        final a = Get.put(AudienceController(room, q, r, s), tag: tag);
        await tester.runAsync(room.load);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: AudienceScreen(code: 'ABC1234567'),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);

        if (w < 700) {
          for (final tab in AudienceTab.values) {
            a.tab.value = tab;
            await _settle(tester);
            expect(tester.takeException(), isNull, reason: 'tab $tab at $w');
          }
        }
      });
    }
  });
}
