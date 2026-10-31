import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Decorative "now playing" card. Static illustration, no real track data.
class HeroVisual extends StatefulWidget {
  const HeroVisual({super.key});

  @override
  State<HeroVisual> createState() => _HeroVisualState();
}

class _HeroVisualState extends State<HeroVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 0.9,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, _) => _Equalizer(t: _anim.value),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your next track',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Picked by the crowd',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.45,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Equalizer extends StatelessWidget {
  const _Equalizer({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            width: 12,
            height: 40 + 70 * (0.5 + 0.5 * math.sin(2 * math.pi * t + i * 0.9)),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}
