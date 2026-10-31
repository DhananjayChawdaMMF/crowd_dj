import 'package:crowd_dj/features/room/domain/use_cases/create_room.dart';
import 'package:crowd_dj/features/room/presentation/create_room_controller.dart';
import 'package:crowd_dj/features/room/presentation/create_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

void main() {
  late FakeRoomRepository repo;
  late CreateRoomController controller;

  setUp(() {
    Get.reset();
    repo = FakeRoomRepository();
    controller = Get.put(
      CreateRoomController(CreateRoom(FakeSessions(), repo)),
    );
  });

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CreateRoomScreen()));
  }

  testWidgets('shows validation errors and does not call backend', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.text('Create room').last);
    await tester.pump();

    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(find.text('Enter a room name.'), findsOneWidget);
    expect(repo.created, isNull);
  });

  testWidgets('submits trimmed values and toggles', (tester) async {
    await pumpForm(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Your DJ name'),
      ' Ann ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Room name'),
      'Party',
    );
    await tester.tap(find.text('Enable voting'));
    await tester.pump();

    final session = await tester.runAsync(controller.submit);
    expect(session, isNotNull);
    expect(repo.created?.hostName, ' Ann ');
    expect(repo.created?.enableVoting, isTrue);
  });

  testWidgets('shows backend error message', (tester) async {
    await pumpForm(tester);
    repo.failure = failure('too_many_active_rooms');
    await tester.enterText(
      find.widgetWithText(TextField, 'Your DJ name'),
      'Ann',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Room name'),
      'Party',
    );
    await tester.runAsync(controller.submit);
    await tester.pump();

    expect(find.text('too_many_active_rooms'), findsOneWidget);
  });
}
