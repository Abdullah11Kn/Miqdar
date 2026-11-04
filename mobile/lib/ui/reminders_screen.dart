import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

/// Daily phone notifications, off until the user turns them on.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _refused = false;

  Future<void> _setEnabled(MiqdarController controller, bool on) async {
    final allowed = await controller.updateReminders(controller.reminderSettings.copyWith(enabled: on));
    if (mounted) setState(() => _refused = on && !allowed);
  }

  Future<void> _replace(MiqdarController controller, MealReminder updated) => controller.updateReminders(
        controller.reminderSettings.copyWith(
          meals: [
            for (final meal in controller.reminderSettings.meals) meal.meal == updated.meal ? updated : meal,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final c = context.mq;
    final settings = controller.reminderSettings;

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Meal Reminders', 'تذكير الوجبات'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.tr('Remind me to log meals', 'ذكّرني بتسجيل الوجبات'), style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
                subtitle: Text(
                  s.tr('Notifications from this phone. Nothing is sent anywhere.', 'إشعارات من هذا الهاتف. لا يُرسل شيء إلى أي مكان.'),
                  style: MiqdarType.caption.copyWith(color: c.inkMuted),
                ),
                value: settings.enabled,
                onChanged: (on) => _setEnabled(controller, on),
              ),
            ),
            if (_refused) ...[
              const SizedBox(height: 12),
              SurfaceCard(
                color: c.accentSoft,
                child: Text(
                  s.tr(
                    'Notifications are off for Miqdar. To get reminders, allow them in the Settings app. Everything else works as usual.',
                    'الإشعارات متوقفة لمقدار. لتلقي التذكيرات، فعّلها من تطبيق الإعدادات. كل شيء آخر يعمل كالمعتاد.',
                  ),
                  style: MiqdarType.body.copyWith(color: c.ink),
                ),
              ),
            ],
            if (settings.enabled) ...[
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (final meal in settings.meals)
                      Row(
                        children: [
                          Expanded(child: Text(s.mealTypeLabel(meal.meal), style: MiqdarType.body.copyWith(color: c.ink))),
                          TextButton(
                            onPressed: meal.on
                                ? () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: meal.hour, minute: meal.minute),
                                    );
                                    if (picked != null) {
                                      await _replace(controller, meal.copyWith(hour: picked.hour, minute: picked.minute));
                                    }
                                  }
                                : null,
                            child: Text(TimeOfDay(hour: meal.hour, minute: meal.minute).format(context)),
                          ),
                          Switch(
                            value: meal.on,
                            onChanged: (on) => _replace(controller, meal.copyWith(on: on)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
