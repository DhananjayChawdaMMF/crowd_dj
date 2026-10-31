import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class CrowdLogo extends StatelessWidget {
  const CrowdLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        SizedBox(width: size * 0.3),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
