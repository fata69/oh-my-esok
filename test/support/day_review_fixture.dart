import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/data/task_dao.dart';
import 'package:jadwal/state/day_review.dart';
import 'package:jadwal/state/task_store.dart';

class MemoryTaskDao implements TaskDao {
  MemoryTaskDao(Iterable<Task> tasks, this.events)
    : rows = {for (final task in tasks) task.id: task};

  final Map<String, Task> rows;
  final List<String> events;
  bool failRead = false;
  bool failMove = false;
  int moveCalls = 0;

  @override
  Future<Task?> byId(String id) async {
    if (failRead) throw StateError('read failed');
    return rows[id];
  }

  @override
  Future<List<Task>> forDate(String day) async {
    if (failRead) throw StateError('read failed');
    return rows.values.where((task) => task.scheduledDate == day).toList();
  }

  @override
  Future<String?> earliestDate() async {
    if (failRead) throw StateError('read failed');
    final dates = rows.values.map((task) => task.scheduledDate).toList()
      ..sort();
    return dates.firstOrNull;
  }

  @override
  Future<Map<String, int>> countsBetween(String from, String to) async {
    if (failRead) throw StateError('read failed');
    final counts = <String, int>{};
    for (final task in rows.values) {
      final date = task.scheduledDate;
      if (date.compareTo(from) >= 0 && date.compareTo(to) <= 0) {
        counts[date] = (counts[date] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<void> setDone(String id, bool done) async {
    final task = rows[id];
    if (task != null) rows[id] = task.copyWith(isDone: done);
  }

  @override
  Future<Task?> rescheduleIncomplete({
    required String id,
    required String from,
    required String to,
  }) async {
    moveCalls++;
    events.add('move');
    if (failMove) throw StateError('write failed');
    final task = rows[id];
    if (task == null || task.isDone || task.scheduledDate != from) return null;
    return rows[id] = task.copyWith(scheduledDate: to);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DayReviewFixture {
  DayReviewFixture({List<Task>? tasks, List<MoneyTransaction>? transactions}) {
    dao = MemoryTaskDao(tasks ?? [task()], events);
    store = TaskStore(dao);
    this.transactions = transactions ?? [];
    service = DayReviewService(
      tasks: store,
      transactionsForDate: (_) async => this.transactions,
      reconcileWidget: () async {
        events.add('reconcile');
        if (failReconcile) throw StateError('widget queue unavailable');
        await onReconcile?.call();
      },
      rescheduleReminder: (task) async {
        events.add('reminder');
        if (failReminder) throw StateError('alarm unavailable');
        scheduled.add(task);
      },
      pushWidget: () async {
        events.add('widget');
        if (failWidget) throw StateError('widget unavailable');
      },
    );
  }

  final events = <String>[];
  final scheduled = <Task>[];
  late final MemoryTaskDao dao;
  late final TaskStore store;
  late final DayReviewService service;
  late List<MoneyTransaction> transactions;
  Future<void> Function()? onReconcile;
  bool failReconcile = false;
  bool failReminder = false;
  bool failWidget = false;

  static final date = DateTime(2026, 11, 15);

  static Task task({
    String id = 'note',
    String title = 'Bayar listrik',
    DateTime? date,
    bool done = false,
    String? time = '19:30',
  }) => Task(
    id: id,
    title: title,
    scheduledDate: dateKey(date ?? DayReviewFixture.date),
    scheduledTime: time,
    notes: 'Cek meter sebelum membeli token',
    isDone: done,
    createdAt: 123,
  );

  static MoneyTransaction transaction(
    String kind,
    int amount, {
    String date = '2026-11-15',
  }) => MoneyTransaction(
    id: '$kind-$amount-$date',
    amount: amount,
    kind: kind,
    accountId: 'cash',
    toAccountId: kind == 'transfer' ? 'bank' : null,
    date: date,
    createdAt: 1,
  );
}
