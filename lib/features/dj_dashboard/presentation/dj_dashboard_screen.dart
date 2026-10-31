import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notice_listener.dart';
import '../../music_player/presentation/widgets/host_player_controls.dart';
import '../../music_player/presentation/widgets/now_playing_card.dart';
import '../../queue/presentation/widgets/queue_panel.dart';
import '../../recommendations/presentation/widgets/pending_recommendations_panel.dart';
import '../../room/domain/entities/room.dart';
import '../../room/domain/room_realtime.dart';
import '../../room/presentation/room_controllers_binding.dart';
import '../../room/presentation/widgets/audience_panel.dart';
import '../../room/presentation/widgets/room_gate.dart';
import '../../room/presentation/widgets/room_header.dart';
import 'dj_dashboard_controller.dart';

class DJDashboardScreen extends GetView<DJDashboardController> {
  const DJDashboardScreen({super.key, required this.code});

  final String code;

  @override
  String? get tag => roomTag(ParticipantRole.host, code);

  @override
  Widget build(BuildContext context) {
    return RoomGate(
      controller: controller.room,
      builder: (context, room) {
        final size = Breakpoints.ofContext(context);
        return NoticeListener(
          notices: [
            controller.room.notice,
            controller.queue.notice,
            controller.recommendations.notice,
            controller.player.notice,
          ],
          child: size == ScreenSize.mobile
              ? _MobileLayout(controller: controller, room: room)
              : _WideLayout(controller: controller, room: room, size: size),
        );
      },
    );
  }
}

Future<void> _confirmClose(
  BuildContext context,
  DJDashboardController c,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Close this room?'),
      content: const Text(
        'Everyone will be disconnected and the room link will stop working.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Close room'),
        ),
      ],
    ),
  );
  if (ok == true) await c.room.closeRoom();
}

List<Widget> _headerActions(
  BuildContext context,
  DJDashboardController c, {
  required bool compact,
}) => [
  IconButton(
    tooltip: 'Refresh',
    onPressed: c.refreshAll,
    icon: const Icon(Icons.refresh_rounded),
  ),
  Obx(
    () => IconButton(
      tooltip: c.linkCopied.value ? 'Copied!' : 'Copy room link',
      onPressed: c.copyLink,
      icon: Icon(c.linkCopied.value ? Icons.check_rounded : Icons.link_rounded),
    ),
  ),
  if (compact)
    IconButton(
      tooltip: 'Close room',
      onPressed: () => _confirmClose(context, c),
      icon: const Icon(Icons.power_settings_new_rounded),
    )
  else
    Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Obx(
        () => OutlinedButton(
          onPressed: c.room.closing.value
              ? null
              : () => _confirmClose(context, c),
          child: const Text('Close room'),
        ),
      ),
    ),
];

Widget _nowPlaying(DJDashboardController c, Room room) => Obx(() {
  final r = c.room.room.value ?? room;
  return NowPlayingCard(
    song: r.currentSong,
    playback: r.playback,
    hostName: c.room.hostName,
    hostControls: HostPlayerControls(player: c.player),
  );
});

/// Warns when this DJ console is open in several tabs (each would play audio).
class _MultiTabWarning extends StatelessWidget {
  const _MultiTabWarning({required this.controller});

  final DJDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.room.openInAnotherTab) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This room is open in another tab. Close the extra tab, or the music may play twice.',
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ShareStrip extends StatelessWidget {
  const _ShareStrip({required this.controller});

  final DJDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.share_rounded, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              controller.room.shareUrl,
              maxLines: 1,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Obx(
            () => TextButton.icon(
              onPressed: controller.copyLink,
              icon: Icon(
                controller.linkCopied.value
                    ? Icons.check_rounded
                    : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(controller.linkCopied.value ? 'Copied' : 'Copy link'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.controller,
    required this.room,
    required this.size,
  });

  final DJDashboardController controller;
  final Room room;
  final ScreenSize size;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final player = _nowPlaying(c, room);
    final queue = QueuePanel(controller: c.queue, onRemove: c.queue.remove);
    final recs = PendingRecommendationsPanel(
      controller: c.recommendations,
      onApprove: c.approve,
      onReject: c.reject,
    );
    final audience = AudiencePanel(controller: c.room);

    const gap = SizedBox(height: 16);
    final body = size == ScreenSize.desktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: player),
              const SizedBox(width: 16),
              Expanded(child: queue),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [recs, gap, audience])),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [player, gap, audience])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [recs, gap, queue])),
            ],
          );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                children: [
                  Obx(
                    () => RoomHeader(
                      roomName: room.name,
                      audienceCount: c.room.audienceCount,
                      reconnecting:
                          c.room.connection.value ==
                          RealtimeStatus.reconnecting,
                      actions: _headerActions(context, c, compact: false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ShareStrip(controller: c),
                  const SizedBox(height: 16),
                  _MultiTabWarning(controller: c),
                  body,
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

  final DJDashboardController controller;
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
                  actions: _headerActions(context, c, compact: true),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MultiTabWarning(controller: c),
            ),
            Expanded(
              child: Obx(
                () => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: switch (c.tab.value) {
                    DjTab.player => _nowPlaying(c, room),
                    DjTab.queue => QueuePanel(
                      controller: c.queue,
                      onRemove: c.queue.remove,
                    ),
                    DjTab.requests => PendingRecommendationsPanel(
                      controller: c.recommendations,
                      onApprove: c.approve,
                      onReject: c.reject,
                    ),
                    DjTab.audience => AudiencePanel(controller: c.room),
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
          onDestinationSelected: (i) => c.tab.value = DjTab.values[i],
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.album_rounded),
              label: 'Player',
            ),
            const NavigationDestination(
              icon: Icon(Icons.queue_music_rounded),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: c.recommendations.pending.isNotEmpty,
                label: Text('${c.recommendations.pending.length}'),
                child: const Icon(Icons.thumb_up_alt_rounded),
              ),
              label: 'Requests',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_rounded),
              label: 'Audience',
            ),
          ],
        ),
      ),
    );
  }
}
