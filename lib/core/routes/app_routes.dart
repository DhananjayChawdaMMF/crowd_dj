abstract final class AppRoutes {
  static const landing = '/';
  static const createRoom = '/create-room';
  static const room = '/room/:code';
  static const djDashboard = '/room/:code/dj';
  static const guestDashboard = '/room/:code/guest';

  static String roomPath(String code) => '/room/$code';
  static String djPath(String code) => '/room/$code/dj';
  static String guestPath(String code) => '/room/$code/guest';
}
