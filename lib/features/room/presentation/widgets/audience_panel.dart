import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel_card.dart';
import '../room_controller.dart';

/// Everyone who has joined the room. Live presence arrives with realtime;
/// until then this lists joined participants, not who is currently online.
class AudiencePanel extends StatelessWidget {
  const AudiencePanel({super.key, required this.controller});

  final RoomController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final people = controller.participants.toList()
        ..sort((a, b) => a.isHost == b.isHost ? 0 : (a.isHost ? -1 : 1));
      final myId = controller.me.value?.id;
      final onlineKnown = controller.onlineIds.value != null;
      return PanelCard(
        title: onlineKnown ? 'Online now' : 'In the room',
        count: onlineKnown ? controller.audienceCount : people.length,
        child: Column(
          children: [
            for (final p in people)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: p.isHost
                              ? AppColors.primary
                              : AppColors.surfaceHigh,
                          child: Text(
                            p.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (onlineKnown)
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controller.isOnline(p.id)
                                    ? AppColors.success
                                    : AppColors.border,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.id == myId ? '${p.displayName} (you)' : p.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'DJ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}
