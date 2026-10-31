import 'package:crowd_dj/features/audience/presentation/audience_controller.dart';
import 'package:crowd_dj/features/audience/presentation/audience_screen.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_controller.dart';
import 'package:crowd_dj/features/dj_dashboard/presentation/dj_dashboard_screen.dart';
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
      )
      ..participants = [
        Participant(
          id: 'p-host',
          roomId: 'room-1',
          userId: 'u-host',
          displayName: 'DJ Ann',
          role: ParticipantRole.host,
        ),
        Participant(
          id: 'p-guest',
          roomId: 'room-1',
          userId: 'u-guest',
          displayName: 'Bob',
          role: ParticipantRole.guest,
        ),
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('DJ approves, rejects and removes; close room asks to confirm', (
    tester,
  ) async {
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
    Get.put(
      DJDashboardController(room, q, r, makePlayer(room, q, rooms)),
      tag: tag,
    );
    await tester.runAsync(room.load);
    await pump(tester, const DJDashboardScreen(code: 'ABC1234567'));

    await tester.tap(find.text('Approve'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(recs.reviewed, {'r1': true});

    await tester.tap(find.byTooltip('Remove from queue'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(queue.removed, ['q1']);

    await tester.tap(find.text('Close room'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Close this room?'), findsOneWidget);
    expect(rooms.closed, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(rooms.closed, isFalse);
  });

  testWidgets('guest searches the demo catalog and recommends a song', (
    tester,
  ) async {
    final tag = roomTag(ParticipantRole.guest, 'ABC1234567');
    final room = Get.put(
      RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.guest,
        sessions: _Sessions('u-guest'),
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
    Get.put(AudienceController(room, q, r, s), tag: tag);
    await tester.runAsync(room.load);
    await pump(tester, const AudienceScreen(code: 'ABC1234567'));

    expect(find.text('Recommend a song'), findsOneWidget);
    expect(find.textContaining('Sample data'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.byTooltip('Remove from queue'), findsNothing);

    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Golden Hour (Demo)'), findsOneWidget);

    await tester.tap(find.text('Recommend'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(recs.recommended.single.providerSongId, 'demo-003');
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('recommendations turned off hides search for guests', (
    tester,
  ) async {
    rooms.room = Room(
      id: 'room-1',
      code: 'ABC1234567',
      name: 'Friday Party',
      description: null,
      hostUserId: 'u-host',
      isActive: true,
      isPublic: false,
      allowRecommendations: false,
      enableVoting: false,
    );
    final tag = roomTag(ParticipantRole.guest, 'ABC1234567');
    final room = Get.put(
      RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.guest,
        sessions: _Sessions('u-guest'),
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
    Get.put(AudienceController(room, q, r, s), tag: tag);
    await tester.runAsync(room.load);
    await pump(tester, const AudienceScreen(code: 'ABC1234567'));

    expect(find.text('Recommendations are turned off'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('guest sees "DJ offline" only when presence excludes the host', (
    tester,
  ) async {
    final tag = roomTag(ParticipantRole.guest, 'ABC1234567');
    final room = Get.put(
      RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.guest,
        sessions: _Sessions('u-guest'),
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
    Get.put(AudienceController(room, q, r, s), tag: tag);
    await tester.runAsync(room.load);
    await pump(tester, const AudienceScreen(code: 'ABC1234567'));

    expect(find.text('DJ offline'), findsNothing); // presence unknown

    room.onlineIds.value = {'p-guest', 'p-host'};
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DJ offline'), findsNothing);

    room.onlineIds.value = {'p-guest'};
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DJ offline'), findsOneWidget);
  });

  testWidgets('DJ console warns when the room is open in another tab', (
    tester,
  ) async {
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
    Get.put(
      DJDashboardController(room, q, r, makePlayer(room, q, rooms)),
      tag: tag,
    );
    await tester.runAsync(room.load);
    await pump(tester, const DJDashboardScreen(code: 'ABC1234567'));

    expect(find.textContaining('open in another tab'), findsNothing);
    room.presenceCounts.value = {'p-host': 2};
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('open in another tab'), findsOneWidget);
    room.presenceCounts.value = {'p-host': 1};
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('open in another tab'), findsNothing);
  });

  testWidgets('phone layout: the close-room button asks for confirmation', (
    tester,
  ) async {
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
    Get.put(
      DJDashboardController(room, q, r, makePlayer(room, q, rooms)),
      tag: tag,
    );
    await tester.runAsync(room.load);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: DJDashboardScreen(code: 'ABC1234567')),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Close room'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Close this room?'), findsOneWidget);
    expect(rooms.closed, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Close this room?'), findsNothing);
  });
}
