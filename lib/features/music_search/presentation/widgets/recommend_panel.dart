import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/panel_card.dart';
import '../../../../core/widgets/song_artwork.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../recommendations/presentation/recommendation_controller.dart';
import '../../../room/presentation/room_controller.dart';
import '../../domain/song_candidate.dart';
import '../music_search_controller.dart';

/// Guest view: search the catalog and recommend songs to the DJ.
class RecommendPanel extends StatelessWidget {
  const RecommendPanel({
    super.key,
    required this.search,
    required this.recommendations,
    required this.room,
  });

  final MusicSearchController search;
  final RecommendationController recommendations;
  final RoomController room;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Recommend a song',
      child: Obx(() {
        final allowed = room.room.value?.allowRecommendations ?? true;
        if (!allowed) {
          return const EmptyState(
            icon: Icons.block_rounded,
            title: 'Recommendations are turned off',
            message: 'The DJ is choosing the music for this room.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (v) => search.query.value = v,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search songs or artists',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (search.isDemoCatalog) ...[
              const SizedBox(height: 8),
              Text(
                'Searching: ${search.catalogName}. Sample data, not a real music library.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _results(),
          ],
        );
      }),
    );
  }

  Widget _results() {
    if (search.errorMessage.value != null) {
      return ErrorState(
        message: search.errorMessage.value!,
        onRetry: () => search.search(search.query.value),
      );
    }
    if (search.loading.value) return const SkeletonList(count: 2);
    if (!search.searched.value) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find something for the crowd',
        message: 'Type at least 2 characters.',
      );
    }
    if (search.results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a different title or artist.',
      );
    }
    return Column(
      children: [
        for (final song in search.results) _ResultTile(song, recommendations),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(this.song, this.controller);

  final SongCandidate song;
  final RecommendationController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SongArtwork(url: song.artworkUrl, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${song.artist} · ${Formatters.duration(song.durationMs)}',
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
          const SizedBox(width: 8),
          Obx(() {
            final sent = controller.sentKeys.contains(song.key);
            final busy = controller.submittingKeys.contains(song.key);
            if (busy) {
              return const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return sent
                ? const Chip(
                    label: Text('Sent'),
                    avatar: Icon(Icons.check_rounded, size: 16),
                  )
                : FilledButton.tonal(
                    onPressed: () => controller.submit(song),
                    child: const Text('Recommend'),
                  );
          }),
        ],
      ),
    );
  }
}
