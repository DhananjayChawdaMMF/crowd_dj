import 'package:crowd_dj/core/errors/app_failure.dart';
import 'package:crowd_dj/core/services/session_provider.dart';

import 'dart:async';

import 'package:crowd_dj/features/music_player/presentation/music_player_controller.dart';
import 'package:crowd_dj/features/music_search/data/mock_music_provider.dart';
import 'package:crowd_dj/features/queue/presentation/queue_controller.dart';
import 'package:crowd_dj/features/room/presentation/room_controller.dart';

import 'package:crowd_dj/features/music_player/domain/audio_playback_service.dart';
import 'package:crowd_dj/features/music_player/domain/playback_repository.dart';
import 'package:crowd_dj/features/music_player/domain/playback_state.dart';
import 'package:crowd_dj/features/room/domain/room_realtime.dart';
import 'package:crowd_dj/features/music_search/domain/song.dart';
import 'package:crowd_dj/features/music_search/domain/song_candidate.dart';
import 'package:crowd_dj/features/queue/domain/queue_item.dart';
import 'package:crowd_dj/features/queue/domain/queue_repository.dart';
import 'package:crowd_dj/features/recommendations/domain/recommendation.dart';
import 'package:crowd_dj/features/recommendations/domain/recommendation_repository.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/domain/room_repository.dart';

class FakeSessions implements SessionProvider {
  int signIns = 0;

  @override
  Future<String> ensureSignedIn() async {
    signIns++;
    return 'user-1';
  }
}

final fakeRoom = Room(
  id: 'room-1',
  code: 'ABC1234567',
  name: 'Party',
  description: null,
  hostUserId: 'user-1',
  isActive: true,
  isPublic: false,
  allowRecommendations: true,
  enableVoting: false,
);

Participant fakeParticipant(ParticipantRole role, [String name = 'Sam']) =>
    Participant(
      id: 'p-1',
      roomId: 'room-1',
      userId: 'user-1',
      displayName: name,
      role: role,
    );

class FakeRoomRepository implements RoomRepository {
  RoomPreview preview = const RoomPreview(
    code: 'ABC1234567',
    name: 'Party',
    description: null,
    hostName: 'DJ Ann',
    isActive: true,
    isHost: false,
    myDisplayName: null,
  );
  Object? failure;
  CreateRoomParams? created;
  String? joinedAs;

  @override
  Future<RoomSession> createRoom(CreateRoomParams params) async {
    if (failure != null) throw failure!;
    created = params;
    return RoomSession(
      room: fakeRoom,
      participant: fakeParticipant(ParticipantRole.host),
    );
  }

  @override
  Future<RoomPreview> getPreview(String code) async {
    if (failure != null) throw failure!;
    return preview;
  }

  Room? room;
  List<Participant> participants = [];

  bool closed = false;
  int fetchRoomCount = 0;

  @override
  Future<void> closeRoom(String roomId) async {
    if (failure != null) throw failure!;
    closed = true;
    final r = room ?? fakeRoom;
    room = Room(
      id: r.id,
      code: r.code,
      name: r.name,
      description: r.description,
      hostUserId: r.hostUserId,
      isActive: false,
      isPublic: r.isPublic,
      allowRecommendations: r.allowRecommendations,
      enableVoting: r.enableVoting,
      playback: r.playback,
      currentSong: r.currentSong,
    );
  }

  @override
  Future<Room> fetchRoom(String code) async {
    fetchRoomCount++;
    if (failure != null) throw failure!;
    return room ?? fakeRoom;
  }

  @override
  Future<List<Participant>> fetchParticipants(String roomId) async =>
      participants;

  @override
  Future<RoomSession> joinRoom(String code, String displayName) async {
    if (failure != null) throw failure!;
    joinedAs = displayName;
    return RoomSession(
      room: fakeRoom,
      participant: fakeParticipant(
        preview.isHost ? ParticipantRole.host : ParticipantRole.guest,
        displayName,
      ),
    );
  }
}

AppFailure failure(String code) => AppFailure(code, code: code);

class FakeQueueRepository implements QueueRepository {
  List<QueueItem> items = [];
  Object? failure;

  final removed = <String>[];
  int fetchCount = 0;

  @override
  Future<void> removeItem(String queueId) async {
    if (failure != null) throw failure!;
    removed.add(queueId);
  }

  @override
  Future<List<QueueItem>> fetchQueue(String roomId) async {
    fetchCount++;
    if (failure != null) throw failure!;
    return items;
  }
}

class FakeRecommendationRepository implements RecommendationRepository {
  List<Recommendation> items = [];

  Object? failure;
  final recommended = <SongCandidate>[];
  final reviewed = <String, bool>{};

  @override
  Future<void> recommendSong(String roomId, SongCandidate song) async {
    if (failure != null) throw failure!;
    recommended.add(song);
  }

  @override
  Future<void> review(String recommendationId, {required bool approve}) async {
    if (failure != null) throw failure!;
    reviewed[recommendationId] = approve;
  }

  @override
  Future<List<Recommendation>> fetchRecommendations(String roomId) async =>
      items;
}

const demoSong = Song(
  id: 's1',
  provider: 'mock',
  providerSongId: 'demo-001',
  title: 'Demo Song',
  artist: 'Demo Artist',
  durationMs: 185000,
);

const nextSong = Song(
  id: 's2',
  provider: 'mock',
  providerSongId: 'demo-002',
  title: 'Next Track',
  artist: 'Other Artist',
  durationMs: 200000,
);

// ---- Phase 5 fakes ---------------------------------------------------------

class FakeAudio implements AudioPlaybackService {
  final _state = StreamController<AudioState>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  final loaded = <String>[];
  bool playBlocked = false;
  bool failLoad = false;
  bool disposed = false;
  Duration position = Duration.zero;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> load(PlayableSource source) async {
    if (failLoad) throw Exception('cannot load');
    loaded.add(source.assetPath ?? source.url.toString());
    position = Duration.zero;
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (playBlocked) throw const AutoplayBlockedException();
    _state.add(AudioState.playing);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _state.add(AudioState.paused);
  }

  @override
  Future<void> seek(Duration p) async => position = p;

  @override
  Future<void> stop() async {
    stopCalls++;
    _state.add(AudioState.idle);
  }

  @override
  Duration getPosition() => position;

  @override
  Duration? getDuration() => const Duration(seconds: 24);

  @override
  Stream<AudioState> get playbackStateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _pos.stream;

  void emit(AudioState s) => _state.add(s);

  @override
  Future<void> dispose() async => disposed = true;
}

/// Simulates the backend's play_next / set_playback against [FakeRoomRepository].
class FakePlaybackRepository implements PlaybackRepository {
  FakePlaybackRepository(this.rooms, this.upcoming);

  final FakeRoomRepository rooms;
  final List<Song> upcoming;
  final published = <(PlaybackStatus, int)>[];
  final playNextVersions = <int>[];
  int version = 0;
  Object? failure;

  PlaybackState _state(PlaybackStatus s, int pos) => PlaybackState(
    status: s,
    positionMs: pos,
    updatedAt: DateTime.now(),
    version: version,
  );

  @override
  Future<PlaybackState> setPlayback(
    String roomId,
    PlaybackStatus status,
    int positionMs,
  ) async {
    if (failure != null) throw failure!;
    version++;
    published.add((status, positionMs));
    final st = _state(status, positionMs);
    rooms.room = (rooms.room ?? fakeRoom).copyWith(playback: st);
    return st;
  }

  @override
  Future<PlaybackState> playNext(String roomId, int expectedVersion) async {
    playNextVersions.add(expectedVersion);
    if (failure != null) throw failure!;
    if (expectedVersion != version) throw failure_('stale_playback_version');
    version++;
    final room = rooms.room ?? fakeRoom;
    if (upcoming.isEmpty) {
      final st = _state(PlaybackStatus.stopped, 0);
      rooms.room = room.copyWith(playback: st, clearCurrentSong: true);
      return st;
    }
    final song = upcoming.removeAt(0);
    final st = _state(PlaybackStatus.playing, 0);
    rooms.room = room.copyWith(playback: st, currentSong: song);
    return st;
  }

  AppFailure failure_(String code) => AppFailure(code, code: code);
}

class FakeRealtime implements RoomRealtime {
  void Function(RoomChange)? onChange;
  void Function(Map<String, int>)? onPresence;
  void Function(RealtimeStatus)? onStatus;
  String? roomId;
  Participant? me;
  int connects = 0;
  bool closed = false;

  @override
  Future<RealtimeSubscription> connect({
    required String roomId,
    required Participant me,
    required void Function(RoomChange change) onChange,
    required void Function(Map<String, int> connectionsByParticipant)
    onPresence,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    connects++;
    this.roomId = roomId;
    this.me = me;
    this.onChange = onChange;
    this.onPresence = onPresence;
    this.onStatus = onStatus;
    return _Sub(this);
  }
}

class _Sub implements RealtimeSubscription {
  _Sub(this._owner);
  final FakeRealtime _owner;
  @override
  Future<void> close() async => _owner.closed = true;
}

MusicPlayerController makePlayer(
  RoomController room,
  QueueController queue,
  FakeRoomRepository rooms, {
  FakeAudio? audio,
  List<Song>? upcoming,
  FakePlaybackRepository? repo,
  Duration heartbeat = const Duration(seconds: 30),
}) => MusicPlayerController(
  audio: audio ?? FakeAudio(),
  playback: repo ?? FakePlaybackRepository(rooms, upcoming ?? []),
  provider: const MockMusicProvider(),
  room: room,
  queue: queue,
  heartbeat: heartbeat,
);
