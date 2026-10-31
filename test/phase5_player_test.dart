import 'package:crowd_dj/core/services/server_clock.dart';
import 'package:crowd_dj/features/music_player/domain/audio_playback_service.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
import 'package:crowd_dj/features/music_player/presentation/music_player_controller.dart';
import 'package:crowd_dj/features/music_search/domain/song.dart';
import 'package:crowd_dj/features/queue/presentation/queue_controller.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/presentation/room_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

class _Sessions extends FakeSessions {
  @override
  Future<String> ensureSignedIn() async => 'u-host';
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late FakeRoomRepository rooms;
  late FakeAudio audio;
  late FakePlaybackRepository repo;
  late RoomController room;
  late QueueController queue;
  late MusicPlayerController player;

  Room baseRoom({Song? song, PlaybackState? playback}) => Room(
    id: 'room-1',
    code: 'ABC1234567',
    name: 'Party',
    description: null,
    hostUserId: 'u-host',
    isActive: true,
    isPublic: false,
    allowRecommendations: true,
    enableVoting: false,
    currentSong: song,
    playback: playback ?? const PlaybackState.stopped(),
  );

  Future<void> build({
    Room? initial,
    List<Song>? upcoming,
    Duration heartbeat = const Duration(seconds: 30),
    DateTime Function()? clockNow,
  }) async {
    Get.reset();
    rooms = FakeRoomRepository()
      ..room = initial ?? baseRoom()
      ..participants = [
        const Participant(
          id: 'p-host',
          roomId: 'room-1',
          userId: 'u-host',
          displayName: 'DJ',
          role: ParticipantRole.host,
        ),
      ];
    audio = FakeAudio();
    repo = FakePlaybackRepository(rooms, upcoming ?? [demoSong, nextSong]);
    room = Get.put(
      RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.host,
        sessions: _Sessions(),
        rooms: rooms,
        clock: ServerClock(localNow: clockNow),
      ),
    );
    queue = Get.put(QueueController(FakeQueueRepository(), room));
    await room.load();
    player = Get.put(
      makePlayer(
        room,
        queue,
        rooms,
        audio: audio,
        repo: repo,
        heartbeat: heartbeat,
      ),
    );
    await settle();
  }

  tearDown(Get.reset);

  test(
    'play from stopped advances the queue, loads the asset and plays',
    () async {
      await build();
      await player.togglePlay();
      await settle();

      expect(repo.playNextVersions, [0]);
      expect(room.room.value!.currentSong!.id, 's1');
      expect(audio.loaded.single, 'assets/audio/demo-001.mp3');
      expect(audio.playCalls, 1);
      expect(player.isPlaying.value, isTrue);
      expect(player.needsGesture.value, isFalse);
    },
  );

  test('pause and resume publish status and position', () async {
    await build();
    await player.togglePlay();
    await settle();

    audio.position = const Duration(seconds: 7);
    await player.pause();
    expect(repo.published.last, (PlaybackStatus.paused, 7000));
    expect(room.room.value!.playback.status, PlaybackStatus.paused);

    audio.position = const Duration(seconds: 7);
    await player.resume();
    await settle();
    expect(repo.published.last, (PlaybackStatus.playing, 7000));
    expect(audio.loaded, hasLength(1)); // not reloaded
  });

  test('seek moves the audio and publishes the new position', () async {
    await build();
    await player.togglePlay();
    await settle();

    audio.position = const Duration(seconds: 12);
    await player.seek(12000);
    expect(audio.position, const Duration(seconds: 12));
    expect(repo.published.last, (PlaybackStatus.playing, 12000));
  });

  test('restart seeks to zero', () async {
    await build();
    await player.togglePlay();
    await settle();
    await player.restart();
    expect(audio.position, Duration.zero);
  });

  test('a song ending advances exactly once, even if reported twice', () async {
    await build();
    await player.togglePlay();
    await settle();
    expect(room.room.value!.currentSong!.id, 's1');
    final before = repo.playNextVersions.length;

    audio.emit(AudioState.completed);
    audio.emit(AudioState.completed);
    await settle();
    await settle();

    expect(repo.playNextVersions.length, before + 1);
    expect(room.room.value!.currentSong!.id, 's2');
    expect(audio.loaded.last, 'assets/audio/demo-002.mp3');
  });

  test('a stale version is rejected without loading anything', () async {
    await build();
    await player.togglePlay();
    await settle();
    final loadedBefore = audio.loaded.length;

    // Backend moved on (e.g. duplicate skip) but the client's version is old.
    repo.version += 5;
    final fetchesBefore = rooms.fetchRoomCount;
    await player.next();
    await settle();

    expect(audio.loaded.length, loadedBefore);
    expect(rooms.fetchRoomCount, greaterThan(fetchesBefore)); // resynced
    expect(player.notice.value, isNull); // stale is silent
  });

  test('ending the last song stops playback', () async {
    await build(upcoming: [demoSong]);
    await player.togglePlay();
    await settle();

    audio.emit(AudioState.completed);
    await settle();
    await settle();

    expect(room.room.value!.currentSong, isNull);
    expect(room.room.value!.playback.status, PlaybackStatus.stopped);
    expect(player.isPlaying.value, isFalse);
  });

  test(
    'blocked autoplay asks for a click and tells guests it is paused',
    () async {
      await build();
      audio.playBlocked = true;
      await player.togglePlay();
      await settle();

      expect(player.needsGesture.value, isTrue);
      expect(player.isPlaying.value, isFalse);
      expect(repo.published.last, (PlaybackStatus.paused, 0));

      audio.playBlocked = false;
      await player.togglePlay(); // user click
      await settle();
      expect(player.needsGesture.value, isFalse);
      expect(player.isPlaying.value, isTrue);
    },
  );

  test(
    'after a host reload "playing" is restored as paused at the estimate',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 10);
      final snapshot = PlaybackState(
        status: PlaybackStatus.playing,
        positionMs: 5000,
        updatedAt: now.subtract(const Duration(seconds: 3)),
        version: 4,
      );
      await build(
        initial: baseRoom(song: demoSong, playback: snapshot),
        clockNow: () => now,
      );

      expect(audio.loaded.single, 'assets/audio/demo-001.mp3');
      expect(audio.position, const Duration(milliseconds: 8000));
      expect(audio.playCalls, 0);
      expect(repo.published.single, (PlaybackStatus.paused, 8000));
      expect(player.needsGesture.value, isTrue);
    },
  );

  test(
    'if the audio cannot be loaded, guests are told paused, not playing',
    () async {
      await build();
      audio.failLoad = true;
      await player.togglePlay();
      await settle();

      expect(room.room.value!.currentSong!.id, 's1'); // backend advanced
      expect(player.notice.value, contains('Could not load'));
      expect(player.isPlaying.value, isFalse);
      expect(repo.published.last, (PlaybackStatus.paused, 0));
      expect(room.room.value!.playback.status, PlaybackStatus.paused);
    },
  );

  test('stopped rooms are not restored', () async {
    await build();
    expect(audio.loaded, isEmpty);
    expect(repo.published, isEmpty);
  });

  test('heartbeat republishes while playing', () async {
    await build(heartbeat: const Duration(milliseconds: 40));
    await player.togglePlay();
    await settle();
    final before = repo.published.length;
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(repo.published.length, greaterThan(before));
    expect(repo.published.last.$1, PlaybackStatus.playing);
  });

  test('a failing publish surfaces a notice and does not crash', () async {
    await build();
    await player.togglePlay();
    await settle();
    repo.failure = failure('forbidden');
    await player.pause();
    expect(player.notice.value, isNotNull);
  });

  test('closing the room silences the audio and stops the heartbeat', () async {
    await build(heartbeat: const Duration(milliseconds: 40));
    await player.togglePlay();
    await settle();
    expect(player.isPlaying.value, isTrue);
    final published = repo.published.length;

    rooms.room = rooms.room!.copyWith(isActive: false);
    await room.refreshQuietly();
    await settle();

    expect(audio.stopCalls, 1);
    expect(player.isPlaying.value, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(repo.published.length, published); // no heartbeat after close

    await room.refreshQuietly(); // later refreshes do not stop twice
    expect(audio.stopCalls, 1);
  });

  test('onClose disposes the audio engine', () async {
    await build();
    Get.delete<MusicPlayerController>();
    await settle();
    expect(audio.disposed, isTrue);
  });
}
