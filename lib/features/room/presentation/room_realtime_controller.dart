import 'dart:async';

import 'package:get/get.dart';

import '../../queue/presentation/queue_controller.dart';
import '../../recommendations/presentation/recommendation_controller.dart';
import '../domain/room_realtime.dart';
import 'room_controller.dart';

/// Keeps a dashboard live: turns realtime hints into authoritative reloads,
/// tracks presence, and fully resyncs after a connection drop.
class RoomRealtimeController extends GetxController {
  RoomRealtimeController({
    required this.realtime,
    required this.room,
    required this.queue,
    required this.recommendations,
    this.debounce = const Duration(milliseconds: 200),
  });

  final RoomRealtime realtime;
  final RoomController room;
  final QueueController queue;
  final RecommendationController recommendations;
  final Duration debounce;

  final status = RealtimeStatus.connecting.obs;

  RealtimeSubscription? _subscription;
  Worker? _worker;
  Timer? _timer;
  final _dirty = <RoomChange>{};
  bool _started = false;
  bool _disposed = false;
  bool _everConnected = false;

  @override
  void onInit() {
    super.onInit();
    _worker = ever(room.me, (_) => _maybeStart());
    _maybeStart();
  }

  Future<void> _maybeStart() async {
    final me = room.me.value;
    final current = room.room.value;
    if (_started || me == null || current == null) return;
    _started = true;
    final sub = await realtime.connect(
      roomId: current.id,
      me: me,
      onChange: _onChange,
      onPresence: (counts) {
        room.presenceCounts.value = counts;
        room.onlineIds.value = counts.keys.toSet();
      },
      onStatus: _onStatus,
    );
    if (_disposed) {
      await sub.close();
    } else {
      _subscription = sub;
    }
  }

  void _onStatus(RealtimeStatus next) {
    final wasDown = status.value == RealtimeStatus.reconnecting;
    status.value = next;
    room.connection.value = next;
    if (next == RealtimeStatus.connected) {
      // Events missed while disconnected are gone: reload everything. The first
      // connect needs no resync because the dashboard just loaded.
      if (_everConnected && wasDown) resync();
      _everConnected = true;
    }
  }

  void _onChange(RoomChange change) {
    _dirty.add(change);
    _timer ??= Timer(debounce, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    final changes = {..._dirty};
    _dirty.clear();
    if (_disposed || changes.isEmpty) return;
    await Future.wait([
      if (changes.contains(RoomChange.room) ||
          changes.contains(RoomChange.participants))
        room.refreshQuietly(),
      if (changes.contains(RoomChange.recommendations))
        recommendations.load(quiet: true),
      if (changes.contains(RoomChange.queue)) queue.load(quiet: true),
    ]);
  }

  /// Reloads all authoritative state.
  Future<void> resync() => Future.wait([
    room.refreshQuietly(),
    recommendations.load(quiet: true),
    queue.load(quiet: true),
  ]);

  @override
  void onClose() {
    _disposed = true;
    _timer?.cancel();
    _worker?.dispose();
    unawaited(_subscription?.close() ?? Future.value());
    super.onClose();
  }
}
