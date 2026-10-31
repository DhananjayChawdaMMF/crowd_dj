import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/server_clock.dart';
import '../../../core/services/session_provider.dart';
import '../../music_player/domain/playback_state.dart';
import '../domain/entities/room.dart';
import '../domain/room_realtime.dart';
import '../domain/room_repository.dart';

enum RoomStatus { loading, ready, error }

/// Loads the room for a dashboard and enforces which dashboard the caller may
/// see. The URL is the only input; the backend (RLS) decides membership.
/// This is UX routing only; the real authorization is in the database.
class RoomController extends GetxController {
  RoomController({
    required this.code,
    required this.expectedRole,
    required this.sessions,
    required this.rooms,
    Uri? baseUri,
    ServerClock? clock,
  }) : _baseUri = baseUri ?? Uri.base,
       clock = clock ?? ServerClock();

  final String code;
  final ParticipantRole expectedRole;
  final SessionProvider sessions;
  final RoomRepository rooms;
  final Uri _baseUri;
  final ServerClock clock;

  final status = RoomStatus.loading.obs;
  final room = Rxn<Room>();
  final participants = <Participant>[].obs;
  final me = Rxn<Participant>();
  final errorMessage = RxnString();
  final notice = RxnString();

  /// Realtime connection health, written by the realtime controller.
  final connection = RealtimeStatus.connecting.obs;

  /// Participant ids currently present, or null while presence is unavailable.
  final onlineIds = Rxn<Set<String>>();

  /// Open connections per participant id (more than 1 = several tabs).
  final presenceCounts = Rxn<Map<String, int>>();
  final closing = false.obs;

  /// Set when the caller should be sent elsewhere (join page / other dashboard).
  final redirectTo = RxnString();

  @override
  void onReady() {
    super.onReady();
    load();
  }

  String get shareUrl {
    final path = AppRoutes.roomPath(code.toUpperCase());
    final isWeb = _baseUri.scheme == 'http' || _baseUri.scheme == 'https';
    return isWeb ? '${_baseUri.origin}$path' : path;
  }

  String get hostName =>
      participants
          .firstWhereOrNull((p) => p.role == ParticipantRole.host)
          ?.displayName ??
      'DJ';

  /// Live audience size: present participants when presence works, otherwise
  /// everyone who has joined.
  int get audienceCount => onlineIds.value?.length ?? participants.length;

  bool isOnline(String participantId) =>
      onlineIds.value?.contains(participantId) ?? true;

  /// True when the caller has this room open in more than one tab.
  bool get openInAnotherTab {
    final id = me.value?.id;
    if (id == null) return false;
    return (presenceCounts.value?[id] ?? 1) > 1;
  }

  bool get hostOnline {
    final ids = onlineIds.value;
    if (ids == null) return true;
    final host = participants.firstWhereOrNull((p) => p.isHost);
    return host != null && ids.contains(host.id);
  }

  bool get roomClosed => room.value != null && !room.value!.isActive;

  Future<void> load() async {
    status.value = RoomStatus.loading;
    errorMessage.value = null;
    try {
      final userId = await sessions.ensureSignedIn();
      await clock.sync();
      final loaded = await rooms.fetchRoom(code);
      final people = await rooms.fetchParticipants(loaded.id);
      final mine = people.firstWhereOrNull((p) => p.userId == userId);

      if (mine == null) {
        redirectTo.value = AppRoutes.roomPath(code.toUpperCase());
        return;
      }
      if (mine.role != expectedRole) {
        redirectTo.value = mine.isHost
            ? AppRoutes.djPath(loaded.code)
            : AppRoutes.guestPath(loaded.code);
        return;
      }
      room.value = loaded;
      participants.assignAll(people);
      me.value = mine;
      status.value = RoomStatus.ready;
    } catch (e) {
      final failure = AppFailure.from(e);
      if (failure.code == 'room_not_found') {
        // Not a member (or no such room): the join page sorts it out.
        redirectTo.value = AppRoutes.roomPath(code.toUpperCase());
        return;
      }
      errorMessage.value = failure.message;
      status.value = RoomStatus.error;
    }
  }

  /// Reloads room + participants without flashing the loading state.
  Future<void> refreshQuietly() async {
    try {
      final loaded = await rooms.fetchRoom(code);
      final people = await rooms.fetchParticipants(loaded.id);
      room.value = loaded;
      participants.assignAll(people);
    } catch (_) {
      // Keep showing the last known state; the manual refresh surfaces errors.
    }
  }

  /// Applies a locally known playback snapshot (e.g. the result of a host
  /// action) without a round trip.
  void applyPlayback(PlaybackState playback) {
    final current = room.value;
    if (current != null) room.value = current.copyWith(playback: playback);
  }

  /// Host: closes the room. The room row flips to closed and every dashboard
  /// switches to the closed view on its next refresh.
  Future<bool> closeRoom() async {
    final current = room.value;
    if (current == null || closing.value) return false;
    closing.value = true;
    try {
      await rooms.closeRoom(current.id);
      await refreshQuietly();
      return true;
    } catch (e) {
      notice.value = AppFailure.from(e).message;
      return false;
    } finally {
      closing.value = false;
    }
  }
}
