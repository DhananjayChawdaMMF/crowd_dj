import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../domain/room_code_validator.dart';

class LandingController extends GetxController {
  final joinError = RxnString();

  void goToCreateRoom(BuildContext context) => context.go(AppRoutes.createRoom);

  /// Accepts either a bare room code or a pasted room URL.
  void joinRoom(BuildContext context, String input) {
    final code = RoomCodeValidator.extract(input);
    if (code == null) {
      joinError.value = 'Enter a valid room code or link.';
      return;
    }
    joinError.value = null;
    context.go(AppRoutes.roomPath(code));
  }

  void clearJoinError() => joinError.value = null;
}
