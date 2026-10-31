import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../room/presentation/room_controller.dart';
import '../../music_search/domain/song_candidate.dart';
import '../domain/recommendation.dart';
import '../domain/recommendation_repository.dart';

class RecommendationController extends GetxController {
  RecommendationController(this._repository, this._room);

  final RecommendationRepository _repository;
  final RoomController _room;

  final items = <Recommendation>[].obs;
  final loading = true.obs;
  final errorMessage = RxnString();

  /// One-shot feedback message for the UI (snackbar). Cleared once shown.
  final notice = RxnString();

  /// Candidate keys the caller already sent in this session.
  final sentKeys = <String>{}.obs;
  final submittingKeys = <String>{}.obs;
  final busyIds = <String>{}.obs;

  Worker? _worker;

  List<Recommendation> get pending =>
      items.where((r) => r.status == RecommendationStatus.pending).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// The caller's own recommendations, newest first.
  List<Recommendation> get mine {
    final id = _room.me.value?.id;
    return items.where((r) => r.participantId == id).toList();
  }

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
      items.assignAll(await _repository.fetchRecommendations(roomId));
    } catch (e) {
      errorMessage.value = AppFailure.from(e).message;
    } finally {
      loading.value = false;
    }
  }

  /// Guest: recommend a song to the DJ.
  Future<bool> submit(SongCandidate song) async {
    final room = _room.room.value;
    if (room == null || submittingKeys.contains(song.key)) return false;
    if (!room.allowRecommendations) {
      notice.value = 'The DJ turned off recommendations.';
      return false;
    }
    submittingKeys.add(song.key);
    try {
      await _repository.recommendSong(room.id, song);
      sentKeys.add(song.key);
      notice.value = 'Sent "${song.title}" to the DJ.';
      await load();
      return true;
    } catch (e) {
      final failure = AppFailure.from(e);
      if (failure.code == 'already_recommended') sentKeys.add(song.key);
      notice.value = failure.message;
      return false;
    } finally {
      submittingKeys.remove(song.key);
    }
  }

  /// Host: approve (enqueues atomically) or reject a pending recommendation.
  Future<bool> review(String id, {required bool approve}) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repository.review(id, approve: approve);
      notice.value = approve
          ? 'Added to the queue.'
          : 'Recommendation rejected.';
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
