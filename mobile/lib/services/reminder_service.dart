import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MealReminder {
  const MealReminder({required this.meal, required this.on, required this.hour, required this.minute});

  final String meal;
  final bool on;
  final int hour;
  final int minute;

  MealReminder copyWith({bool? on, int? hour, int? minute}) =>
      MealReminder(meal: meal, on: on ?? this.on, hour: hour ?? this.hour, minute: minute ?? this.minute);

  Map<String, Object> toJson() => {'meal': meal, 'on': on, 'hour': hour, 'minute': minute};

  factory MealReminder.fromJson(Map<String, dynamic> json) => MealReminder(
        meal: json['meal'] as String,
        on: json['on'] as bool,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
}

/// Off until the user turns them on.
class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.meals = defaults});

  static const defaults = [
    MealReminder(meal: 'Breakfast', on: true, hour: 8, minute: 0),
    MealReminder(meal: 'Lunch', on: true, hour: 13, minute: 0),
    MealReminder(meal: 'Dinner', on: true, hour: 19, minute: 0),
  ];

  final bool enabled;
  final List<MealReminder> meals;

  ReminderSettings copyWith({bool? enabled, List<MealReminder>? meals}) =>
      ReminderSettings(enabled: enabled ?? this.enabled, meals: meals ?? this.meals);

  String encode() => jsonEncode({'enabled': enabled, 'meals': [for (final m in meals) m.toJson()]});

  factory ReminderSettings.decode(String? text) {
    if (text == null || text.isEmpty) return const ReminderSettings();
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return ReminderSettings(
        enabled: json['enabled'] as bool,
        meals: (json['meals'] as List<dynamic>).cast<Map<String, dynamic>>().map(MealReminder.fromJson).toList(),
      );
    } catch (_) {
      return const ReminderSettings();
    }
  }
}

/// A notification to repeat every day at this time.
class DailyReminder {
  const DailyReminder({required this.id, required this.body, required this.hour, required this.minute});

  final int id;
  final String body;
  final int hour;
  final int minute;
}

abstract class ReminderScheduler {
  /// Asks only when the user turns reminders on. False if they refuse.
  Future<bool> requestPermission();
  Future<void> replaceAll(List<DailyReminder> reminders);
}

/// Local notifications only: nothing leaves the phone.
class LocalNotificationReminders implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _prepare() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _prepare();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<DailyReminder> reminders) async {
    await _prepare();
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final reminder in reminders) {
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, reminder.hour, reminder.minute);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: 'Miqdar',
        body: reminder.body,
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('meal_reminders', 'Meal reminders'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
