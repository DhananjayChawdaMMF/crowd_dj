import 'package:get/get.dart';

import '../../music_search/presentation/music_search_controller.dart';
import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../../room/presentation/room_controller.dart';

enum AudienceTab { nowPlaying, recommend, queue, requests, audience }

class AudienceController extends GetxController {
  AudienceController(this.room, this.queue, this.recommendations, this.search);

  final RoomController room;
  final QueueController queue;
  final RecommendationController recommendations;
  final MusicSearchController search;

  final tab = AudienceTab.nowPlaying.obs;

  Future<void> refreshAll() => Future.wait([
    room.refreshQuietly(),
    queue.load(),
    recommendations.load(),
  ]);
}
