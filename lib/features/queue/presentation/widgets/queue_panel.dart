import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/panel_card.dart';
import '../../../../core/widgets/song_artwork.dart';
import '../../../../core/widgets/state_views.dart';
import '../queue_controller.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key, required this.controller, this.onRemove});

  final QueueController controller;

  /// Host-only. Null hides the remove action (guest view).
  final void Function(String id)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final upcoming = controller.upcoming;
      return PanelCard(
        title: 'Up next',
        count: controller.loading.value ? null : upcoming.length,
        child: _body(upcoming),
      );
    });
  }

  Widget _body(List upcoming) {
    if (controller.errorMessage.value != null) {
      return ErrorState(
        message: controller.errorMessage.value!,
        onRetry: controller.load,
      );
    }
    if (controller.loading.value && controller.items.isEmpty) {
      return const SkeletonList();
    }
    if (upcoming.isEmpty) {
      return const EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'The queue is empty',
        message: 'Approved recommendations will show up here.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < upcoming.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                SongArtwork(url: upcoming[i].song.artworkUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upcoming[i].song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        [
                          upcoming[i].song.artist,
                          if (upcoming[i].recommendedBy != null)
                            'by ${upcoming[i].recommendedBy}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.duration(upcoming[i].song.durationMs),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove from queue',
                    onPressed: controller.busyIds.contains(upcoming[i].id)
                        ? null
                        : () => onRemove!(upcoming[i].id),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
