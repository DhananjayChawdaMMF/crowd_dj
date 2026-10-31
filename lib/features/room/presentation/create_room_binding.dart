import 'package:get/get.dart';

import '../../../core/services/session_provider.dart';
import '../domain/room_repository.dart';
import '../domain/use_cases/create_room.dart';
import 'create_room_controller.dart';

class CreateRoomBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CreateRoom(Get.find<SessionProvider>(), Get.find<RoomRepository>()),
    );
    Get.lazyPut(() => CreateRoomController(Get.find<CreateRoom>()));
  }
}
