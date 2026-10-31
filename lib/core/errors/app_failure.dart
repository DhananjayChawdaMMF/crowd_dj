import 'package:supabase_flutter/supabase_flutter.dart';

class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  /// Maps backend error codes (raised by the RPCs) and transport errors to
  /// user-facing messages.
  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is PostgrestException) {
      final code = error.message;
      return AppFailure(
        _messages[code] ?? 'Something went wrong. Please try again.',
        code: code,
      );
    }
    if (error is AuthException) {
      return AppFailure('Could not start a session: ${error.message}');
    }
    return const AppFailure(
      'Network problem. Check your connection and retry.',
    );
  }

  static const _messages = {
    'room_not_found': 'That room does not exist.',
    'room_full': 'This room is full.',
    'stale_playback_version': 'Playback changed elsewhere. Refreshing.',
    'nothing_to_play': 'There is nothing to play yet.',
    'already_recommended': 'That song is already pending or in the queue.',
    'rate_limited': 'Slow down a little. Try again in a minute.',
    'recommendations_disabled': 'The DJ turned off recommendations.',
    'already_reviewed': 'That recommendation was already handled.',
    'recommendation_not_found': 'That recommendation no longer exists.',
    'queue_item_not_found': 'That song is no longer in the queue.',
    'invalid_song': 'That song cannot be recommended.',
    'room_closed': 'This room has been closed.',
    'forbidden': 'You are not allowed to do that.',
    'invalid_room_name': 'Room name must be 1–80 characters.',
    'invalid_display_name': 'Display name must be 1–40 characters.',
    'too_many_active_rooms':
        'You already have the maximum number of open rooms.',
    'not_authenticated': 'Your session expired. Reload the page.',
  };

  @override
  String toString() => message;
}
