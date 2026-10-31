import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/crowd_logo.dart';
import 'room_entry_controller.dart';

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key});

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final controller = Get.find<RoomEntryController>();
  final _name = TextEditingController();
  late final Worker _redirect;

  @override
  void initState() {
    super.initState();
    _redirect = ever<String?>(controller.redirectTo, (path) {
      if (path != null && mounted) context.go(path);
    });
  }

  @override
  void dispose() {
    _redirect.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrowdLogo(size: 36),
                const SizedBox(height: 28),
                Obx(_body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (controller.status.value) {
      case RoomEntryStatus.loading:
      case RoomEntryStatus.joining:
        return const Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        );
      case RoomEntryStatus.needsName:
        final p = controller.preview.value!;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (p.hostName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'DJ ${p.hostName}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 20),
              Obx(
                () => TextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    labelText: 'Your display name',
                    errorText: controller.nameError.value,
                  ),
                  onSubmitted: controller.submitName,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Join room',
                  onPressed: () => controller.submitName(_name.text),
                ),
              ),
            ],
          ),
        );
      case RoomEntryStatus.closed:
        return _message('This room has been closed.', retry: false);
      case RoomEntryStatus.error:
        return _message(
          controller.errorMessage.value ?? 'Something went wrong.',
          retry: true,
        );
    }
  }

  Widget _message(String text, {required bool retry}) {
    return AppCard(
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          if (retry) AppButton(label: 'Try again', onPressed: controller.load),
          if (retry) const SizedBox(height: 12),
          AppButton(
            label: 'Back to home',
            style: AppButtonStyle.secondary,
            onPressed: () => context.go(AppRoutes.landing),
          ),
        ],
      ),
    );
  }
}
