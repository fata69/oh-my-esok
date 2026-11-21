import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/notify/reminder_alarm.dart';
import 'package:jadwal/state/task_store.dart';

import 'support/day_review_fixture.dart';

void main() {
  final start = DateTime(2026, 11, 23, 8);
  const recurring = Task(
    id: 'weekday-reminder',
    title: 'Absen',
    scheduledDate: '2026-11-23',
    scheduledTime: '08:00',
    isDone: false,
    createdAt: 1,
    repeatWeekdays: [1, 2, 3, 4, 5],
  );

  List<Map<String, Object?>> alarms(Task task, DateTime now) =>
      agendaReminderAlarms(
        task,
        now: now,
        when: task.scheduledDateTime,
        channel: 'esok_reminders_coin',
        sound: 'coin',
        leadMinutes: 15,
      );

  test('completed occurrence retains two distinct slots for widget undo', () {
    final monday = recurring.occurrenceOn('2026-11-23');
    final tuesday = recurring.occurrenceOn('2026-11-24');
    final now = start.subtract(const Duration(hours: 2));
    final completed = alarms(monday.copyWith(isDone: true), now);
    final unfinished = alarms(tuesday, now);
    expect(completed.map((slot) => slot['slot']), [1, 2]);
    expect(completed.map((slot) => slot['taskId']).toSet(), {monday.id});
    expect(completed.map((slot) => slot['done']), [true, true]);
    expect(unfinished.map((slot) => slot['taskId']).toSet(), {tuesday.id});
    expect(unfinished.map((slot) => slot['done']), [false, false]);
  });

  test('undo never replays an expired lead or appointment', () {
    final monday = recurring.occurrenceOn('2026-11-23');
    final before = alarms(monday, start.subtract(const Duration(minutes: 1)));
    expect(before.map((slot) => slot['slot']), [1]);
    expect(before.single['when'], start.millisecondsSinceEpoch);
    expect(alarms(monday, start), isEmpty);
    expect(alarms(monday.copyWith(clearTime: true), start), isEmpty);
  });

  test(
    'a second tap from stale widget state cannot accidentally undo',
    () async {
      final rendered = recurring.occurrenceOn('2026-11-23');
      final dao = MemoryTaskDao([rendered], []);
      final store = TaskStore(dao);
      addTearDown(store.dispose);
      final completed = await store.setCompletion(rendered, true);
      expect(completed?.isDone, isTrue);
      expect(await store.setCompletion(rendered, true), isNull);
      expect((await store.taskById(rendered.id))?.isDone, isTrue);
      expect((await store.setCompletion(completed!, false))?.isDone, isFalse);
    },
  );
}
