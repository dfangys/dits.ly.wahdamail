import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import '../../../app/controllers/settings_controller.dart';
import '../../../widgets/listile/show_dialog_box.dart';

class SwipGestureSetting extends GetView<SettingController> {
  SwipGestureSetting({super.key});
  final SwapSettingData data = SwapSettingData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Swipe Gestures',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header with explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.swipe,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Customize how swipe gestures behave when managing your emails',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Left to right swipe section
            Text(
              "Left to right swipe",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Left to right swipe card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => const Material(
                      child: ListTileCupertinoDilaogue(
                        direction: "LTR",
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Obx(() {
                        final action = getSwapActionFromString(controller.swipeGesturesLTR());
                        final actionModel = data.swapActionModel[action]!;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: actionModel.backgroundColor.withOpacity(actionModel.opacity),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            actionModel.icon,
                            color: actionModel.iconColor,
                            size: 24,
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(() {
                          final action = getSwapActionFromString(controller.swipeGesturesLTR());
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.swapActionModel[action]!.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Swipe from left to right to ${data.swapActionModel[action]!.text.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Right to left swipe section
            Text(
              "Right to left swipe",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Right to left swipe card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => const Material(
                      child: ListTileCupertinoDilaogue(
                        direction: "RTL",
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Obx(() {
                        final action = getSwapActionFromString(controller.swipeGesturesRTL());
                        final actionModel = data.swapActionModel[action]!;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: actionModel.backgroundColor.withOpacity(actionModel.opacity),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            actionModel.icon,
                            color: actionModel.iconColor,
                            size: 24,
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(() {
                          final action = getSwapActionFromString(controller.swipeGesturesRTL());
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.swapActionModel[action]!.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Swipe from right to left to ${data.swapActionModel[action]!.text.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Swipe animation preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "How it works",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "Swipe on an email to perform actions",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
