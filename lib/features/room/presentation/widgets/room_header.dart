import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/crowd_logo.dart';

class RoomHeader extends StatelessWidget {
  const RoomHeader({
    super.key,
    required this.roomName,
    required this.audienceCount,
    required this.actions,
    this.compact = false,
    this.subtitle,
    this.reconnecting = false,
  });

  final String roomName;
  final String? subtitle;
  final int audienceCount;
  final List<Widget> actions;
  final bool compact;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!compact) ...[const CrowdLogo(size: 30), const SizedBox(width: 20)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  reconnecting ? const _ReconnectingChip() : const _LiveChip(),
                ],
              ),
              Text(
                [?subtitle, '$audienceCount in the room'].join(' · '),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AppColors.success),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconnectingChip extends StatelessWidget {
  const _ReconnectingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.danger,
            ),
          ),
          SizedBox(width: 5),
          Text(
            'RECONNECTING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
