import 'package:flutter/material.dart';

import '../utils/breakpoints.dart';

/// Centers content with a max width and responsive horizontal gutters.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = Breakpoints.ofContext(context) == ScreenSize.mobile
        ? 20.0
        : 32.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}
