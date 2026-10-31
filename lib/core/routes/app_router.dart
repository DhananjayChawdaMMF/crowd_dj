import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/audience/presentation/audience_binding.dart';
import '../../features/audience/presentation/audience_screen.dart';
import '../../features/dj_dashboard/presentation/dj_dashboard_binding.dart';
import '../../features/dj_dashboard/presentation/dj_dashboard_screen.dart';
import '../../features/landing/presentation/landing_binding.dart';
import '../../features/landing/presentation/landing_controller.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/room/presentation/create_room_binding.dart';
import '../../features/room/presentation/create_room_controller.dart';
import '../../features/room/presentation/create_room_screen.dart';
import '../../features/room/presentation/room_entry_binding.dart';
import '../../features/room/presentation/room_entry_controller.dart';
import '../../features/room/presentation/room_entry_screen.dart';
import '../widgets/binding_scope.dart';
import '../widgets/message_screen.dart';
import 'app_routes.dart';

/// Every route is derived from the URL alone, so deep links work in a fresh tab.
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    errorBuilder: (context, state) => const MessageScreen(
      title: 'Page not found',
      detail: 'The link may be wrong or the room may have expired.',
    ),
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (context, state) => BindingScope(
          binding: LandingBinding(),
          onDispose: [() => Get.delete<LandingController>()],
          child: const LandingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.createRoom,
        builder: (context, state) => BindingScope(
          binding: CreateRoomBinding(),
          onDispose: [() => Get.delete<CreateRoomController>()],
          child: const CreateRoomScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.room,
        builder: (context, state) => BindingScope(
          key: ValueKey(state.pathParameters['code']),
          binding: RoomEntryBinding(state.pathParameters['code']!),
          onDispose: [() => Get.delete<RoomEntryController>()],
          child: const RoomEntryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.djDashboard,
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return BindingScope(
            key: ValueKey('dj-$code'),
            binding: DJDashboardBinding(code),
            onDispose: [() => DJDashboardBinding.dispose(code)],
            child: DJDashboardScreen(code: code),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.guestDashboard,
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return BindingScope(
            key: ValueKey('guest-$code'),
            binding: AudienceBinding(code),
            onDispose: [() => AudienceBinding.dispose(code)],
            child: AudienceScreen(code: code),
          );
        },
      ),
    ],
  );
}
