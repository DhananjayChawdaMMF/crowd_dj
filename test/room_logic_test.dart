import 'package:crowd_dj/core/errors/app_failure.dart';
import 'package:crowd_dj/features/room/domain/entities/room.dart';
import 'package:crowd_dj/features/room/domain/room_validator.dart';
import 'package:crowd_dj/features/room/domain/use_cases/create_room.dart';
import 'package:crowd_dj/features/room/domain/use_cases/get_room_preview.dart';
import 'package:crowd_dj/features/room/domain/use_cases/join_room.dart';
import 'package:crowd_dj/features/room/presentation/room_entry_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

void main() {
  late FakeSessions sessions;
  late FakeRoomRepository repo;

  setUp(() {
    Get.reset();
    sessions = FakeSessions();
    repo = FakeRoomRepository();
  });

  group('RoomValidator', () {
    test('display and room names', () {
      expect(RoomValidator.displayName('  '), isNotNull);
      expect(RoomValidator.displayName('Ann'), isNull);
      expect(RoomValidator.displayName('x' * 41), isNotNull);
      expect(RoomValidator.roomName(''), isNotNull);
      expect(RoomValidator.roomName('x' * 81), isNotNull);
      expect(RoomValidator.description('x' * 501), isNotNull);
      expect(RoomValidator.description(null), isNull);
    });
  });

  group('CreateRoom', () {
    test('signs in anonymously then creates', () async {
      final session = await CreateRoom(sessions, repo)(
        const CreateRoomParams(hostName: 'Ann', roomName: 'Party'),
      );
      expect(sessions.signIns, 1);
      expect(repo.created?.roomName, 'Party');
      expect(session.participant.isHost, isTrue);
    });

    test('rejects invalid input without touching backend', () async {
      expect(
        CreateRoom(sessions, repo)(
          const CreateRoomParams(hostName: '', roomName: 'Party'),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(sessions.signIns, 0);
      expect(repo.created, isNull);
    });
  });

  group('JoinRoom', () {
    test('trims the display name', () async {
      await JoinRoom(sessions, repo)('ABC1234567', '  Bob ');
      expect(repo.joinedAs, 'Bob');
    });
  });

  group('RoomEntryController', () {
    RoomEntryController build() => RoomEntryController(
      'ABC1234567',
      GetRoomPreview(sessions, repo),
      JoinRoom(sessions, repo),
    );

    test('new visitor is asked for a name, then sent to guest view', () async {
      final c = build();
      await c.load();
      expect(c.status.value, RoomEntryStatus.needsName);

      await c.submitName('');
      expect(c.nameError.value, isNotNull);
      expect(c.redirectTo.value, isNull);

      await c.submitName('Bob');
      expect(c.redirectTo.value, '/room/ABC1234567/guest');
    });

    test('returning host is rejoined straight to the DJ dashboard', () async {
      repo.preview = const RoomPreview(
        code: 'ABC1234567',
        name: 'Party',
        description: null,
        hostName: 'Ann',
        isActive: true,
        isHost: true,
        myDisplayName: 'Ann',
      );
      final c = build();
      await c.load();
      expect(c.redirectTo.value, '/room/ABC1234567/dj');
    });

    test('closed room is reported, not joined', () async {
      repo.preview = const RoomPreview(
        code: 'ABC1234567',
        name: 'Party',
        description: null,
        hostName: 'Ann',
        isActive: false,
        isHost: false,
        myDisplayName: null,
      );
      final c = build();
      await c.load();
      expect(c.status.value, RoomEntryStatus.closed);
      expect(repo.joinedAs, isNull);
    });

    test('backend failure surfaces an error state', () async {
      repo.failure = failure('room_not_found');
      final c = build();
      await c.load();
      expect(c.status.value, RoomEntryStatus.error);
      expect(c.errorMessage.value, 'room_not_found');
    });
  });
}
