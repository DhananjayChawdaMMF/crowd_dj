import 'package:get/get.dart';

import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../../room/domain/entities/room.dart';
import '../../room/presentation/room_controller.dart';
import '../../room/presentation/room_controllers_binding.dart';
import '../../music_search/domain/song_search_repository.dart';
import '../../music_search/presentation/music_search_controller.dart';
import 'audience_controller.dart';

class AudienceBinding extends Bindings {
  AudienceBinding(this.code);

  final String code;

  @override
  void dependencies() {
    registerRoomControllers(code, ParticipantRole.guest);
    final tag = roomTag(ParticipantRole.guest, code);
    Get.put(MusicSearchController(Get.find<SongSearchRepository>()), tag: tag);
    Get.put(
      AudienceController(
        Get.find<RoomController>(tag: tag),
        Get.find<QueueController>(tag: tag),
        Get.find<RecommendationController>(tag: tag),
        Get.find<MusicSearchController>(tag: tag),
      ),
      tag: tag,
    );
  }

  static void dispose(String code) {
    Get.delete<MusicSearchController>(
      tag: roomTag(ParticipantRole.guest, code),
    );
    Get.delete<AudienceController>(tag: roomTag(ParticipantRole.guest, code));
    deleteRoomControllers(code, ParticipantRole.guest);
  }
}
