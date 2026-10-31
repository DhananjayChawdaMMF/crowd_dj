import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../core/widgets/content_container.dart';

const _steps = [
  ('1', 'Create a room', 'Name your room and get a unique shareable link.'),
  ('2', 'Share the link', 'Anyone with the link joins as a guest in seconds.'),
  ('3', 'Build the queue', 'Guests recommend, you approve, the music flows.'),
];

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final row = Breakpoints.ofContext(context) != ScreenSize.mobile;

    final items = [
      for (final s in _steps) _Step(number: s.$1, title: s.$2, body: s.$3),
    ];

    return ContentContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            const Text(
              'How it works',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 40),
            if (row)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(child: item)],
              )
            else
              Column(
                children: [
                  for (final item in items) ...[
                    item,
                    const SizedBox(height: 28),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
