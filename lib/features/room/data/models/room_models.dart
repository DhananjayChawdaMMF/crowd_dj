import '../../../music_player/data/models/playback_model.dart';
import '../../../music_search/data/models/song_model.dart';
import '../../domain/entities/room.dart';

Room roomFromJson(Map<String, dynamic> j) => Room(
  id: j['id'] as String,
  code: j['room_code'] as String,
  name: j['room_name'] as String,
  description: j['description'] as String?,
  hostUserId: j['host_user_id'] as String,
  isActive: j['status'] == 'active',
  isPublic: j['is_public'] as bool,
  allowRecommendations: j['allow_recommendations'] as bool,
  enableVoting: j['enable_voting'] as bool,
  playback: playbackFromJson(j),
  currentSong: j['current_song'] is Map<String, dynamic>
      ? songFromJson(j['current_song'] as Map<String, dynamic>)
      : null,
);

Participant participantFromJson(Map<String, dynamic> j) => Participant(
  id: j['id'] as String,
  roomId: j['room_id'] as String,
  userId: j['user_id'] as String,
  displayName: j['display_name'] as String,
  role: j['role'] == 'host' ? ParticipantRole.host : ParticipantRole.guest,
);

RoomSession roomSessionFromJson(Map<String, dynamic> j) => RoomSession(
  room: roomFromJson(j['room'] as Map<String, dynamic>),
  participant: participantFromJson(j['participant'] as Map<String, dynamic>),
);

RoomPreview roomPreviewFromJson(Map<String, dynamic> j) => RoomPreview(
  code: j['room_code'] as String,
  name: j['room_name'] as String,
  description: j['description'] as String?,
  hostName: j['host_name'] as String?,
  isActive: j['status'] == 'active',
  isHost: j['is_host'] as bool,
  myDisplayName: j['my_display_name'] as String?,
);
