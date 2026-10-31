import 'package:crowd_dj/features/landing/domain/room_code_validator.dart';
import 'package:crowd_dj/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('RoomCodeValidator', () {
    test('accepts bare codes and uppercases them', () {
      expect(RoomCodeValidator.extract(' ab12cd '), 'AB12CD');
    });

    test('extracts code from room URLs', () {
      expect(
        RoomCodeValidator.extract('https://crowddj.app/room/AB12CD/guest'),
        'AB12CD',
      );
    });

    test('rejects invalid input', () {
      expect(RoomCodeValidator.extract(''), isNull);
      expect(RoomCodeValidator.extract('a b'), isNull);
      expect(RoomCodeValidator.extract('https://x.com/other'), isNull);
    });
  });

  group('Landing page', () {
    setUp(Get.reset);

    testWidgets('shows hero copy and CTAs', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CrowdDjApp());
      await tester.pump();

      expect(find.text('Your Music. Your Crowd. Your Vibe.'), findsOneWidget);
      expect(find.text('Create Room'), findsWidgets);
      expect(find.text('Join Room'), findsWidgets);
      expect(find.text('How it works'), findsOneWidget);
    });

    testWidgets('join dialog rejects invalid code', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CrowdDjApp());
      await tester.pump();

      await tester.tap(find.text('Join Room').first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'no good');
      await tester.tap(find.text('Join').last);
      await tester.pump();

      expect(find.text('Enter a valid room code or link.'), findsOneWidget);
    });
  });
}
