import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'crowd_logo.dart';

/// Full-page message with a way back home (not found, backend not configured).
class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrowdLogo(size: 40),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, style: const TextStyle(color: AppColors.textMuted)),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(AppRoutes.landing),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
