import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../music_player_controller.dart';

/// DJ transport: seekable progress, restart / play-pause / next.
class HostPlayerControls extends StatelessWidget {
  const HostPlayerControls({super.key, required this.player});

  final MusicPlayerController player;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration = player.durationMs;
      final hasSong = player.currentSong != null;
      final max = (duration ?? 0).toDouble();
      final value = player.positionMs.value.toDouble().clamp(
        0,
        max == 0 ? 1 : max,
      );
      return Column(
        children: [
          if (player.needsGesture.value)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Your browser needs a click before it will play audio. Press play to start.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              max: max == 0 ? 1 : max,
              onChangeStart: hasSong && max > 0
                  ? (_) => player.beginSeek()
                  : null,
              onChanged: hasSong && max > 0
                  ? (v) => player.updateSeek(v.round())
                  : null,
              onChangeEnd: hasSong && max > 0
                  ? (v) => player.endSeek(v.round())
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.duration(player.positionMs.value),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                Formatters.duration(duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 32,
                tooltip: 'Restart song',
                onPressed: hasSong ? player.restart : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 8),
              player.busy.value
                  ? const SizedBox(
                      width: 56,
                      height: 56,
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  : IconButton.filled(
                      iconSize: 40,
                      tooltip: player.isPlaying.value ? 'Pause' : 'Play',
                      onPressed: player.togglePlay,
                      icon: Icon(
                        player.isPlaying.value
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 32,
                tooltip: 'Next song',
                onPressed: player.busy.value ? null : player.next,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      );
    });
  }
}
