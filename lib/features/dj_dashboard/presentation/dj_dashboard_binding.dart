import 'package:get/get.dart';

import '../../music_player/data/just_audio_playback_service.dart';
import '../../music_player/domain/audio_playback_service.dart';
import '../../music_player/domain/playback_repository.dart';
import '../../music_player/presentation/music_player_controller.dart';
import '../../music_search/domain/music_provider.dart';
import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../../room/domain/entities/room.dart';
import '../../room/presentation/room_controller.dart';
import '../../room/presentation/room_controllers_binding.dart';
import 'dj_dashboard_controller.dart';

class DJDashboardBinding extends Bindings {
  DJDashboardBinding(this.code, {AudioPlaybackService Function()? audioFactory})
    : audioFactory = audioFactory ?? JustAudioPlaybackService.new;

  final String code;
  final AudioPlaybackService Function() audioFactory;

  @override
  void dependencies() {
    registerRoomControllers(code, ParticipantRole.host);
    final tag = roomTag(ParticipantRole.host, code);
    final room = Get.find<RoomController>(tag: tag);
    final queue = Get.find<QueueController>(tag: tag);
    final player = Get.put(
      MusicPlayerController(
        audio: audioFactory(),
        playback: Get.find<PlaybackRepository>(),
        provider: Get.find<MusicProvider>(),
        room: room,
        queue: queue,
      ),
      tag: tag,
    );
    Get.put(
      DJDashboardController(
        room,
        queue,
        Get.find<RecommendationController>(tag: tag),
        player,
      ),
      tag: tag,
    );
  }

  static void dispose(String code) {
    final tag = roomTag(ParticipantRole.host, code);
    Get.delete<DJDashboardController>(tag: tag);
    Get.delete<MusicPlayerController>(tag: tag);
    deleteRoomControllers(code, ParticipantRole.host);
  }
}
