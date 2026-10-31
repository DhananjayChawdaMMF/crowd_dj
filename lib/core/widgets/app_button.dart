import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonStyle { primary, secondary }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final primary = style == AppButtonStyle.primary;
    final radius = BorderRadius.circular(14);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (loading || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary ? AppColors.brandGradient : null,
            color: primary ? null : AppColors.surface,
            borderRadius: radius,
            border: primary ? null : Border.all(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
