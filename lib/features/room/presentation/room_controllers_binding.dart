import 'package:get/get.dart';

import '../../../core/services/server_clock.dart';
import '../../../core/services/session_provider.dart';
import '../../queue/domain/queue_repository.dart';
import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/domain/recommendation_repository.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../domain/entities/room.dart';
import '../domain/room_repository.dart';
import '../domain/room_realtime.dart';
import 'room_controller.dart';
import 'room_realtime_controller.dart';

/// GetX registry tag for one dashboard instance. Tags keep the DJ and guest
/// routes (and different rooms) from sharing or deleting each other's
/// controllers when one route replaces another during a redirect.
String roomTag(ParticipantRole role, String code) =>
    '${role.name}-${code.toUpperCase()}';

/// Controllers shared by the DJ and audience dashboards.
void registerRoomControllers(String code, ParticipantRole role) {
  final tag = roomTag(role, code);
  final room = Get.put(
    RoomController(
      code: code,
      expectedRole: role,
      sessions: Get.find<SessionProvider>(),
      rooms: Get.find<RoomRepository>(),
      clock: Get.find<ServerClock>(),
    ),
    tag: tag,
  );
  final queue = Get.put(
    QueueController(Get.find<QueueRepository>(), room),
    tag: tag,
  );
  final recs = Get.put(
    RecommendationController(Get.find<RecommendationRepository>(), room),
    tag: tag,
  );
  Get.put(
    RoomRealtimeController(
      realtime: Get.find<RoomRealtime>(),
      room: room,
      queue: queue,
      recommendations: recs,
    ),
    tag: tag,
  );
}

void deleteRoomControllers(String code, ParticipantRole role) {
  final tag = roomTag(role, code);
  Get.delete<RoomRealtimeController>(tag: tag);
  Get.delete<RecommendationController>(tag: tag);
  Get.delete<QueueController>(tag: tag);
  Get.delete<RoomController>(tag: tag);
}
