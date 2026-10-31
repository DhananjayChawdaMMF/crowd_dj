import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/crowd_logo.dart';
import 'landing_controller.dart';
import 'widgets/feature_section.dart';
import 'widgets/hero_section.dart';
import 'widgets/how_it_works_section.dart';
import 'widgets/join_room_dialog.dart';
import 'widgets/landing_footer.dart';

class LandingScreen extends GetView<LandingController> {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void create() => controller.goToCreateRoom(context);
    void join() => showJoinRoomDialog(context, controller);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ContentContainer(
              child: _NavBar(onCreate: create, onJoin: join),
            ),
            HeroSection(onCreate: create, onJoin: join),
            const FeatureSection(),
            const HowItWorksSection(),
            LandingFooter(onCreate: create),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const CrowdLogo(),
          const Spacer(),
          TextButton(
            onPressed: onJoin,
            child: const Text(
              'Join Room',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            SizedBox(
              child: AppButton(label: 'Create Room', onPressed: onCreate),
            ),
          ],
        ],
      ),
    );
  }
}
