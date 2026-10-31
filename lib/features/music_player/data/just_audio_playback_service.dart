import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../music_search/domain/song_candidate.dart';
import '../domain/audio_playback_service.dart';
import 'asset_url.dart';

class JustAudioPlaybackService implements AudioPlaybackService {
  JustAudioPlaybackService() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(PlayableSource source) async {
    final asset = source.assetPath;
    if (asset != null) {
      final webUrl = resolveAssetUrl(asset);
      if (webUrl != null) {
        await _player.setUrl(webUrl);
      } else {
        await _player.setAsset(asset);
      }
    } else if (source.url != null) {
      await _player.setUrl(source.url.toString());
    } else {
      throw ArgumentError('PlayableSource has neither url nor assetPath');
    }
  }

  @override
  Future<void> play() async {
    Object? error;
    // just_audio's play() future completes when playback ends or pauses, so it
    // is observed rather than awaited. A rejected browser play() surfaces here.
    unawaited(
      _player.play().catchError((Object e) {
        error = e;
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (error != null || !_player.playing) {
      throw const AutoplayBlockedException();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Duration getPosition() => _player.position;

  @override
  Duration? getDuration() => _player.duration;

  @override
  Stream<AudioState> get playbackStateStream =>
      _player.playerStateStream.map((s) {
        switch (s.processingState) {
          case ProcessingState.idle:
            return AudioState.idle;
          case ProcessingState.loading:
          case ProcessingState.buffering:
            return AudioState.loading;
          case ProcessingState.completed:
            return AudioState.completed;
          case ProcessingState.ready:
            return s.playing ? AudioState.playing : AudioState.paused;
        }
      }).distinct();

  @override
  Stream<Duration> get positionStream => _player.createPositionStream(
    minPeriod: const Duration(milliseconds: 250),
    maxPeriod: const Duration(milliseconds: 250),
  );

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}
