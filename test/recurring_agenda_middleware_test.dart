import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/backup/backup_service.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/data/task_dao.dart';

const rule = Task(
  id: 'absen',
  title: 'Absen',
  scheduledDate: '2026-11-16',
  scheduledTime: '08:00',
  isDone: false,
  createdAt: 1,
  repeatWeekdays: [1, 2, 3, 4, 5],
);

const skippedTuesday = Task(
  id: 'occ:absen:2026-11-17',
  seriesId: 'absen',
  title: 'Absen',
  scheduledDate: '2026-11-17',
  scheduledTime: '08:00',
  isDone: false,
  isSkipped: true,
  createdAt: 1,
  repeatWeekdays: [1, 2, 3, 4, 5],
);

Future<BackupData> roundTrip(List<Task> tasks) {
  final json = BackupService.toJsonMap(
    BackupData(tasks: tasks, categories: [], accounts: [], transactions: []),
  );
  return BackupService.parseJsonBytes(
    Uint8List.fromList(utf8.encode(jsonEncode(json))),
  );
}

void main() {
  test('backup distinguishes generated skips from saved exceptions', () async {
    final virtual = rule.occurrenceOn('2026-11-18');
    expect(virtual.isProjected, isTrue);
    final generatedSkip = Task.fromMap({...virtual.toMap(), 'is_skipped': 2});
    final data = await roundTrip([rule, generatedSkip, skippedTuesday]);
    expect(data.tasks[1].toMap()['is_skipped'], 2);
    expect(data.tasks[2].toMap()['is_skipped'], 1);
    expect(
      TaskDao.expandTasks(data.tasks, '2026-11-17', '2026-11-18'),
      isEmpty,
    );
  });

  test(
    'weekday projection preserves completion and skip through backup',
    () async {
      final monday = rule.occurrenceOn('2026-11-16').copyWith(isDone: true);
      final data = await roundTrip([rule, monday, skippedTuesday]);
      final tasks = TaskDao.expandTasks(data.tasks, '2026-11-16', '2026-11-23');
      expect(tasks.map((task) => task.scheduledDate), [
        '2026-11-16',
        '2026-11-18',
        '2026-11-19',
        '2026-11-20',
        '2026-11-23',
      ]);
      expect(tasks.first.id, monday.id);
      expect(tasks.where((task) => task.isDone).single.id, monday.id);
      expect(tasks.last.scheduledTime, '08:00');
    },
  );

  test('rule split retains old dates and stable occurrence identifiers', () {
    final old = Task.fromMap({...rule.toMap(), 'repeat_until': '2026-11-18'});
    final changed = Task.fromMap({
      ...rule.toMap(),
      'id': 'rule:absen:2026-11-18',
      'series_id': 'absen',
      'scheduled_date': '2026-11-18',
      'scheduled_time': '09:00',
      'repeat_weekdays': '3',
    });
    final tasks = TaskDao.expandTasks(
      [old, changed],
      '2026-11-16',
      '2026-11-25',
    );
    expect(tasks.map((task) => task.id), [
      'occ:absen:2026-11-16',
      'occ:absen:2026-11-17',
      'occ:absen:2026-11-18',
      'occ:absen:2026-11-25',
    ]);
    expect(tasks.map((task) => task.scheduledTime), [
      '08:00',
      '08:00',
      '09:00',
      '09:00',
    ]);
  });

  test('moved override occupies its effective date only once', () {
    final moved = rule
        .occurrenceOn('2026-11-16')
        .copyWith(scheduledDate: '2026-11-17');
    final tasks = TaskDao.expandTasks(
      [rule, moved],
      '2026-11-16',
      '2026-11-18',
    );
    expect(tasks.map((task) => task.id), [moved.id, 'occ:absen:2026-11-18']);
    expect(tasks.first.scheduledDate, '2026-11-17');
  });

  test('stopping a series keeps one event and completed history', () async {
    final ended = Task.fromMap({...rule.toMap(), 'repeat_until': '2026-11-18'});
    final remaining = Task.fromMap({
      ...rule.occurrenceOn('2026-11-18').toMap(),
      'series_id': null,
      'repeat_weekdays': null,
    });
    final unfinished = rule
        .occurrenceOn('2026-11-19')
        .copyWith(title: 'Edit satu tanggal');
    final finished = rule.occurrenceOn('2026-11-20').copyWith(isDone: true);
    final data = await roundTrip([
      ended,
      remaining,
      unfinished,
      finished,
      skippedTuesday,
    ]);
    final tasks = TaskDao.expandTasks(data.tasks, '2026-11-16', '2026-11-24');
    expect(tasks.map((task) => task.id), [
      rule.occurrenceOn('2026-11-16').id,
      remaining.id,
      finished.id,
    ]);
    expect(tasks[1].isRecurring, isFalse);
    expect(tasks.last.isDone, isTrue);
    expect(data.tasks.any((task) => task.id == unfinished.id), isTrue);
  });

  test(
    'exceptions survive only on days still included by the changed rule',
    () {
      final ended = Task.fromMap({
        ...rule.toMap(),
        'repeat_until': '2026-11-18',
      });
      final changed = Task.fromMap({
        ...rule.toMap(),
        'id': 'rule:absen:2026-11-18',
        'series_id': 'absen',
        'scheduled_date': '2026-11-18',
        'repeat_weekdays': '3',
      });
      final thursday = rule.occurrenceOn('2026-11-19').copyWith(title: 'Kamis');
      final wednesday = rule.occurrenceOn('2026-11-25').copyWith(title: 'Rabu');
      final tasks = TaskDao.expandTasks(
        [ended, changed, thursday, wednesday],
        '2026-11-18',
        '2026-11-25',
      );
      expect(tasks.map((task) => task.title), ['Absen', 'Rabu']);
    },
  );

  test('v5 task restores as a single calendar event', () async {
    final data = await roundTrip([
      rule.copyWith(repeatWeekdays: const [], isDone: true),
    ]);
    final task = data.tasks.single;
    expect(task.isRecurring, isFalse);
    expect(task.isDone, isTrue);
    expect(task.scheduledTime, '08:00');
    expect(
      TaskDao.expandTasks(data.tasks, '2026-11-17', '2026-11-23'),
      isEmpty,
    );
  });
}
