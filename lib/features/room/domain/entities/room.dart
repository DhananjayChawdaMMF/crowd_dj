import '../../../music_player/domain/playback_state.dart';
import '../../../music_search/domain/song.dart';

class Room {
  const Room({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.hostUserId,
    required this.isActive,
    required this.isPublic,
    required this.allowRecommendations,
    required this.enableVoting,
    this.playback = const PlaybackState.stopped(),
    this.currentSong,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String hostUserId;
  final bool isActive;
  final bool isPublic;
  final bool allowRecommendations;
  final bool enableVoting;
  final PlaybackState playback;
  final Song? currentSong;

  Room copyWith({
    PlaybackState? playback,
    Song? currentSong,
    bool clearCurrentSong = false,
    bool? isActive,
  }) => Room(
    id: id,
    code: code,
    name: name,
    description: description,
    hostUserId: hostUserId,
    isActive: isActive ?? this.isActive,
    isPublic: isPublic,
    allowRecommendations: allowRecommendations,
    enableVoting: enableVoting,
    playback: playback ?? this.playback,
    currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
  );
}

enum ParticipantRole { host, guest }

class Participant {
  const Participant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final ParticipantRole role;

  bool get isHost => role == ParticipantRole.host;
}

/// Result of creating or joining a room.
class RoomSession {
  const RoomSession({required this.room, required this.participant});

  final Room room;
  final Participant participant;
}

/// What a visitor can see before joining.
class RoomPreview {
  const RoomPreview({
    required this.code,
    required this.name,
    required this.description,
    required this.hostName,
    required this.isActive,
    required this.isHost,
    required this.myDisplayName,
  });

  final String code;
  final String name;
  final String? description;
  final String? hostName;
  final bool isActive;
  final bool isHost;

  /// Set when this browser session already joined the room.
  final String? myDisplayName;
}

class CreateRoomParams {
  const CreateRoomParams({
    required this.hostName,
    required this.roomName,
    this.description,
    this.isPublic = false,
    this.allowRecommendations = true,
    this.enableVoting = false,
  });

  final String hostName;
  final String roomName;
  final String? description;
  final bool isPublic;
  final bool allowRecommendations;
  final bool enableVoting;
}
