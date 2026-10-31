import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/notice_listener.dart';
import '../../music_search/presentation/widgets/recommend_panel.dart';
import '../../music_player/presentation/widgets/now_playing_card.dart';
import '../../queue/presentation/widgets/queue_panel.dart';
import '../../recommendations/presentation/widgets/my_recommendations_panel.dart';
import '../../room/domain/entities/room.dart';
import '../../room/domain/room_realtime.dart';
import '../../room/presentation/room_controllers_binding.dart';
import '../../room/presentation/widgets/audience_panel.dart';
import '../../room/presentation/widgets/room_gate.dart';
import '../../room/presentation/widgets/room_header.dart';
import 'audience_controller.dart';

/// Guest view. Contains no host controls by construction.
class AudienceScreen extends GetView<AudienceController> {
  const AudienceScreen({super.key, required this.code});

  final String code;

  @override
  String? get tag => roomTag(ParticipantRole.guest, code);

  @override
  Widget build(BuildContext context) {
    return RoomGate(
      controller: controller.room,
      builder: (context, room) {
        final size = Breakpoints.ofContext(context);
        return NoticeListener(
          notices: [controller.recommendations.notice],
          child: size == ScreenSize.mobile
              ? _MobileLayout(controller: controller, room: room)
              : _WideLayout(controller: controller, room: room),
        );
      },
    );
  }
}

List<Widget> _actions(BuildContext context, AudienceController c) => [
  IconButton(
    tooltip: 'Refresh',
    onPressed: c.refreshAll,
    icon: const Icon(Icons.refresh_rounded),
  ),
  IconButton(
    tooltip: 'Leave',
    onPressed: () => context.go(AppRoutes.landing),
    icon: const Icon(Icons.logout_rounded),
  ),
];

Widget _nowPlaying(AudienceController c, Room room) => Obx(() {
  final r = c.room.room.value ?? room;
  return NowPlayingCard(
    song: r.currentSong,
    playback: r.playback,
    hostName: c.room.hostName,
    hostOnline: c.room.hostOnline,
    now: c.room.clock.now,
  );
});

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.controller, required this.room});

  final AudienceController controller;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const gap = SizedBox(height: 16);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  Obx(
                    () => RoomHeader(
                      roomName: room.name,
                      subtitle: 'DJ ${c.room.hostName}',
                      audienceCount: c.room.audienceCount,
                      reconnecting:
                          c.room.connection.value ==
                          RealtimeStatus.reconnecting,
                      actions: _actions(context, c),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _nowPlaying(c, room),
                            gap,
                            AudiencePanel(controller: c.room),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            RecommendPanel(
                              search: c.search,
                              recommendations: c.recommendations,
                              room: c.room,
                            ),
                            gap,
                            QueuePanel(controller: c.queue),
                            gap,
                            MyRecommendationsPanel(
                              controller: c.recommendations,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.controller, required this.room});

  final AudienceController controller;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Obx(
                () => RoomHeader(
                  roomName: room.name,
                  audienceCount: c.room.audienceCount,
                  reconnecting:
                      c.room.connection.value == RealtimeStatus.reconnecting,
                  compact: true,
                  actions: _actions(context, c),
                ),
              ),
            ),
            Expanded(
              child: Obx(
                () => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: switch (c.tab.value) {
                    AudienceTab.nowPlaying => _nowPlaying(c, room),
                    AudienceTab.recommend => RecommendPanel(
                      search: c.search,
                      recommendations: c.recommendations,
                      room: c.room,
                    ),
                    AudienceTab.queue => QueuePanel(controller: c.queue),
                    AudienceTab.requests => MyRecommendationsPanel(
                      controller: c.recommendations,
                    ),
                    AudienceTab.audience => AudiencePanel(controller: c.room),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: c.tab.value.index,
          onDestinationSelected: (i) => c.tab.value = AudienceTab.values[i],
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.album_rounded),
              label: 'Playing',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'Recommend',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_music_rounded),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: Icon(Icons.thumb_up_alt_rounded),
              label: 'Requests',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_rounded),
              label: 'Audience',
            ),
          ],
        ),
      ),
    );
  }
}
