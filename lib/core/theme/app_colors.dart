import 'package:flutter/material.dart';

/// CrowdDJ palette. Dark-first.
abstract final class AppColors {
  static const background = Color(0xFF0B0B12);
  static const surface = Color(0xFF151522);
  static const surfaceHigh = Color(0xFF1D1D2E);
  static const border = Color(0xFF2A2A3F);

  static const primary = Color(0xFF8B5CF6);
  static const primaryDark = Color(0xFF6D3FE0);
  static const secondary = Color(0xFF3B82F6);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9A9AB0);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);

  static const brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
