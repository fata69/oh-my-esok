import 'package:flutter/foundation.dart';

import '../data/money_transaction.dart';
import '../data/task.dart';
import 'task_store.dart';

class DayReview {
  DayReview({
    required DateTime date,
    required List<Task> tasks,
    required List<MoneyTransaction> transactions,
  }) : date = dateOnly(date),
       tasks = List.unmodifiable(
         tasks.where((task) => task.scheduledDate == dateKey(date)),
       ),
       transactions = List.unmodifiable(
         transactions.where((entry) => entry.date == dateKey(date)),
       );

  final DateTime date;
  final List<Task> tasks;
  final List<MoneyTransaction> transactions;

  List<Task> get incompleteTasks =>
      tasks.where((task) => !task.isDone).toList(growable: false);

  int get income => transactions
      .where((entry) => entry.isIncome)
      .fold(0, (total, entry) => total + entry.amount);

  int get expense => transactions
      .where((entry) => entry.isExpense)
      .fold(0, (total, entry) => total + entry.amount);
}

enum DayReviewIssue { reminder, widget, refresh }

class DayMoveResult {
  const DayMoveResult({required this.task, required this.issues});

  // null means that the task was completed, deleted or moved in the meantime.
  final Task? task;
  final Set<DayReviewIssue> issues;

  bool get moved => task != null;
}

/// Orchestrates the commit separately from fallible platform updates.
/// Callbacks keep the workflow testable without notification or widget plugins.
class DayReviewService {
  DayReviewService({
    required TaskStore tasks,
    required this.transactionsForDate,
    required this.reconcileWidget,
    required this.rescheduleReminder,
    required this.pushWidget,
  }) : _tasks = tasks;

  final TaskStore _tasks;
  final Future<List<MoneyTransaction>> Function(DateTime) transactionsForDate;
  final Future<void> Function() reconcileWidget;
  final Future<void> Function(Task) rescheduleReminder;
  final Future<void> Function() pushWidget;

  Future<DayReview> load(DateTime date) async {
    await reconcileWidget();
    final tasks = await _tasks.tasksFor(date);
    final transactions = await transactionsForDate(date);
    return DayReview(date: date, tasks: tasks, transactions: transactions);
  }

  Future<DayMoveResult> reschedule({
    required String id,
    required DateTime from,
    required DateTime to,
  }) async {
    // Apply pending widget checkmarks before the conditional database write.
    await reconcileWidget();
    final moved = await _tasks.rescheduleIncomplete(id: id, from: from, to: to);
    if (moved == null) {
      final issues = <DayReviewIssue>{};
      await _refresh(issues);
      return DayMoveResult(task: null, issues: Set.unmodifiable(issues));
    }

    return DayMoveResult(task: moved, issues: await synchronize(moved.id));
  }

  /// Retry only the effects of a committed move, never the date write itself.
  Future<Set<DayReviewIssue>> synchronize(String id) async {
    final issues = <DayReviewIssue>{};
    var reconciled = false;
    try {
      await reconcileWidget();
      reconciled = true;
      // Re-read after reconciliation; a widget may have completed the task.
      final current = await _tasks.taskById(id);
      if (current != null) await rescheduleReminder(current);
    } catch (error, stack) {
      debugPrint('Day review reminder update failed: $error\n$stack');
      issues.add(DayReviewIssue.reminder);
    }
    if (reconciled) {
      try {
        await pushWidget();
      } catch (error, stack) {
        debugPrint('Day review widget update failed: $error\n$stack');
        issues.add(DayReviewIssue.widget);
      }
    } else {
      // Don't overwrite a widget snapshot when pending checkmarks are unknown.
      issues.add(DayReviewIssue.widget);
    }
    await _refresh(issues);
    return Set.unmodifiable(issues);
  }

  Future<void> _refresh(Set<DayReviewIssue> issues) async {
    try {
      await _tasks.refresh();
      await _tasks.loadMonth(_tasks.selectedDate);
    } catch (error, stack) {
      debugPrint('Day review refresh failed: $error\n$stack');
      issues.add(DayReviewIssue.refresh);
    }
  }
}
