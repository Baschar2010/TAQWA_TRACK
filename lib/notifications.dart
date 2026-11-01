import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'domain.dart';

/// Lokale Benachrichtigungen: Gebets-Erinnerungen (optional mit Adhan-Ton)
/// und Hinweise von verknÃ¼pften Familienmitgliedern.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'prayer_reminders';
  static const _adhanChannelId = 'prayer_adhan';

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!_supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('Zeitzone konnte nicht geladen werden: $error');
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Gebets-Erinnerungen',
        description: 'Erinnerungen vor den fÃ¼nf Gebetszeiten',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _adhanChannelId,
        'Gebets-Erinnerungen mit Signalton',
        description: 'Erinnerungen mit Glockenton',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('adhan'),
        playSound: true,
      ),
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    if (!_supported) return;
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('Benachrichtigungsrechte nicht verfuegbar: $error');
    }
  }

  static NotificationDetails _details({required bool withAdhan}) {
    if (withAdhan) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          _adhanChannelId,
          'Gebets-Erinnerungen mit Signalton',
          channelDescription: 'Erinnerungen mit Glockenton',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('adhan'),
          category: AndroidNotificationCategory.reminder,
        ),
      );
    }
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Gebets-Erinnerungen',
        channelDescription: 'Erinnerungen vor den fÃ¼nf Gebetszeiten',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  /// Plant tÃ¤gliche Erinnerungen fÃ¼r die fÃ¼nf Gebete.
  static Future<void> schedulePrayerReminders({
    required PrayerSchedule schedule,
    required int minutesBefore,
    required bool withAdhan,
  }) async {
    await initialize();
    if (!_supported) return;
    await _plugin.cancelAllPendingNotifications();
    final now = DateTime.now();
    for (final prayer in Prayer.values) {
      final when = schedule.times[prayer]!.subtract(
        Duration(minutes: minutesBefore),
      );
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: prayer.index + 1,
        title: switch (minutesBefore) {
          0 => '${prayerNames[prayer]} â€“ Zeit fÃ¼rs Gebet',
          _ => '${prayerNames[prayer]} in $minutesBefore Minuten',
        },
        body: '${prayerNames[prayer]} beginnt um ${formatClock(schedule.times[prayer]!)}. MÃ¶ge Allah dein Gebet annehmen.',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details(withAdhan: withAdhan),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: prayer.name,
      );
    }
  }

  static Future<void> cancelPrayerReminders() async {
    await initialize();
    if (!_supported) return;
    await _plugin.cancelAllPendingNotifications();
  }

  /// Sofortige Benachrichtigung, z. B. wenn eine Erinnerung eines
  /// Familienmitglieds eingetroffen ist.
  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      if (!_supported) return;
      await _plugin.show(
        id: 9001,
        title: title,
        body: body,
        notificationDetails: _details(withAdhan: true),
      );
    } catch (error) {
      // Auf Plattformen ohne Benachrichtigungs-Plugin (z. B. Tests) bleibt
      // die App nutzbar – der Hinweis entfällt dann einfach.
      debugPrint('Benachrichtigung konnte nicht gezeigt werden: $error');
    }
  }
}
