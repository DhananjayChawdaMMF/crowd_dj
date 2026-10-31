import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/room.dart';
import '../domain/room_realtime.dart';

/// Two channels per room:
///  * `room-data:<id>`: postgres_changes, protected by table RLS (members only).
///  * `room:<id>`: private presence channel, protected by Realtime
///    authorization policies (see the realtime_authorization migration).
class SupabaseRoomRealtime implements RoomRealtime {
  SupabaseRoomRealtime(this._client);

  final SupabaseClient _client;

  @override
  Future<RealtimeSubscription> connect({
    required String roomId,
    required Participant me,
    required void Function(RoomChange change) onChange,
    required void Function(Map<String, int> connectionsByParticipant)
    onPresence,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    onStatus(RealtimeStatus.connecting);

    RealtimeChannel data = _client.channel('room-data:$roomId');
    void listen(String table, String column, RoomChange change) {
      data = data.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: roomId,
        ),
        callback: (_) => onChange(change),
      );
    }

    listen('rooms', 'id', RoomChange.room);
    listen('participants', 'room_id', RoomChange.participants);
    listen('recommendations', 'room_id', RoomChange.recommendations);
    listen('queue', 'room_id', RoomChange.queue);

    data.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onStatus(RealtimeStatus.connected);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          // The client rejoins automatically; "subscribed" fires again after.
          onStatus(RealtimeStatus.reconnecting);
      }
    });

    final presence = _client.channel(
      'room:$roomId',
      opts: RealtimeChannelConfig(key: me.id, private: true),
    );
    presence
        .onPresenceSync((_) {
          onPresence({
            for (final s in presence.presenceState()) s.key: s.presences.length,
          });
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await presence.track({
              'participant_id': me.id,
              'name': me.displayName,
              'role': me.role.name,
            });
          }
        });

    return _Subscription(_client, data, presence);
  }
}

class _Subscription implements RealtimeSubscription {
  _Subscription(this._client, this._data, this._presence);

  final SupabaseClient _client;
  final RealtimeChannel _data;
  final RealtimeChannel _presence;

  @override
  Future<void> close() async {
    try {
      await _presence.untrack();
    } catch (_) {}
    await _client.removeChannel(_data);
    await _client.removeChannel(_presence);
  }
}
