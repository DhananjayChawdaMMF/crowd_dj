import 'package:crowd_dj/core/utils/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Breakpoints map widths to screen sizes', () {
    expect(Breakpoints.of(375), ScreenSize.mobile);
    expect(Breakpoints.of(800), ScreenSize.tablet);
    expect(Breakpoints.of(1400), ScreenSize.desktop);
  });
}
