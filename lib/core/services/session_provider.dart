/// Abstraction over "make sure there is a signed-in (anonymous) user".
abstract interface class SessionProvider {
  /// Returns the current user id, signing in anonymously if needed.
  Future<String> ensureSignedIn();
}
