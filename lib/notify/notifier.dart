import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/task.dart';
import '../data/database.dart';
import '../data/task_dao.dart';
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
  bool _timezoneKnown = false;

  int notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  int leadNotificationId(String taskId) =>
      (taskId.hashCode ^ 0x5F3759DF) & 0x7fffffff;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _refreshTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_esok'),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
    await _ensureChannel();
  }

  Future<bool> _refreshTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(info.identifier);
      final changed = !_timezoneKnown || tz.local.name != location.name;
      _timezoneKnown = true;
      if (!changed) return false;
      tz.setLocalLocation(location);
      return true;
    } catch (error, stack) {
      debugPrint('Timezone init failed: $error\n$stack');
      return false;
    }
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
    if (task.isRecurring) {
      await syncFromDatabase();
      return;
    }
    await _scheduleOccurrence(task);
  }

  Future<void> _scheduleOccurrence(Task task, {Set<int>? pending}) async {
    await init();
    await _ensureChannel();
    if (pending == null) await cancel(task.id);

    final when = _scheduledTime(task);
    if (when == null || task.isDone) return;
    final now = DateTime.now();
    if (!when.isAfter(now)) return;

    final details = NotificationDetails(android: _details);

    if (pending?.contains(notificationId(task.id)) != true) {
      await _scheduleOne(
        id: notificationId(task.id),
        title: task.title,
        body: 'Pengingat jam ${timeText(task.scheduledTime)}',
        when: when,
        payload: task.id,
        details: details,
      );
    }

    if (!_leadEnabled || task.scheduledTime == null) return;
    final leadWhen = when.subtract(Duration(minutes: _leadMinutes));
    if (!leadWhen.isAfter(now) ||
        pending?.contains(leadNotificationId(task.id)) == true) {
      return;
    }
    await _scheduleOne(
      id: leadNotificationId(task.id),
      title: task.title,
      body: 'Pengingat awal · pukul ${timeText(task.scheduledTime)}',
      when: leadWhen,
      payload: task.id,
      details: details,
    );
  }

  DateTime? _scheduledTime(Task task) {
    final hour = task.hour;
    if (hour == null) return null;
    if (!_timezoneKnown) return task.scheduledDateTime;
    final day = task.date;
    return tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      hour,
      task.minute ?? 0,
    );
  }

  DateTime _localNow() =>
      _timezoneKnown ? tz.TZDateTime.now(tz.local) : DateTime.now();

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

  Future<List<Task>> _readTasks() async {
    final db = await AppDatabase.open();
    return TaskDao(db).all();
  }

  Future<void> syncFromDatabase() =>
      _enqueue(() async => _replaceSchedule(await _readTasks()));

  Future<void> _pendingSync = Future<void>.value();
  String? _filledDay;

  Future<void> _enqueue(Future<void> Function() work) {
    final operation = _pendingSync.then((_) => work());
    _pendingSync = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> rescheduleAll(Iterable<Task> tasks) {
    final rows = tasks.toList(growable: false);
    return _enqueue(() => _replaceSchedule(rows));
  }

  Future<void> topUpRecurring() => _enqueue(() async {
    await init();
    if (await _refreshTimezone()) {
      _filledDay = null;
      await _replaceSchedule(await _readTasks());
      return;
    }
    final now = _localNow();
    final day = dateKey(now);
    if (_filledDay == day) return;
    final rows = await _readTasks();
    final pending = await _plugin.pendingNotificationRequests();
    await _scheduleRecurring(
      rows,
      now,
      pending: pending.map((request) => request.id).toSet(),
    );
    _filledDay = day;
  });

  Future<void> _replaceSchedule(List<Task> rows) async {
    await init();
    await _refreshTimezone();
    _filledDay = null;
    await _plugin.cancelAllPendingNotifications();
    final now = _localNow();
    for (final task in rows.where((task) => !task.isRecurring)) {
      await _scheduleOccurrence(task);
    }
    await _scheduleRecurring(rows, now);
    _filledDay = dateKey(now);
  }

  Future<void> _scheduleRecurring(
    List<Task> rows,
    DateTime now, {
    Set<int>? pending,
  }) async {
    final from = dateKey(now);
    final to = dateKey(DateTime(now.year, now.month, now.day + 60));
    final occurrences =
        TaskDao.expandTasks(
          rows.where((task) => task.isRecurring),
          from,
          to,
        ).where(
          (task) =>
              !task.isDone && (_scheduledTime(task)?.isAfter(now) ?? false),
        );
    for (final task in occurrences.take(200)) {
      await _scheduleOccurrence(task, pending: pending);
    }
  }

  Future<void> reschedule(Task task) async {
    await schedule(task);
  }
}
