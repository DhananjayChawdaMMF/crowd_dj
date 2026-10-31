import 'dart:async';

import 'package:crowd_dj/features/music_search/data/mock_music_provider.dart';
import 'package:crowd_dj/features/music_search/data/song_search_repository_impl.dart';
import 'package:crowd_dj/features/music_search/domain/song_candidate.dart';
import 'package:crowd_dj/features/music_search/domain/song_search_repository.dart';
import 'package:crowd_dj/features/music_search/presentation/music_search_controller.dart';
import 'package:crowd_dj/features/queue/domain/queue_item.dart';
import 'package:crowd_dj/features/queue/presentation/queue_controller.dart';
import 'package:crowd_dj/features/recommendations/presentation/recommendation_controller.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/presentation/room_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

class _Sessions extends FakeSessions {
  @override
  Future<String> ensureSignedIn() async => 'user-1';
}

class _ControlledSearch implements SongSearchRepository {
  final pending = <String, Completer<List<SongCandidate>>>{};

  @override
  String get catalogName => 'test';
  @override
  bool get isDemoCatalog => false;

  @override
  Future<List<SongCandidate>> searchSongs(String query) =>
      (pending[query] = Completer<List<SongCandidate>>()).future;
}

const _a = SongCandidate(
  provider: 'mock',
  providerSongId: 'a',
  title: 'A',
  artist: 'X',
);
const _b = SongCandidate(
  provider: 'mock',
  providerSongId: 'b',
  title: 'B',
  artist: 'Y',
);

void main() {
  setUp(Get.reset);

  group('MockMusicProvider', () {
    const provider = MockMusicProvider();

    test(
      'is labelled as demo data; audio is bundled, unknown ids have none',
      () async {
        expect(provider.isDemo, isTrue);
        expect(provider.displayName.toLowerCase(), contains('sample'));
        expect(
          (await provider.getPlayableSource('demo-001'))?.assetPath,
          'assets/audio/demo-001.mp3',
        );
        expect(await provider.getPlayableSource('nope'), isNull);
      },
    );

    test('every title is visibly marked as a demo entry', () async {
      final all = await provider.searchSongs('demo');
      expect(all, isNotEmpty);
      expect(all.every((s) => s.title.contains('(Demo)')), isTrue);
    });

    test(
      'search is case-insensitive over title and artist; empty is empty',
      () async {
        expect(
          (await provider.searchSongs('NEON')).single.providerSongId,
          'demo-001',
        );
        expect((await provider.searchSongs('artist beta')).length, 2);
        expect(await provider.searchSongs('   '), isEmpty);
        expect(await provider.searchSongs('zzzz'), isEmpty);
      },
    );

    test('details lookup', () async {
      expect(
        (await provider.getSongDetails('demo-003'))?.title,
        'Golden Hour (Demo)',
      );
      expect(await provider.getSongDetails('nope'), isNull);
    });
  });

  group('MusicSearchController', () {
    test('short queries clear results without searching', () async {
      final c = MusicSearchController(
        const SongSearchRepositoryImpl(MockMusicProvider()),
      );
      await c.search('neon');
      expect(c.results, hasLength(1));
      await c.search('n');
      expect(c.results, isEmpty);
      expect(c.searched.value, isFalse);
    });

    test('a stale response never overwrites a newer one', () async {
      final repo = _ControlledSearch();
      final c = MusicSearchController(repo);
      final first = c.search('ab');
      final second = c.search('abc');
      repo.pending['abc']!.complete([_b]);
      await second;
      repo.pending['ab']!.complete([_a]); // arrives late
      await first;
      expect(c.results.single.providerSongId, 'b');
      expect(c.loading.value, isFalse);
    });

    test('errors are surfaced as a message', () async {
      final repo = _ControlledSearch();
      final c = MusicSearchController(repo);
      final f = c.search('ab');
      repo.pending['ab']!.completeError(Exception('boom'));
      await f;
      expect(c.errorMessage.value, isNotNull);
      expect(c.loading.value, isFalse);
    });
  });

  group('Recommendation / queue / room actions', () {
    late FakeRoomRepository rooms;
    late FakeRecommendationRepository recs;
    late FakeQueueRepository queue;
    late RoomController room;
    late RecommendationController recC;
    late QueueController queueC;

    setUp(() async {
      rooms = FakeRoomRepository()
        ..participants = [
          Participant(
            id: 'p-1',
            roomId: 'room-1',
            userId: 'user-1',
            displayName: 'Sam',
            role: ParticipantRole.host,
          ),
        ];
      recs = FakeRecommendationRepository();
      queue = FakeQueueRepository();
      room = RoomController(
        code: 'ABC1234567',
        expectedRole: ParticipantRole.host,
        sessions: _Sessions(),
        rooms: rooms,
      );
      await room.load();
      recC = RecommendationController(recs, room);
      queueC = QueueController(queue, room);
    });

    test('submit sends the song and marks it sent', () async {
      expect(await recC.submit(_a), isTrue);
      expect(recs.recommended.single.key, 'mock:a');
      expect(recC.sentKeys, contains('mock:a'));
      expect(recC.notice.value, contains('Sent'));
    });

    test('submit maps already_recommended to a friendly message', () async {
      recs.failure = failure('already_recommended');
      expect(await recC.submit(_a), isFalse);
      expect(recC.sentKeys, contains('mock:a'));
      expect(recC.notice.value, 'already_recommended'); // fake echoes code
    });

    test('submit is blocked when recommendations are disabled', () async {
      rooms.room = Room(
        id: 'room-1',
        code: 'ABC1234567',
        name: 'Party',
        description: null,
        hostUserId: 'user-1',
        isActive: true,
        isPublic: false,
        allowRecommendations: false,
        enableVoting: false,
      );
      await room.load();
      expect(await recC.submit(_a), isFalse);
      expect(recs.recommended, isEmpty);
    });

    test('approve and reject call the review RPC', () async {
      expect(await recC.review('r1', approve: true), isTrue);
      expect(await recC.review('r2', approve: false), isTrue);
      expect(recs.reviewed, {'r1': true, 'r2': false});
      expect(recC.busyIds, isEmpty);
    });

    test('review failure is reported and busy flag is released', () async {
      recs.failure = failure('already_reviewed');
      expect(await recC.review('r1', approve: true), isFalse);
      expect(recC.notice.value, isNotNull);
      expect(recC.busyIds, isEmpty);
    });

    test('queue remove calls the RPC and reloads', () async {
      queue.items = [
        const QueueItem(
          id: 'q1',
          position: 0,
          song: demoSong,
          isPlaying: false,
        ),
      ];
      await queueC.load();
      expect(queueC.upcoming, hasLength(1));
      queue.items = [];
      expect(await queueC.remove('q1'), isTrue);
      expect(queue.removed, ['q1']);
      expect(queueC.items, isEmpty);
    });

    test('closeRoom closes and reflects the closed state', () async {
      expect(await room.closeRoom(), isTrue);
      expect(rooms.closed, isTrue);
      expect(room.room.value!.isActive, isFalse);
    });

    test('closeRoom failure leaves the room open and sets a notice', () async {
      rooms.failure = failure('forbidden');
      expect(await room.closeRoom(), isFalse);
      expect(room.room.value!.isActive, isTrue);
      expect(room.notice.value, isNotNull);
      expect(room.closing.value, isFalse);
    });
  });
}
