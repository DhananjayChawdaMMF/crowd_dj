import 'package:crowd_dj/core/services/server_clock.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
import 'package:crowd_dj/features/queue/presentation/queue_controller.dart';
import 'package:crowd_dj/features/recommendations/presentation/recommendation_controller.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/domain/room_realtime.dart';
import 'package:crowd_dj/features/room/presentation/room_controller.dart';
import 'package:crowd_dj/features/room/presentation/room_realtime_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

class _Sessions extends FakeSessions {
  @override
  Future<String> ensureSignedIn() async => 'u-guest';
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeRoomRepository rooms;
  late FakeQueueRepository queueRepo;
  late FakeRealtime realtime;
  late RoomController room;
  late RoomRealtimeController controller;

  setUp(() async {
    Get.reset();
    rooms = FakeRoomRepository()
      ..participants = [
        const Participant(
          id: 'p-host',
          roomId: 'room-1',
          userId: 'u-host',
          displayName: 'DJ',
          role: ParticipantRole.host,
        ),
        const Participant(
          id: 'p-guest',
          roomId: 'room-1',
          userId: 'u-guest',
          displayName: 'Bob',
          role: ParticipantRole.guest,
        ),
      ]
      ..room = Room(
        id: 'room-1',
        code: 'ABC1234567',
        name: 'Party',
        description: null,
        hostUserId: 'u-host',
        isActive: true,
        isPublic: false,
        allowRecommendations: true,
        enableVoting: false,
      );
    queueRepo = FakeQueueRepository();
    realtime = FakeRealtime();
    room = Get.put(
      RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.guest,
        sessions: _Sessions(),
        rooms: rooms,
      ),
    );
    final queue = Get.put(QueueController(queueRepo, room));
    final recs = Get.put(
      RecommendationController(FakeRecommendationRepository(), room),
    );
    controller = Get.put(
      RoomRealtimeController(
        realtime: realtime,
        room: room,
        queue: queue,
        recommendations: recs,
        debounce: const Duration(milliseconds: 20),
      ),
    );
    await room.load();
    await wait(10);
  });

  tearDown(Get.reset);

  test('connects once the room and participant are known', () {
    expect(realtime.connects, 1);
    expect(realtime.roomId, 'room-1');
    expect(realtime.me!.id, 'p-guest');
  });

  test('a burst of queue events causes a single reload', () async {
    final before = queueRepo.fetchCount;
    for (var i = 0; i < 5; i++) {
      realtime.onChange!(RoomChange.queue);
    }
    await wait(80);
    expect(queueRepo.fetchCount, before + 1);
  });

  test(
    'room events reload the room (authoritative read, not the payload)',
    () async {
      final before = rooms.fetchRoomCount;
      realtime.onChange!(RoomChange.room);
      await wait(80);
      expect(rooms.fetchRoomCount, before + 1);
    },
  );

  test('a playback change reaches the guest through a reload', () async {
    rooms.room = rooms.room!.copyWith(
      currentSong: demoSong,
      playback: PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 1000,
        updatedAt: DateTime.now(),
        version: 3,
      ),
    );
    realtime.onChange!(RoomChange.room);
    await wait(80);
    expect(room.room.value!.currentSong!.title, 'Demo Song');
    expect(room.room.value!.playback.isPlaying, isTrue);
  });

  test('presence drives the online count and host-offline detection', () async {
    expect(room.audienceCount, 2); // presence unknown: falls back to joined
    realtime.onPresence!({'p-guest': 1});
    expect(room.audienceCount, 1);
    expect(room.isOnline('p-guest'), isTrue);
    expect(room.hostOnline, isFalse);
    realtime.onPresence!({'p-guest': 1, 'p-host': 1});
    expect(room.hostOnline, isTrue);
    expect(room.audienceCount, 2);
  });

  test('several tabs of the same participant are detected', () async {
    expect(room.openInAnotherTab, isFalse);
    realtime.onPresence!({'p-guest': 2, 'p-host': 1});
    expect(room.openInAnotherTab, isTrue); // the caller is p-guest here
    expect(room.audienceCount, 2); // still two people, not three connections
    realtime.onPresence!({'p-guest': 1, 'p-host': 1});
    expect(room.openInAnotherTab, isFalse);
  });

  test('reconnecting resyncs everything; first connect does not', () async {
    realtime.onStatus!(RealtimeStatus.connected);
    await wait(30);
    final q0 = queueRepo.fetchCount;
    final r0 = rooms.fetchRoomCount;

    realtime.onStatus!(RealtimeStatus.reconnecting);
    expect(room.connection.value, RealtimeStatus.reconnecting);
    expect(queueRepo.fetchCount, q0);

    realtime.onStatus!(RealtimeStatus.connected);
    await wait(30);
    expect(queueRepo.fetchCount, q0 + 1);
    expect(rooms.fetchRoomCount, r0 + 1);
    expect(room.connection.value, RealtimeStatus.connected);
  });

  test('closing the controller closes the subscription', () async {
    Get.delete<RoomRealtimeController>();
    await wait(10);
    expect(realtime.closed, isTrue);
  });

  test('events after dispose are ignored', () async {
    final before = queueRepo.fetchCount;
    Get.delete<RoomRealtimeController>();
    realtime.onChange!(RoomChange.queue);
    await wait(60);
    expect(queueRepo.fetchCount, before);
    expect(controller.status.value, isNotNull);
  });

  group('ServerClock', () {
    test('corrects for a local clock that is behind the server', () async {
      final local = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final clock = ServerClock(
        localNow: () => local,
        fetchServerTime: () async => local.add(const Duration(seconds: 5)),
      );
      await clock.sync();
      expect(clock.offset, const Duration(seconds: 5));
      expect(clock.now(), local.add(const Duration(seconds: 5)));
    });

    test('keeps zero offset when the server cannot be reached', () async {
      final clock = ServerClock(fetchServerTime: () async => throw Exception());
      await clock.sync();
      expect(clock.offset, Duration.zero);
    });
  });

  group('PlaybackState staleness', () {
    test('stops extrapolating after the heartbeat window', () {
      final t0 = DateTime.utc(2026, 1, 1);
      final s = PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 10000,
        updatedAt: t0,
        version: 1,
      );
      expect(
        s.estimatedPositionMs(t0.add(const Duration(minutes: 10))),
        10000 + PlaybackState.staleAfter.inMilliseconds,
      );
    });
  });
}
