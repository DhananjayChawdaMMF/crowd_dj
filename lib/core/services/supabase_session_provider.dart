import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import 'session_provider.dart';

/// Reuses the persisted Supabase session (survives refresh) and only creates
/// a new anonymous user when none exists.
class SupabaseSessionProvider implements SessionProvider {
  SupabaseSessionProvider(this._auth);

  final GoTrueClient _auth;

  @override
  Future<String> ensureSignedIn() async {
    try {
      final existing = _auth.currentUser;
      if (existing != null) return existing.id;
      final response = await _auth.signInAnonymously();
      final user = response.user;
      if (user == null) throw const AppFailure('Could not start a session.');
      return user.id;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
