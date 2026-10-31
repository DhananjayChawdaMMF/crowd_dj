import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/song_candidate.dart';
import '../domain/song_search_repository.dart';

class MusicSearchController extends GetxController {
  MusicSearchController(this._repository);

  static const minQueryLength = 2;

  final SongSearchRepository _repository;

  final query = ''.obs;
  final results = <SongCandidate>[].obs;
  final loading = false.obs;
  final searched = false.obs;
  final errorMessage = RxnString();

  Worker? _debounce;
  int _seq = 0;

  String get catalogName => _repository.catalogName;
  bool get isDemoCatalog => _repository.isDemoCatalog;

  @override
  void onInit() {
    super.onInit();
    _debounce = debounce(
      query,
      search,
      time: const Duration(milliseconds: 350),
    );
  }

  /// Runs a search now. Stale responses (a newer query started) are dropped.
  Future<void> search(String text) async {
    final q = text.trim();
    final seq = ++_seq;
    if (q.length < minQueryLength) {
      results.clear();
      searched.value = false;
      loading.value = false;
      errorMessage.value = null;
      return;
    }
    loading.value = true;
    errorMessage.value = null;
    try {
      final found = await _repository.searchSongs(q);
      if (seq != _seq) return;
      results.assignAll(found);
      searched.value = true;
    } catch (e) {
      if (seq != _seq) return;
      errorMessage.value = AppFailure.from(e).message;
    } finally {
      if (seq == _seq) loading.value = false;
    }
  }

  @override
  void onClose() {
    _debounce?.dispose();
    super.onClose();
  }
}
