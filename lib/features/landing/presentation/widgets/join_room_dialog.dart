import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_button.dart';
import '../landing_controller.dart';

Future<void> showJoinRoomDialog(
  BuildContext context,
  LandingController controller,
) {
  final input = TextEditingController();
  controller.clearJoinError();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join a room',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Obx(
                () => TextField(
                  controller: input,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    hintText: 'Room code or link',
                    errorText: controller.joinError.value,
                  ),
                  onChanged: (_) => controller.clearJoinError(),
                  onSubmitted: (v) => _submit(dialogContext, controller, v),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Join',
                  onPressed: () =>
                      _submit(dialogContext, controller, input.text),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(input.dispose);
}

void _submit(BuildContext context, LandingController c, String value) {
  c.joinRoom(context, value);
  if (c.joinError.value == null) Navigator.of(context).pop();
}
