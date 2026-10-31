import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/song_artwork.dart';
import '../../domain/recommendation.dart';

class RecommendationTile extends StatelessWidget {
  const RecommendationTile({
    super.key,
    required this.recommendation,
    this.showGuest = true,
    this.actions,
    this.showStatus = false,
  });

  final Recommendation recommendation;
  final bool showGuest;
  final bool showStatus;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final meta = [
      r.song.artist,
      if (showGuest) 'from ${r.guestName}',
      Formatters.timeAgo(r.createdAt, DateTime.now()),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SongArtwork(url: r.song.artworkUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      meta,
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
              if (showStatus) _StatusChip(r.status),
            ],
          ),
          if (actions != null) ...[const SizedBox(height: 10), actions!],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final RecommendationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RecommendationStatus.pending => ('Pending', AppColors.textMuted),
      RecommendationStatus.approved => ('Approved', AppColors.success),
      RecommendationStatus.rejected => ('Rejected', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
