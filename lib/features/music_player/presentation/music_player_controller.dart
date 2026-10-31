// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../music_search/domain/music_provider.dart';
import '../../music_search/domain/song.dart';
import '../../queue/presentation/queue_controller.dart';
import '../../room/domain/entities/room.dart';
import '../../room/presentation/room_controller.dart';
import '../domain/audio_playback_service.dart';
import '../domain/playback_repository.dart';
import '../domain/playback_state.dart';

/// Host-only audio controller. Owns the only audio engine in the room, keeps
/// the authoritative playback state in the backend in step with it, and
/// advances the queue. Guests never construct this.
class MusicPlayerController extends GetxController {
  MusicPlayerController({
    required AudioPlaybackService audio,
    required PlaybackRepository playback,
    required MusicProvider provider,
    required RoomController room,
    required QueueController queue,
    this.heartbeat = const Duration(seconds: 30),
  }) : _audio = audio,
       _repo = playback,
       _provider = provider,
       _room = room,
       _queue = queue;

  final AudioPlaybackService _audio;
  final PlaybackRepository _repo;
  final MusicProvider _provider;
  final RoomController _room;
  final QueueController _queue;
  final Duration heartbeat;

  final isPlaying = false.obs;
  final positionMs = 0.obs;
  final busy = false.obs;

  /// True when the browser refused to start audio; the DJ must press play.
  final needsGesture = false.obs;
  final notice = RxnString();

  StreamSubscription<AudioState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  Worker? _roomWorker;
  Timer? _heartbeat;
  String? _loadedSongId;
  bool _advancing = false;
  bool _restored = false;
  bool _seeking = false;
  bool _closed = false;

  Song? get currentSong => _room.room.value?.currentSong;
  int? get durationMs {
    final audioMs = _audio.getDuration()?.inMilliseconds;
    return audioMs ?? currentSong?.durationMs;
  }

  @override
  void onInit() {
    super.onInit();
    _stateSub = _audio.playbackStateStream.listen(_onAudioState);
    _posSub = _audio.positionStream.listen((p) {
      if (!_seeking) positionMs.value = p.inMilliseconds;
    });
    _roomWorker = ever(_room.room, _onRoomChanged);
    _onRoomChanged(_room.room.value);
  }

  void _onRoomChanged(Room? room) {
    if (room == null) return;
    if (!room.isActive) {
      _stopForClosedRoom();
      return;
    }
    if (!_restored) {
      _restored = true;
      restore();
    }
  }

  /// The room was closed (by this DJ or another tab): silence the audio so the
  /// music does not keep playing behind the "room closed" screen.
  void _stopForClosedRoom() {
    if (_closed) return;
    _closed = true;
    _stopHeartbeat();
    isPlaying.value = false;
    unawaited(_audio.stop());
  }

  // ---- user actions ------------------------------------------------------

  Future<void> togglePlay() async {
    if (busy.value) return;
    final room = _room.room.value;
    if (room == null) return;
    if (currentSong == null) return _advance();
    isPlaying.value ? await pause() : await resume();
  }

  Future<void> resume() async {
    final song = currentSong;
    if (song == null) return _advance();
    busy.value = true;
    try {
      if (_loadedSongId != song.id) {
        final startAt = _room.room.value!.playback.estimatedPositionMs(
          _room.clock.now(),
          durationMs: song.durationMs,
        );
        if (!await _load(song, startAtMs: startAt)) return;
      }
      await _startAudio();
      await _publish(PlaybackStatus.playing);
    } finally {
      busy.value = false;
    }
  }

  Future<void> pause() async {
    busy.value = true;
    try {
      await _audio.pause();
      await _publish(PlaybackStatus.paused);
    } finally {
      busy.value = false;
    }
  }

  /// Seek to [ms] and publish the new position.
  Future<void> seek(int ms) async {
    if (currentSong == null) return;
    await _audio.seek(Duration(milliseconds: ms));
    positionMs.value = ms;
    await _publish(
      isPlaying.value ? PlaybackStatus.playing : PlaybackStatus.paused,
    );
  }

  void beginSeek() => _seeking = true;

  void updateSeek(int ms) => positionMs.value = ms;

  Future<void> endSeek(int ms) async {
    _seeking = false;
    await seek(ms);
  }

  /// "Previous" restarts the current song; there is no play history.
  Future<void> restart() => seek(0);

  Future<void> next() async {
    if (busy.value) return;
    await _advance();
  }

  // ---- lifecycle ---------------------------------------------------------

  /// After a host page reload the backend may still say "playing" although no
  /// audio is running. Reload the source at the estimated position and publish
  /// "paused" so guests are not told something false; the DJ presses play.
  Future<void> restore() async {
    final room = _room.room.value;
    final song = room?.currentSong;
    if (room == null || song == null) return;
    final pb = room.playback;
    if (pb.status == PlaybackStatus.stopped) return;
    final pos = pb.estimatedPositionMs(
      _room.clock.now(),
      durationMs: song.durationMs,
    );
    if (await _load(song, startAtMs: pos)) {
      positionMs.value = pos;
      if (pb.status == PlaybackStatus.playing) {
        await _publish(PlaybackStatus.paused, positionOverrideMs: pos);
        needsGesture.value = true;
      }
    } else if (pb.status == PlaybackStatus.playing) {
      // Nothing is playing here, so do not leave the room marked as playing.
      await _publish(PlaybackStatus.paused, positionOverrideMs: pos);
    }
  }

  // ---- internals ---------------------------------------------------------

  Future<void> _advance() async {
    if (_advancing) return;
    _advancing = true;
    busy.value = true;
    try {
      final room = _room.room.value;
      if (room == null) return;
      try {
        await _repo.playNext(room.id, room.playback.version);
      } catch (e) {
        final failure = AppFailure.from(e);
        if (failure.code != 'stale_playback_version') {
          notice.value = failure.message;
        }
        // Someone else (or an earlier call) already moved on: resync and stop.
        await _room.refreshQuietly();
        return;
      }
      await _room.refreshQuietly();
      await _queue.load();

      final song = currentSong;
      if (song == null) {
        await _audio.stop();
        _loadedSongId = null;
        _stopHeartbeat();
        isPlaying.value = false;
        positionMs.value = 0;
        return;
      }
      if (!await _load(song)) {
        // The backend already marked it playing; correct that for the guests.
        await _publish(PlaybackStatus.paused, positionOverrideMs: 0);
        return;
      }
      try {
        await _startAudio();
        _startHeartbeat();
      } catch (_) {
        // Blocked: tell guests the truth (paused at 0) until the DJ taps play.
        await _publish(PlaybackStatus.paused, positionOverrideMs: 0);
      }
    } finally {
      _advancing = false;
      busy.value = false;
    }
  }

  Future<bool> _load(Song song, {int startAtMs = 0}) async {
    try {
      if (song.provider != _provider.id) {
        notice.value = 'No audio source for this song.';
        return false;
      }
      final source = await _provider.getPlayableSource(song.providerSongId);
      if (source == null) {
        notice.value = '"${song.title}" has no playable audio.';
        return false;
      }
      await _audio.load(source);
      if (startAtMs > 0) await _audio.seek(Duration(milliseconds: startAtMs));
      _loadedSongId = song.id;
      return true;
    } catch (e, st) {
      debugPrint('Audio load failed for ${song.providerSongId}: $e\n$st');
      notice.value = 'Could not load "${song.title}".';
      return false;
    }
  }

  Future<void> _startAudio() async {
    try {
      await _audio.play();
      needsGesture.value = false;
      _startHeartbeat();
    } on AutoplayBlockedException {
      needsGesture.value = true;
      notice.value = 'Your browser blocked audio. Press play to start.';
      rethrow;
    }
  }

  Future<void> _publish(
    PlaybackStatus status, {
    int? positionOverrideMs,
  }) async {
    final room = _room.room.value;
    if (room == null) return;
    final pos = positionOverrideMs ?? _audio.getPosition().inMilliseconds;
    try {
      final state = await _repo.setPlayback(room.id, status, pos);
      _room.applyPlayback(state);
    } catch (e) {
      notice.value = AppFailure.from(e).message;
    }
  }

  void _onAudioState(AudioState state) {
    isPlaying.value = state == AudioState.playing;
    if (state == AudioState.completed) {
      _stopHeartbeat();
      unawaited(_advance());
    }
  }

  void _startHeartbeat() {
    _heartbeat ??= Timer.periodic(heartbeat, (_) {
      if (isPlaying.value) unawaited(_publish(PlaybackStatus.playing));
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  void onClose() {
    _stopHeartbeat();
    _roomWorker?.dispose();
    _stateSub?.cancel();
    _posSub?.cancel();
    unawaited(_audio.dispose());
    super.onClose();
  }
}
