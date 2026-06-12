import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'skinlog_daily';
  static const _notifId = 1;

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Lembrete diário',
            description: 'Aviso para registrar a pele todos os dias',
            importance: Importance.defaultImportance,
          ),
        );
  }

  // Cancela a notificação pendente e agenda uma nova para as 20h
  // se o usuário ainda não registrou hoje.
  static Future<void> scheduleOrCancel(bool registeredToday) async {
    if (kIsWeb) return;
    await _plugin.cancel(_notifId);
    if (registeredToday) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 20h
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      'Hora do seu registro! 🌿',
      'Você ainda não registrou sua pele hoje. Leva menos de 1 minuto.',
      scheduled,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          'Lembrete diário',
          channelDescription: 'Aviso para registrar a pele todos os dias',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
