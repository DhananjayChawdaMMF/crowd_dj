import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/content_container.dart';

class _Feature {
  const _Feature(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _features = [
  _Feature(
    Icons.link_rounded,
    'No sign-up needed',
    'Guests join from a link with just a display name. No email, no password.',
  ),
  _Feature(
    Icons.queue_music_rounded,
    'Crowd-powered queue',
    'Everyone recommends songs. The DJ approves what makes the queue.',
  ),
  _Feature(
    Icons.headphones_rounded,
    'DJ-controlled playback',
    'Only the DJ plays audio. Guests see what is playing, live.',
  ),
  _Feature(
    Icons.bolt_rounded,
    'Realtime everything',
    'Recommendations, queue and playback update instantly for the whole room.',
  ),
];

class FeatureSection extends StatelessWidget {
  const FeatureSection({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = switch (Breakpoints.ofContext(context)) {
      ScreenSize.desktop => 4,
      ScreenSize.tablet => 2,
      ScreenSize.mobile => 1,
    };

    return ContentContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 16.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final f in _features)
                  SizedBox(
                    width: width,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(f.icon, color: AppColors.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            f.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            f.body,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
