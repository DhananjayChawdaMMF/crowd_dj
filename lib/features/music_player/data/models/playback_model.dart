import '../../domain/playback_state.dart';

PlaybackState playbackFromJson(Map<String, dynamic> j) => PlaybackState(
  status: PlaybackStatus.parse(j['playback_status'] as String?),
  positionMs: (j['playback_position_ms'] as num?)?.toInt() ?? 0,
  updatedAt: j['playback_updated_at'] == null
      ? null
      : DateTime.parse(j['playback_updated_at'] as String),
  version: (j['playback_version'] as num?)?.toInt() ?? 0,
);
