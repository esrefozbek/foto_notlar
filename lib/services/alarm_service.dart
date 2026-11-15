import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/note.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Bildirim servisini ve saat dilimini başlatır
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        // Yerel saat dilimi bulunamazsa varsayılanı kullan
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Bildirime tıklandığında yapılacak işlemler
        },
      );

      // Android Bildirim Kanalı Oluştur (Yüksek Öncelik ve Ses)
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            'foto_notlar_alarm_channel',
            'Not Alarmları ve Hatırlatıcılar',
            description: 'Notlar için kurulan alarm ve hatırlatıcı bildirimleri',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Android 13+ bildirim izni iste
        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('AlarmService initialize hatası: $e');
    }
  }

  /// Not ID'sinden benzersiz bir integer bildirim ID'si üretir
  static int _getNotificationId(String noteId) {
    return noteId.hashCode.abs() % 1000000;
  }

  /// Bir not için alarm kurar
  static Future<bool> scheduleAlarm(Note note) async {
    if (note.reminderDateTime == null) return false;
    final scheduledDate = note.reminderDateTime!;

    // Geçmiş bir tarihe alarm kurulamaz
    if (scheduledDate.isBefore(DateTime.now())) {
      return false;
    }

    await initialize();

    try {
      final notifId = _getNotificationId(note.id);
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      final androidDetails = AndroidNotificationDetails(
        'foto_notlar_alarm_channel',
        'Not Alarmları ve Hatırlatıcılar',
        channelDescription: 'Notlar için kurulan alarm ve hatırlatıcı bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          note.content.isNotEmpty ? note.content : 'Notunuzun hatırlatıcı zamanı geldi!',
          contentTitle: note.title.isNotEmpty ? note.title : 'Not Hatırlatıcı ⏰',
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: notifId,
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: note.title.isNotEmpty ? note.title : 'Not Hatırlatıcı ⏰',
        body: note.content.isNotEmpty
            ? (note.content.length > 80 ? '${note.content.substring(0, 80)}...' : note.content)
            : 'Notunuzun hatırlatıcı vakti geldi!',
        payload: note.id,
      );

      return true;
    } catch (e) {
      debugPrint('Alarm kurma hatası: $e');
      return false;
    }
  }

  /// Bir notun alarmını iptal eder
  static Future<void> cancelAlarm(String noteId) async {
    try {
      await initialize();
      final notifId = _getNotificationId(noteId);
      await _notificationsPlugin.cancel(id: notifId);
    } catch (e) {
      debugPrint('Alarm iptal hatası: $e');
    }
  }

  /// Tarih & Saat seçme diyaloğu (Hızlı önayarlar + Takvim)
  static Future<DateTime?> showAlarmPicker(
    BuildContext context, {
    DateTime? currentReminder,
  }) async {
    final now = DateTime.now();

    return await showModalBottomSheet<DateTime?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Wrap(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.alarm_add_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hatırlatıcı & Alarm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Nota ne zaman alarm kurulsun?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Hızlı Seçenek 1: 15 Dakika Sonra
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.deepPurple),
                  title: const Text('15 dakika sonra'),
                  subtitle: Text(DateFormat('HH:mm').format(now.add(const Duration(minutes: 15)))),
                  onTap: () => Navigator.pop(ctx, now.add(const Duration(minutes: 15))),
                ),

                // Hızlı Seçenek 2: 1 Saat Sonra
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom_rounded, color: Colors.blueAccent),
                  title: const Text('1 saat sonra'),
                  subtitle: Text(DateFormat('HH:mm').format(now.add(const Duration(hours: 1)))),
                  onTap: () => Navigator.pop(ctx, now.add(const Duration(hours: 1))),
                ),

                // Hızlı Seçenek 3: Yarın Sabah 09:00
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
                  title: const Text('Yarın sabah'),
                  subtitle: const Text('09:00'),
                  onTap: () {
                    final tomorrow = now.add(const Duration(days: 1));
                    final tomorrowMorning = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
                    Navigator.pop(ctx, tomorrowMorning);
                  },
                ),

                // Özel Tarih & Saat Seçimi
                ListTile(
                  leading: const Icon(Icons.edit_calendar_rounded, color: Colors.green),
                  title: const Text('Özel Tarih ve Saat Seç...'),
                  subtitle: const Text('Takvimden istediğiniz günü ve saati belirleyin'),
                  onTap: () async {
                    final nav = Navigator.of(ctx);
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: currentReminder ?? now.add(const Duration(hours: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );

                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          currentReminder ?? now.add(const Duration(hours: 1)),
                        ),
                      );

                      if (pickedTime != null) {
                        final finalDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );

                        if (finalDateTime.isBefore(DateTime.now())) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Geçmiş bir zamana alarm kurulamaz!')),
                            );
                          }
                        } else {
                          nav.pop(finalDateTime);
                        }
                      }
                    }
                  },
                ),

                // Eğer zaten kurulu bir alarm varsa: Alarmı Kaldır butonu
                if (currentReminder != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.alarm_off_rounded, color: Colors.redAccent),
                    title: const Text('Alarmı Kaldır', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Mevcut: ${DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(currentReminder)}'),
                    onTap: () => Navigator.pop(ctx, DateTime(1970)), // 1970 silme sinyali
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
