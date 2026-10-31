import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/entities/room.dart';
import '../domain/room_validator.dart';
import '../domain/use_cases/create_room.dart';

class CreateRoomController extends GetxController {
  CreateRoomController(this._createRoom);

  final CreateRoom _createRoom;

  final hostName = TextEditingController();
  final roomName = TextEditingController();
  final description = TextEditingController();

  final isPublic = false.obs;
  final allowRecommendations = true.obs;
  final enableVoting = false.obs;

  final loading = false.obs;
  final hostNameError = RxnString();
  final roomNameError = RxnString();
  final descriptionError = RxnString();
  final submitError = RxnString();

  bool _validate() {
    hostNameError.value = RoomValidator.displayName(hostName.text);
    roomNameError.value = RoomValidator.roomName(roomName.text);
    descriptionError.value = RoomValidator.description(description.text);
    return hostNameError.value == null &&
        roomNameError.value == null &&
        descriptionError.value == null;
  }

  /// Returns the created session, or null if validation/creation failed
  /// (the reason is exposed through the error observables).
  Future<RoomSession?> submit() async {
    if (loading.value || !_validate()) return null;
    loading.value = true;
    submitError.value = null;
    try {
      return await _createRoom(
        CreateRoomParams(
          hostName: hostName.text,
          roomName: roomName.text,
          description: description.text,
          isPublic: isPublic.value,
          allowRecommendations: allowRecommendations.value,
          enableVoting: enableVoting.value,
        ),
      );
    } catch (e) {
      submitError.value = AppFailure.from(e).message;
      return null;
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    hostName.dispose();
    roomName.dispose();
    description.dispose();
    super.onClose();
  }
}
