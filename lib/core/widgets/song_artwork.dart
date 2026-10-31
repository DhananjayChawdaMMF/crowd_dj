import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Album artwork with a gradient placeholder for missing/failed images.
class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    this.url,
    required this.size,
    this.radius = 12,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white70,
        size: size * 0.4,
      ),
    );
    final src = url;
    if (src == null || src.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}
