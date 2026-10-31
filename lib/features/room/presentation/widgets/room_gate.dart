import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/crowd_logo.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/room.dart';
import '../room_controller.dart';

/// Shows loading / error / closed states and performs role redirects; renders
/// [builder] once the room is loaded and the caller holds the expected role.
class RoomGate extends StatefulWidget {
  const RoomGate({super.key, required this.controller, required this.builder});

  final RoomController controller;
  final Widget Function(BuildContext context, Room room) builder;

  @override
  State<RoomGate> createState() => _RoomGateState();
}

class _RoomGateState extends State<RoomGate> {
  Worker? _redirect;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _redirect = ever<String?>(c.redirectTo, _go);
    // The redirect may already have been decided before this widget mounted.
    if (c.redirectTo.value != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _go(c.redirectTo.value),
      );
    }
  }

  void _go(String? path) {
    if (path != null && mounted) context.go(path);
  }

  @override
  void dispose() {
    _redirect?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Obx(() {
      switch (c.status.value) {
        case RoomStatus.loading:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        case RoomStatus.error:
          return Scaffold(
            body: Center(
              child: ErrorState(
                message: c.errorMessage.value ?? 'Something went wrong.',
                onRetry: c.load,
              ),
            ),
          );
        case RoomStatus.ready:
          final room = c.room.value!;
          if (!room.isActive) return const _ClosedView();
          return widget.builder(context, room);
      }
    });
  }
}

class _ClosedView extends StatelessWidget {
  const _ClosedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CrowdLogo(size: 36),
            const SizedBox(height: 28),
            const Text(
              'This room has been closed.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Back to home',
              onPressed: () => context.go(AppRoutes.landing),
            ),
          ],
        ),
      ),
    );
  }
}
