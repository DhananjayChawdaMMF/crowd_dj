import 'package:get/get.dart';

import '../../../core/services/session_provider.dart';
import '../domain/room_repository.dart';
import '../domain/use_cases/get_room_preview.dart';
import '../domain/use_cases/join_room.dart';
import 'room_entry_controller.dart';

class RoomEntryBinding extends Bindings {
  RoomEntryBinding(this.code);

  final String code;

  @override
  void dependencies() {
    final sessions = Get.find<SessionProvider>();
    final rooms = Get.find<RoomRepository>();
    Get.put(
      RoomEntryController(
        code,
        GetRoomPreview(sessions, rooms),
        JoinRoom(sessions, rooms),
      ),
    );
  }
}
