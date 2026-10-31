import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/panel_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../recommendation_controller.dart';
import 'recommendation_tile.dart';

/// Guest view: the caller's own recommendations and their review status.
class MyRecommendationsPanel extends StatelessWidget {
  const MyRecommendationsPanel({super.key, required this.controller});

  final RecommendationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mine = controller.mine;
      return PanelCard(
        title: 'Your recommendations',
        count: controller.loading.value ? null : mine.length,
        child: _body(mine),
      );
    });
  }

  Widget _body(List mine) {
    if (controller.errorMessage.value != null) {
      return ErrorState(
        message: controller.errorMessage.value!,
        onRetry: controller.load,
      );
    }
    if (controller.loading.value && controller.items.isEmpty) {
      return const SkeletonList(count: 2);
    }
    if (mine.isEmpty) {
      return const EmptyState(
        icon: Icons.library_music_outlined,
        title: 'You have not recommended anything yet',
        message: 'Songs you suggest will show their status here.',
      );
    }
    return Column(
      children: [
        for (final r in mine)
          RecommendationTile(
            recommendation: r,
            showGuest: false,
            showStatus: true,
          ),
      ],
    );
  }
}
