import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/panel_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../recommendation_controller.dart';
import 'recommendation_tile.dart';

/// DJ view: pending recommendations with approve / reject.
class PendingRecommendationsPanel extends StatelessWidget {
  const PendingRecommendationsPanel({
    super.key,
    required this.controller,
    required this.onApprove,
    required this.onReject,
  });

  final RecommendationController controller;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = controller.pending;
      return PanelCard(
        title: 'Recommendations',
        count: controller.loading.value ? null : pending.length,
        child: _body(pending),
      );
    });
  }

  Widget _body(List pending) {
    if (controller.errorMessage.value != null) {
      return ErrorState(
        message: controller.errorMessage.value!,
        onRetry: controller.load,
      );
    }
    if (controller.loading.value && controller.items.isEmpty) {
      return const SkeletonList();
    }
    if (pending.isEmpty) {
      return const EmptyState(
        icon: Icons.thumb_up_alt_outlined,
        title: 'No pending recommendations',
        message: 'Guests\' song suggestions will appear here.',
      );
    }
    return Column(
      children: [
        for (final r in pending)
          RecommendationTile(
            recommendation: r,
            actions: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.busyIds.contains(r.id)
                        ? null
                        : () => onApprove(r.id),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.busyIds.contains(r.id)
                        ? null
                        : () => onReject(r.id),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
