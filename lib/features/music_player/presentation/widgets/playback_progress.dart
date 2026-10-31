import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/playback_state.dart';

/// Progress bar driven by a local ticker that extrapolates from the last
/// authoritative [PlaybackState]. Informational: the host player is the truth.
class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.playback,
    required this.durationMs,
    this.now = DateTime.now,
  });

  final PlaybackState playback;
  final int? durationMs;
  final DateTime Function() now;

  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(PlaybackProgress old) {
    super.didUpdateWidget(old);
    _syncTimer();
  }

  void _syncTimer() {
    if (widget.playback.isPlaying) {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => mounted ? setState(() {}) : null,
      );
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.durationMs;
    final position = widget.playback.estimatedPositionMs(
      widget.now(),
      durationMs: duration,
    );
    final value = duration == null || duration == 0
        ? 0.0
        : (position / duration).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Formatters.duration(position),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Text(
              Formatters.duration(duration),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
