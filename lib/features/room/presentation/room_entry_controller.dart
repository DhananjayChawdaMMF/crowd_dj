import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routes/app_routes.dart';
import '../domain/entities/room.dart';
import '../domain/room_validator.dart';
import '../domain/use_cases/get_room_preview.dart';
import '../domain/use_cases/join_room.dart';

enum RoomEntryStatus { loading, needsName, joining, closed, error }

/// Resolves /room/:code purely from the URL: loads a preview, rejoins a
/// returning browser session automatically, or asks a new guest for a name.
class RoomEntryController extends GetxController {
  RoomEntryController(this.code, this._getPreview, this._joinRoom);

  final String code;
  final GetRoomPreview _getPreview;
  final JoinRoom _joinRoom;

  final status = RoomEntryStatus.loading.obs;
  final preview = Rxn<RoomPreview>();
  final errorMessage = RxnString();
  final nameError = RxnString();

  /// Set when the user should be sent to a dashboard.
  final redirectTo = RxnString();

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    status.value = RoomEntryStatus.loading;
    errorMessage.value = null;
    try {
      final p = await _getPreview(code);
      preview.value = p;
      if (!p.isActive) {
        status.value = RoomEntryStatus.closed;
      } else if (p.myDisplayName != null) {
        await _join(p.myDisplayName!);
      } else {
        status.value = RoomEntryStatus.needsName;
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> submitName(String name) async {
    nameError.value = RoomValidator.displayName(name);
    if (nameError.value != null) return;
    await _join(name);
  }

  Future<void> _join(String name) async {
    status.value = RoomEntryStatus.joining;
    try {
      final session = await _joinRoom(code, name);
      redirectTo.value = session.participant.isHost
          ? AppRoutes.djPath(session.room.code)
          : AppRoutes.guestPath(session.room.code);
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    final failure = AppFailure.from(e);
    errorMessage.value = failure.message;
    status.value = switch (failure.code) {
      'room_closed' => RoomEntryStatus.closed,
      'room_not_found' => RoomEntryStatus.error,
      _ => RoomEntryStatus.error,
    };
  }
}
