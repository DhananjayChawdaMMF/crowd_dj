import 'entities/room.dart';

/// Which part of the room changed on the server.
enum RoomChange { room, participants, recommendations, queue }

enum RealtimeStatus { connecting, connected, reconnecting }

abstract interface class RealtimeSubscription {
  Future<void> close();
}

/// Live updates for one room. Events are hints, never data: consumers must
/// re-read authoritative state from the database (events are not durable).
abstract interface class RoomRealtime {
  Future<RealtimeSubscription> connect({
    required String roomId,
    required Participant me,
    required void Function(RoomChange change) onChange,

    /// Participant id -> number of open connections (tabs). Not called if
    /// presence is unavailable.
    required void Function(Map<String, int> connectionsByParticipant)
    onPresence,
    required void Function(RealtimeStatus status) onStatus,
  });
}
