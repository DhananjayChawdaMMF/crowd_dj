import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../music_player/presentation/music_player_controller.dart';
import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../../room/presentation/room_controller.dart';

enum DjTab { player, queue, requests, audience }

class DJDashboardController extends GetxController {
  DJDashboardController(
    this.room,
    this.queue,
    this.recommendations,
    this.player,
  );

  final RoomController room;
  final QueueController queue;
  final RecommendationController recommendations;
  final MusicPlayerController player;

  /// Only used by the single-column mobile layout.
  final tab = DjTab.player.obs;
  final linkCopied = false.obs;

  Future<void> copyLink() async {
    await Clipboard.setData(ClipboardData(text: room.shareUrl));
    linkCopied.value = true;
    await Future<void>.delayed(const Duration(seconds: 2));
    linkCopied.value = false;
  }

  Future<void> approve(String id) async {
    if (await recommendations.review(id, approve: true)) await queue.load();
  }

  Future<void> reject(String id) => recommendations.review(id, approve: false);

  Future<void> refreshAll() => Future.wait([
    room.refreshQuietly(),
    queue.load(),
    recommendations.load(),
  ]);
}
