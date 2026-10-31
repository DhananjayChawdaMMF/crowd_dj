import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../room/presentation/room_controller.dart';
import '../domain/queue_item.dart';
import '../domain/queue_repository.dart';

class QueueController extends GetxController {
  QueueController(this._repository, this._room);

  final QueueRepository _repository;
  final RoomController _room;

  final items = <QueueItem>[].obs;
  final loading = true.obs;
  final errorMessage = RxnString();

  final notice = RxnString();
  final busyIds = <String>{}.obs;

  Worker? _worker;

  /// Upcoming songs (excludes the one currently playing).
  List<QueueItem> get upcoming => items.where((i) => !i.isPlaying).toList();

  @override
  void onInit() {
    super.onInit();
    _worker = ever(_room.room, (room) {
      if (room != null && items.isEmpty && loading.value) load();
    });
    if (_room.room.value != null) load();
  }

  /// [quiet] reloads in the background without showing the loading state.
  Future<void> load({bool quiet = false}) async {
    final roomId = _room.room.value?.id;
    if (roomId == null) return;
    if (!quiet) loading.value = true;
    errorMessage.value = null;
    try {
      items.assignAll(await _repository.fetchQueue(roomId));
    } catch (e) {
      errorMessage.value = AppFailure.from(e).message;
    } finally {
      loading.value = false;
    }
  }

  /// Host: remove a queued song.
  Future<bool> remove(String id) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repository.removeItem(id);
      notice.value = 'Removed from the queue.';
      return true;
    } catch (e) {
      notice.value = AppFailure.from(e).message;
      return false;
    } finally {
      busyIds.remove(id);
      await load();
    }
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }
}
