import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/task.dart';
import '../util/format.dart';

class TaskNotifier {
  TaskNotifier._();

  static final TaskNotifier instance = TaskNotifier._();

  bool _leadEnabled = true;
  int _leadMinutes = 60;
  String _soundRaw = 'coin';

  String get _channelId => 'esok_reminders_$_soundRaw';

  void configureLead({required bool enabled, required int minutes}) {
    _leadEnabled = enabled;
    _leadMinutes = minutes;
  }

  Future<void> configureSound(String raw) async {
    if (_soundRaw == raw) return;
    _soundRaw = raw;
    await init();
    await _ensureChannel();
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  int notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  int leadNotificationId(String taskId) =>
      (taskId.hashCode ^ 0x5F3759DF) & 0x7fffffff;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error, stack) {
      debugPrint('Timezone init failed: $error\n$stack');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_esok'),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
    await _ensureChannel();
  }

  /// Kanal Android mengunci nada saat dibuat, jadi tiap pilihan suara
  /// memakai kanal sendiri.
  Future<void> _ensureChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        'Pengingat jadwal',
        description: 'Pengingat untuk tugas yang punya jam',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_soundRaw),
      ),
    );
  }

  AndroidNotificationDetails get _details => AndroidNotificationDetails(
    _channelId,
    'Pengingat jadwal',
    channelDescription: 'Pengingat untuk tugas yang punya jam',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(_soundRaw),
  );

  Future<void> showTest() async {
    await init();
    await _ensureChannel();
    await _plugin.show(
      id: 990001,
      title: 'Pengingat tugas',
      body: 'Contoh nada pengingat Esok.',
      notificationDetails: NotificationDetails(android: _details),
    );
  }

  Future<void> requestPermissions() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  Future<void> requestExactAlarms() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> schedule(Task task) async {
    await init();
    await _ensureChannel();
    await cancel(task.id);

    final when = task.scheduledDateTime;
    if (when == null || task.isDone) return;
    final now = DateTime.now();
    if (!when.isAfter(now)) return;

    final details = NotificationDetails(android: _details);

    await _scheduleOne(
      id: notificationId(task.id),
      title: task.title,
      body: 'Pengingat jam ${timeText(task.scheduledTime)}',
      when: when,
      payload: task.id,
      details: details,
    );

    if (!_leadEnabled || task.scheduledTime == null) return;
    final leadWhen = when.subtract(Duration(minutes: _leadMinutes));
    if (!leadWhen.isAfter(now)) return;
    await _scheduleOne(
      id: leadNotificationId(task.id),
      title: task.title,
      body: 'Pengingat awal · pukul ${timeText(task.scheduledTime)}',
      when: leadWhen,
      payload: task.id,
      details: details,
    );
  }

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required NotificationDetails details,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException catch (error) {
      debugPrint('Exact alarm failed, falling back to inexact: $error');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> cancel(String taskId) async {
    await init();
    await _plugin.cancel(id: notificationId(taskId));
    await _plugin.cancel(id: leadNotificationId(taskId));
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAllPendingNotifications();
  }

  Future<void> rescheduleAll(Iterable<Task> tasks) async {
    await init();
    await _plugin.cancelAllPendingNotifications();
    for (final task in tasks) {
      await schedule(task);
    }
  }

  Future<void> reschedule(Task task) async {
    await cancel(task.id);
    await schedule(task);
  }
}
