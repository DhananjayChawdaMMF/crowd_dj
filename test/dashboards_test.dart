import 'package:crowd_dj/core/services/server_clock.dart';
import 'package:crowd_dj/core/services/session_provider.dart';
import 'package:crowd_dj/features/room/domain/room_realtime.dart';
import 'package:crowd_dj/features/audience/presentation/audience_controller.dart';
import 'package:crowd_dj/features/queue/domain/queue_repository.dart';
import 'package:crowd_dj/features/recommendations/domain/recommendation_repository.dart';
import 'package:crowd_dj/features/room/domain/room_repository.dart';
import 'package:crowd_dj/features/audience/presentation/audience_screen.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_controller.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_screen.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

class _Sessions extends FakeSessions {
  _Sessions(this.id);
  final String id;
  @override
  Future<String> ensureSignedIn() async => id;
}

Participant _p(String id, String user, String name, ParticipantRole role) =>
    Participant(
      id: id,
      roomId: 'room-1',
      userId: user,
      displayName: name,
      role: role,
    );

void main() {
  late FakeRoomRepository rooms;
  late FakeQueueRepository queue;
  late FakeRecommendationRepository recs;

  setUp(() {
    Get.reset();
    rooms = FakeRoomRepository()
      ..room = Room(
        id: 'room-1',
        code: 'ABC1234567',
        name: 'Friday Party',
        description: null,
        hostUserId: 'u-host',
        isActive: true,
        isPublic: false,
        allowRecommendations: true,
        enableVoting: false,
        currentSong: demoSong,
        playback: const PlaybackState(
          status: PlaybackStatus.paused,
          positionMs: 60000,
          updatedAt: null,
          version: 2,
        ),
      )
      ..participants = [
        _p('p-host', 'u-host', 'DJ Ann', ParticipantRole.host),
        _p('p-guest', 'u-guest', 'Bob', ParticipantRole.guest),
      ];
    queue = FakeQueueRepository()
      ..items = [
        const QueueItem(
          id: 'q1',
          position: 0,
          song: nextSong,
          isPlaying: false,
          recommendedBy: 'Bob',
        ),
      ];
    recs = FakeRecommendationRepository()
      ..items = [
        Recommendation(
          id: 'r1',
          song: demoSong,
          participantId: 'p-guest',
          guestName: 'Bob',
          status: RecommendationStatus.pending,
          createdAt: DateTime.now(),
        ),
      ];
  });

  RoomController roomController(String user, ParticipantRole role) => Get.put(
    RoomController(
      code: 'ABC1234567',
      expectedRole: role,
      sessions: _Sessions(user),
      rooms: rooms,
      baseUri: Uri.parse('https://crowddj.app/anything?x=1'),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('controller registry', () {
    test('host and guest dashboards of one room do not share or delete controllers', () {
      Get.put<SessionProvider>(_Sessions('u-host'));
      Get.put<ServerClock>(ServerClock());
      Get.put<RoomRealtime>(FakeRealtime());
      Get.put<RoomRepository>(rooms);
      Get.put<QueueRepository>(queue);
      Get.put<RecommendationRepository>(recs);

      registerRoomControllers('abc1234567', ParticipantRole.host);
      registerRoomControllers('ABC1234567', ParticipantRole.guest);
      final hostTag = roomTag(ParticipantRole.host, 'ABC1234567');
      final guestTag = roomTag(ParticipantRole.guest, 'ABC1234567');

      final host = Get.find<RoomController>(tag: hostTag);
      final guest = Get.find<RoomController>(tag: guestTag);
      expect(host.expectedRole, ParticipantRole.host);
      expect(guest.expectedRole, ParticipantRole.guest);

      // Old route disposing must not remove the new route's controller.
      deleteRoomControllers('ABC1234567', ParticipantRole.host);
      expect(Get.isRegistered<RoomController>(tag: hostTag), isFalse);
      expect(Get.isRegistered<RoomController>(tag: guestTag), isTrue);
    });
  });

  group('RoomController guard', () {
    test(
      'guest opening the DJ route is redirected to the guest dashboard',
      () async {
        final c = roomController('u-guest', ParticipantRole.host);
        await c.load();
        expect(c.redirectTo.value, '/room/ABC1234567/guest');
        expect(c.room.value, isNull);
      },
    );

    test(
      'host opening the guest route is redirected to the DJ dashboard',
      () async {
        final c = roomController('u-host', ParticipantRole.guest);
        await c.load();
        expect(c.redirectTo.value, '/room/ABC1234567/dj');
      },
    );

    test('non-member is sent to the join page', () async {
      final c = roomController('stranger', ParticipantRole.guest);
      await c.load();
      expect(c.redirectTo.value, '/room/ABC1234567');
    });

    test('share url is the clean room link', () {
      final c = roomController('u-host', ParticipantRole.host);
      expect(c.shareUrl, 'https://crowddj.app/room/ABC1234567');
    });
  });

  group('DJ dashboard', () {
    Future<void> pumpDj(WidgetTester tester, {double width = 1400}) async {
      final room = roomController('u-host', ParticipantRole.host);
      final tag = roomTag(ParticipantRole.host, 'ABC1234567');
      final q = Get.put(QueueController(queue, room), tag: tag);
      final r = Get.put(RecommendationController(recs, room), tag: tag);
      Get.put(
        DJDashboardController(room, q, r, makePlayer(room, q, rooms)),
        tag: tag,
      );
      await tester.runAsync(room.load);
      await pump(
        tester,
        const DJDashboardScreen(code: 'ABC1234567'),
        width: width,
      );
    }

    testWidgets('desktop shows console, queue, recommendations and audience', (
      tester,
    ) async {
      await pumpDj(tester);
      expect(find.text('Friday Party'), findsOneWidget);
      expect(find.text('Demo Song'), findsWidgets);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Close room'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('DJ Ann (you)'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('mobile uses bottom navigation and switches tabs', (
      tester,
    ) async {
      await pumpDj(tester, width: 400);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Up next'), findsNothing);
      await tester.tap(find.text('Queue'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Up next'), findsOneWidget);
    });
  });

  group('Audience dashboard', () {
    testWidgets('guest sees no host controls', (tester) async {
      final room = roomController('u-guest', ParticipantRole.guest);
      final tag = roomTag(ParticipantRole.guest, 'ABC1234567');
      final q = Get.put(QueueController(queue, room), tag: tag);
      final r = Get.put(RecommendationController(recs, room), tag: tag);
      Get.put(
        AudienceController(
          room,
          q,
          r,
          Get.put(
            MusicSearchController(
              const SongSearchRepositoryImpl(MockMusicProvider()),
            ),
            tag: tag,
          ),
        ),
        tag: tag,
      );
      await tester.runAsync(room.load);
      await pump(tester, const AudienceScreen(code: 'ABC1234567'));

      expect(find.text('Friday Party'), findsOneWidget);
      expect(find.text('Demo Song'), findsWidgets);
      expect(find.text('Your recommendations'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Close room'), findsNothing);
      expect(find.text('Approve'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    });
  });
}
