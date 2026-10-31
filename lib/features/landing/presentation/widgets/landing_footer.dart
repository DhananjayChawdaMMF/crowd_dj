import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/content_container.dart';
import '../../../../core/widgets/crowd_logo.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ContentContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Text(
                'Ready to hand the aux to the crowd?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Create Room', onPressed: onCreate),
              const SizedBox(height: 40),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                spacing: 24,
                children: const [
                  CrowdLogo(size: 24),
                  Text(
                    '© ${AppConstants.appName}',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
