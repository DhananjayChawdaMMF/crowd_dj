import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/song_artwork.dart';
import '../../../music_search/domain/song.dart';
import '../../domain/playback_state.dart';
import 'playback_progress.dart';

/// Now-playing display shared by the DJ console and the audience view.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({
    super.key,
    required this.song,
    required this.playback,
    required this.hostName,
    this.hostControls,
    this.hostOnline = true,
    this.now = DateTime.now,
  });

  final Song? song;
  final PlaybackState playback;
  final String hostName;

  /// Host-only transport controls (slider + buttons). When set they replace the
  /// read-only progress bar. Never passed for guests.
  final Widget? hostControls;

  /// False when presence shows the DJ is not connected.
  final bool hostOnline;

  /// Clock used to extrapolate the guest progress bar (server-corrected).
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final s = song;
    return AppCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final art = c.maxWidth.clamp(140.0, 320.0);
          return Column(
            children: [
              SongArtwork(url: s?.artworkUrl, size: art, radius: 20),
              const SizedBox(height: 20),
              Text(
                s?.title ?? 'Nothing playing yet',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s?.artist ?? 'The DJ will start the music soon',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _chip(Icons.headphones_rounded, 'DJ $hostName'),
                  _statusChip(playback.status, hasSong: s != null),
                  if (!hostOnline)
                    _chip(
                      Icons.wifi_off_rounded,
                      'DJ offline',
                      color: AppColors.danger,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              hostControls ??
                  PlaybackProgress(
                    playback: playback,
                    durationMs: s?.durationMs,
                    now: now,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textMuted),
        const SizedBox(width: 6),
        // Long display names must not overflow the card on small phones.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color ?? AppColors.textMuted),
          ),
        ),
      ],
    ),
  );

  Widget _statusChip(PlaybackStatus status, {required bool hasSong}) {
    if (!hasSong || status == PlaybackStatus.stopped) {
      return _chip(Icons.stop_circle_outlined, 'Stopped');
    }
    return status == PlaybackStatus.playing
        ? _chip(Icons.graphic_eq_rounded, 'Playing', color: AppColors.success)
        : _chip(Icons.pause_circle_outline_rounded, 'Paused');
  }
}
