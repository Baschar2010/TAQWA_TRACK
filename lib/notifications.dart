import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'domain.dart';

/// Lokale Benachrichtigungen: Gebets-Erinnerungen (optional mit Adhan-Ton)
/// und Hinweise von verknüpften Familienmitgliedern.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initializing;

  static const _channelId = 'prayer_reminders';
  static const _adhanChannelId = 'prayer_adhan';
  static const _familyChannelId = 'family_messages';

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialisiert das Plugin genau einmal – auch bei parallelen Aufrufen.
  static Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
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
          description: 'Erinnerungen vor den fünf Gebetszeiten',
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
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _familyChannelId,
          'Familien-Nachrichten',
          description: 'Erinnerungen und Nachrichten deiner Familie',
          importance: Importance.high,
        ),
      );
    } catch (error) {
      debugPrint(
        'Benachrichtigungen konnten nicht initialisiert werden: $error',
      );
    } finally {
      _initialized = true;
    }
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
        channelDescription: 'Erinnerungen vor den fünf Gebetszeiten',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  /// Plant tägliche Erinnerungen für die fünf Gebete.
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
          0 => '${prayerNames[prayer]} – Zeit fürs Gebet',
          _ => '${prayerNames[prayer]} in $minutesBefore Minuten',
        },
        body:
            '${prayerNames[prayer]} beginnt um ${formatClock(schedule.times[prayer]!)}. Möge Allah dein Gebet annehmen.',
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

  /// Sofortige Benachrichtigung, z. B. wenn eine Erinnerung oder Nachricht
  /// eines Familienmitglieds eingetroffen ist.
  static Future<void> showNow({
    required String title,
    required String body,
    int id = 9001,
  }) async {
    try {
      await initialize();
      if (!_supported) return;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _familyChannelId,
            'Familien-Nachrichten',
            channelDescription: 'Erinnerungen und Nachrichten deiner Familie',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
        ),
      );
    } catch (error) {
      // Auf Plattformen ohne Benachrichtigungs-Plugin (z. B. Tests) bleibt
      // die App nutzbar – der Hinweis entfällt dann einfach.
      debugPrint('Benachrichtigung konnte nicht gezeigt werden: $error');
    }
  }
}
