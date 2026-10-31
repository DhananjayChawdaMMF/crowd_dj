import 'queue_item.dart';

abstract interface class QueueRepository {
  /// Queued and currently-playing items, ordered by position.
  Future<List<QueueItem>> fetchQueue(String roomId);

  /// Host action: removes a queued song.
  Future<void> removeItem(String queueId);
}
