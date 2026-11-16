import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/state/day_review.dart';

import 'support/day_review_fixture.dart';

void main() {
  final source = DayReviewFixture.date;
  final target = DateTime(2026, 12, 1);

  test('review counts only the selected day and actual cash flow', () {
    final review = DayReview(
      date: source,
      tasks: [
        DayReviewFixture.task(),
        DayReviewFixture.task(id: 'done', done: true),
        DayReviewFixture.task(id: 'other-day', date: target),
      ],
      transactions: [
        DayReviewFixture.transaction('income', 100000),
        DayReviewFixture.transaction('expense', 25000),
        DayReviewFixture.transaction('expense', -5000),
        DayReviewFixture.transaction('transfer', 999999),
        DayReviewFixture.transaction('adjustment', 888888),
        DayReviewFixture.transaction('income', 777777, date: '2026-12-01'),
      ],
    );

    expect(review.tasks, hasLength(2));
    expect(review.incompleteTasks.map((task) => task.id), ['note']);
    expect(review.income, 100000);
    expect(review.expense, 20000);
  });

  test('move preserves the latest row and keeps the selected day', () async {
    final fixture = DayReviewFixture();
    addTearDown(fixture.store.dispose);
    await fixture.store.selectDate(source);
    final original = fixture.dao.rows['note']!;
    fixture.dao.rows['note'] = original.copyWith(
      title: 'Judul terbaru',
      notes: 'Teks terbaru',
      scheduledTime: '08:15',
    );
    final latest = fixture.dao.rows['note']!;

    final result = await fixture.service.reschedule(
      id: 'note',
      from: source,
      to: target,
    );

    expect(result.moved, isTrue);
    expect(result.issues, isEmpty);
    expect(fixture.dao.rows['note']!.toMap(), {
      ...latest.toMap(),
      'scheduled_date': '2026-12-01',
    });
    expect(fixture.store.selectedDate, source);
    expect(fixture.store.tasks, isEmpty);
    expect(fixture.scheduled.single.scheduledDate, '2026-12-01');
    expect(fixture.events, [
      'reconcile',
      'move',
      'reconcile',
      'reminder',
      'widget',
    ]);
    expect(fixture.dao.moveCalls, 1);
  });

  test('pending widget completion blocks a stale review move', () async {
    final fixture = DayReviewFixture();
    addTearDown(fixture.store.dispose);
    fixture.onReconcile = () async {
      await fixture.store.setDone('note', true);
    };

    final result = await fixture.service.reschedule(
      id: 'note',
      from: source,
      to: target,
    );

    expect(result.moved, isFalse);
    expect(fixture.dao.rows['note']!.isDone, isTrue);
    expect(fixture.dao.rows['note']!.scheduledDate, dateKey(source));
    expect(fixture.scheduled, isEmpty);
    expect(fixture.events, isNot(contains('widget')));
  });

  for (final state in ['completed', 'moved', 'deleted']) {
    test('a $state task cannot be moved from a stale review', () async {
      final fixture = DayReviewFixture();
      addTearDown(fixture.store.dispose);
      if (state == 'completed') {
        fixture.dao.rows['note'] = fixture.dao.rows['note']!.copyWith(
          isDone: true,
        );
      } else if (state == 'moved') {
        fixture.dao.rows['note'] = fixture.dao.rows['note']!.copyWith(
          scheduledDate: '2026-11-20',
        );
      } else {
        fixture.dao.rows.remove('note');
      }
      final before = fixture.dao.rows['note']?.toMap();

      final result = await fixture.service.reschedule(
        id: 'note',
        from: source,
        to: target,
      );

      expect(result.moved, isFalse);
      expect(fixture.dao.rows['note']?.toMap(), before);
      expect(fixture.scheduled, isEmpty);
    });
  }

  test('database failure does not change alarms or publish a widget', () async {
    final fixture = DayReviewFixture()..dao.failMove = true;
    addTearDown(fixture.store.dispose);
    final before = fixture.dao.rows['note']!.toMap();

    await expectLater(
      fixture.service.reschedule(id: 'note', from: source, to: target),
      throwsStateError,
    );

    expect(fixture.dao.rows['note']!.toMap(), before);
    expect(fixture.events, ['reconcile', 'move']);
  });

  test('a reconciliation failure prevents the database write', () async {
    final fixture = DayReviewFixture()..failReconcile = true;
    addTearDown(fixture.store.dispose);

    await expectLater(
      fixture.service.reschedule(id: 'note', from: source, to: target),
      throwsStateError,
    );
    expect(fixture.dao.moveCalls, 0);
    expect(fixture.scheduled, isEmpty);
    expect(fixture.events, isNot(contains('widget')));
  });

  test(
    'alarm failure after commit is retryable without moving again',
    () async {
      final fixture = DayReviewFixture()..failReminder = true;
      addTearDown(fixture.store.dispose);

      final result = await fixture.service.reschedule(
        id: 'note',
        from: source,
        to: target,
      );

      expect(result.moved, isTrue);
      expect(result.issues, {DayReviewIssue.reminder});
      expect(fixture.dao.rows['note']!.scheduledDate, dateKey(target));
      expect(fixture.events, contains('widget'));

      fixture.failReminder = false;
      // The retry must use this latest widget status, not the saved snapshot.
      fixture.dao.rows['note'] = fixture.dao.rows['note']!.copyWith(
        isDone: true,
      );
      final issues = await fixture.service.synchronize('note');
      expect(issues, isEmpty);
      expect(fixture.dao.moveCalls, 1);
      expect(fixture.scheduled.single.isDone, isTrue);
    },
  );

  test(
    'widget and read failures do not turn a committed move into failure',
    () async {
      final fixture = DayReviewFixture()..failWidget = true;
      addTearDown(fixture.store.dispose);
      fixture.onReconcile = () async {
        if (fixture.dao.moveCalls > 0) fixture.dao.failRead = true;
      };

      final result = await fixture.service.reschedule(
        id: 'note',
        from: source,
        to: target,
      );

      expect(result.moved, isTrue);
      expect(result.issues, {
        DayReviewIssue.reminder,
        DayReviewIssue.widget,
        DayReviewIssue.refresh,
      });
      expect(fixture.dao.moveCalls, 1);
      expect(fixture.dao.rows['note']!.scheduledDate, dateKey(target));
    },
  );

  test(
    'failed reconciliation during retry cannot overwrite widget status',
    () async {
      final fixture = DayReviewFixture()..failReconcile = true;
      addTearDown(fixture.store.dispose);

      final issues = await fixture.service.synchronize('note');

      expect(
        issues,
        containsAll([DayReviewIssue.reminder, DayReviewIssue.widget]),
      );
      expect(fixture.events, isNot(contains('widget')));
      expect(fixture.dao.moveCalls, 0);
    },
  );

  test('same-day target is rejected before a write', () async {
    final fixture = DayReviewFixture();
    addTearDown(fixture.store.dispose);

    await expectLater(
      fixture.service.reschedule(
        id: 'note',
        from: source,
        to: DateTime(source.year, source.month, source.day, 23),
      ),
      throwsArgumentError,
    );

    expect(fixture.dao.moveCalls, 0);
    expect(fixture.events, isNot(contains('widget')));
  });
}
