import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/crowd_logo.dart';
import 'create_room_controller.dart';

class CreateRoomScreen extends GetView<CreateRoomController> {
  const CreateRoomScreen({super.key});

  Future<void> _submit(BuildContext context) async {
    final session = await controller.submit();
    if (session != null && context.mounted) {
      context.go(AppRoutes.djPath(session.room.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const CrowdLogo(size: 28),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.landing),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a room',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You will be the DJ. Share the link once it is ready.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => TextField(
                      controller: controller.hostName,
                      decoration: InputDecoration(
                        labelText: 'Your DJ name',
                        errorText: controller.hostNameError.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => TextField(
                      controller: controller.roomName,
                      decoration: InputDecoration(
                        labelText: 'Room name',
                        errorText: controller.roomNameError.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => TextField(
                      controller: controller.description,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        errorText: controller.descriptionError.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public room'),
                      subtitle: const Text(
                        'Private rooms are only reachable by link.',
                      ),
                      value: controller.isPublic.value,
                      onChanged: controller.isPublic.call,
                    ),
                  ),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow song recommendations'),
                      value: controller.allowRecommendations.value,
                      onChanged: controller.allowRecommendations.call,
                    ),
                  ),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable voting'),
                      value: controller.enableVoting.value,
                      onChanged: controller.enableVoting.call,
                    ),
                  ),
                  Obx(() {
                    final err = controller.submitError.value;
                    return err == null
                        ? const SizedBox(height: 12)
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              err,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          );
                  }),
                  SizedBox(
                    width: double.infinity,
                    child: Obx(
                      () => AppButton(
                        label: 'Create room',
                        loading: controller.loading.value,
                        onPressed: () => _submit(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
