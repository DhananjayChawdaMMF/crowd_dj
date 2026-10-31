import 'package:flutter/widgets.dart';

enum ScreenSize { mobile, tablet, desktop }

abstract final class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;

  static ScreenSize of(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  static ScreenSize ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}
