import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/content_container.dart';
import 'hero_visual.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.ofContext(context);
    final wide = size == ScreenSize.desktop;
    final titleSize = switch (size) {
      ScreenSize.desktop => 64.0,
      ScreenSize.tablet => 52.0,
      ScreenSize.mobile => 38.0,
    };

    final text = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          AppConstants.heroTitle,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            AppConstants.heroSubtitle,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            AppButton(
              label: 'Create Room',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
            AppButton(
              label: 'Join Room',
              icon: Icons.login_rounded,
              style: AppButtonStyle.secondary,
              onPressed: onJoin,
            ),
          ],
        ),
      ],
    );

    return ContentContainer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: wide ? 72 : 40),
        child: wide
            ? Row(
                children: [
                  Expanded(flex: 6, child: text),
                  const SizedBox(width: 48),
                  const Expanded(flex: 5, child: HeroVisual()),
                ],
              )
            : Column(
                children: [
                  text,
                  const SizedBox(height: 48),
                  const HeroVisual(),
                ],
              ),
      ),
    );
  }
}
