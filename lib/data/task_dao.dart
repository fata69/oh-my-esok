import 'package:sqflite/sqflite.dart';

import 'task.dart';

class TaskDao {
  TaskDao(this._db);

  final Database _db;

  Future<List<Task>> forDate(String day) async {
    return expandTasks(await _rangeRows(day, day), day, day);
  }

  // Include moved overrides, even if their effective date is outside the range.
  Future<List<Task>> _rangeRows(
    String from,
    String to, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? _db).query(
      'tasks',
      where:
          'scheduled_date BETWEEN ? AND ? OR series_id IS NOT NULL '
          'OR repeat_weekdays IS NOT NULL',
      whereArgs: [from, to],
    );
    return rows.map(Task.fromMap).toList();
  }

  static List<Task> expandTasks(Iterable<Task> rows, String from, String to) {
    final overrides = <String>{};
    final rules = rows.where((task) => task.isRepeatRule).toList();
    final result = <Task>[];
    for (final task in rows.where((task) => !task.isRepeatRule)) {
      if (task.isOccurrence) {
        overrides.add(task.id);
        final visible = _visibleOccurrence(task, rules);
        if (!visible) continue;
        if (task.scheduledDate != task.occurrenceDay) {
          overrides.add(
            Task.occurrenceId(task.recurrenceId, task.scheduledDate),
          );
        }
      }
      if (!task.isSkipped &&
          task.scheduledDate.compareTo(from) >= 0 &&
          task.scheduledDate.compareTo(to) <= 0) {
        result.add(task);
      }
    }
    for (final rule in rules) {
      var date = DateTime.parse(
        rule.scheduledDate.compareTo(from) > 0 ? rule.scheduledDate : from,
      );
      for (
        var day = dateKey(date);
        day.compareTo(to) <= 0 &&
            (rule.repeatUntil == null || day.compareTo(rule.repeatUntil!) < 0);
        day = dateKey(date)
      ) {
        if (rule.repeatsOn(day)) {
          final task = rule.occurrenceOn(day);
          if (overrides.add(task.id)) result.add(task);
        }
        date = DateTime(date.year, date.month, date.day + 1);
      }
    }
    return result..sort((a, b) {
      final date = a.scheduledDate.compareTo(b.scheduledDate);
      if (date != 0) return date;
      final created = a.createdAt.compareTo(b.createdAt);
      return created != 0 ? created : a.id.compareTo(b.id);
    });
  }

  Future<Task?> byId(String id) => _byId(_db, id);

  static bool _visibleOccurrence(Task task, Iterable<Task> rules) {
    if (task.isDone) return true;
    final lineage = rules.where(
      (rule) => rule.recurrenceId == task.recurrenceId,
    );
    return lineage.any((rule) => rule.repeatsOn(task.occurrenceDay)) &&
        lineage.any((rule) => rule.coversRepeatDate(task.scheduledDate));
  }

  Future<List<Task>> _seriesRules(DatabaseExecutor db, String series) async {
    final rows = await db.query(
      'tasks',
      where: 'id = ? OR (series_id = ? AND id NOT LIKE ?)',
      whereArgs: [series, series, 'occ:%'],
      orderBy: 'scheduled_date DESC',
    );
    return rows.map(Task.fromMap).where((task) => task.isRepeatRule).toList();
  }

  Future<Task?> _byId(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final task = Task.fromMap(rows.first);
      if (task.isSkipped) return null;
      if (task.isOccurrence &&
          !task.isDone &&
          !_visibleOccurrence(
            task,
            await _seriesRules(db, task.recurrenceId),
          )) {
        return null;
      }
      return task;
    }
    final match = RegExp(r'^occ:(.+):(\d{4}-\d{2}-\d{2})$').firstMatch(id);
    if (match == null) return null;
    final series = match[1]!;
    final day = match[2]!;
    if (DateTime.tryParse(day) == null) return null;
    final rules = await _seriesRules(db, series);
    final onTarget = await db.query(
      'tasks',
      where: 'series_id = ? AND scheduled_date = ? AND id LIKE ?',
      whereArgs: [series, day, 'occ:%'],
    );
    if (onTarget
        .map(Task.fromMap)
        .any((task) => _visibleOccurrence(task, rules))) {
      return null;
    }
    for (final rule in rules) {
      if (rule.repeatsOn(day)) return rule.occurrenceOn(day);
    }
    return null;
  }

  Future<String?> earliestDate() async {
    final rows = await _db.rawQuery(
      'SELECT MIN(scheduled_date) AS d FROM tasks',
    );
    return rows.first['d'] as String?;
  }

  Future<Map<String, int>> countsBetween(String from, String to) async {
    final recurring = await _db.query(
      'tasks',
      columns: ['id'],
      where: 'repeat_weekdays IS NOT NULL OR series_id IS NOT NULL',
      limit: 1,
    );
    if (recurring.isNotEmpty) {
      final counts = <String, int>{};
      for (final task in expandTasks(await _rangeRows(from, to), from, to)) {
        counts.update(
          task.scheduledDate,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      return counts;
    }
    final rows = await _db.rawQuery(
      'SELECT scheduled_date AS d, COUNT(*) AS c FROM tasks '
      'WHERE scheduled_date BETWEEN ? AND ? GROUP BY scheduled_date',
      [from, to],
    );
    final result = <String, int>{};
    for (final row in rows) {
      result[row['d'] as String] = row['c'] as int;
    }
    return result;
  }

  Future<void> insert(Task task) async {
    await _db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Task task) async {
    if (task.isOccurrence) {
      await updateOccurrence(task, task, following: false);
      return;
    }
    await _db.update(
      'tasks',
      {
        ...task.toMap(),
        'repeat_weekdays': task.isRecurring
            ? task.repeatWeekdays.join(',')
            : null,
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Move only the date of an incomplete task that is still on [from].
  /// The conditional write and returned snapshot share a transaction so a
  /// stale review never overwrites newer text, time or completion status.
  Future<Task?> rescheduleIncomplete({
    required String id,
    required String from,
    required String to,
  }) {
    return _db.transaction((txn) async {
      final changed = await txn.update(
        'tasks',
        {'scheduled_date': to},
        where:
            'id = ? AND scheduled_date = ? AND is_done = 0 '
            'AND series_id IS NULL AND repeat_weekdays IS NULL',
        whereArgs: [id, from],
      );
      if (changed == 0) return null;

      final rows = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Task.fromMap(rows.single);
    });
  }

  Future<void> setDone(String id, bool done) async {
    if (id.startsWith('occ:')) {
      await _db.transaction((txn) async {
        final task = await _byId(txn, id);
        if (task == null || task.isDone == done) return;
        if (task.isOccurrence) {
          await _saveOccurrence(txn, task, task, done: done);
        } else {
          await txn.update(
            'tasks',
            {'is_done': done ? 1 : 0},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
      return;
    }
    await _db.update(
      'tasks',
      {'is_done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    if (id.startsWith('occ:')) {
      await _db.transaction((txn) async {
        final task = await _byId(txn, id);
        if (task == null) return;
        if (task.isOccurrence) {
          await _saveOccurrence(txn, task, task, skipped: true);
        } else {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
        }
      });
      return;
    }
    await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _saveOccurrence(
    DatabaseExecutor db,
    Task current,
    Task updated, {
    bool? done,
    bool skipped = false,
  }) async {
    await db.insert('tasks', {
      ...updated.toMap(),
      'id': current.id,
      'series_id': current.recurrenceId,
      'repeat_weekdays': current.repeatWeekdays.join(','),
      'repeat_until': null,
      'is_done': (done ?? current.isDone) ? 1 : 0,
      // A generated occurrence has no prior row to restore on undo.
      'is_skipped': skipped ? (current.isProjected ? 2 : 1) : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> undoSkipOccurrence(Task task) async {
    if (!task.isOccurrence) return;
    await _db.transaction((txn) async {
      await txn.delete(
        'tasks',
        where: 'id = ? AND series_id = ? AND is_skipped = 2',
        whereArgs: [task.id, task.recurrenceId],
      );
      await txn.update(
        'tasks',
        {'is_skipped': 0},
        where: 'id = ? AND series_id = ? AND is_skipped = 1',
        whereArgs: [task.id, task.recurrenceId],
      );
    });
  }

  Future<void> updateOccurrence(
    Task original,
    Task updated, {
    required bool following,
  }) => _db.transaction((txn) async {
    final current = await _byId(txn, original.id);
    if (current == null || !current.isOccurrence) return;
    if (!following) {
      final target = updated.scheduledDate;
      if (target != current.scheduledDate) {
        final rows = await _rangeRows(target, target, executor: txn);
        if (expandTasks(rows, target, target).any(
          (task) =>
              task.recurrenceId == current.recurrenceId &&
              task.id != current.id,
        )) {
          throw ArgumentError('Seri ini sudah punya agenda pada tanggal itu.');
        }
      }
      await _saveOccurrence(txn, current, updated);
      return;
    }
    final day = current.occurrenceDay;
    final series = current.recurrenceId;
    if (updated.scheduledDate.compareTo(day) < 0) {
      throw ArgumentError(
        'Tanggal mulai seri tidak boleh sebelum kejadian ini.',
      );
    }
    final ruleFilter = '(id = ? OR (series_id = ? AND id NOT LIKE ?))';
    final ruleArgs = [series, series, 'occ:%'];
    await txn.update(
      'tasks',
      {'repeat_until': day},
      where:
          '$ruleFilter AND scheduled_date < ? '
          'AND (repeat_until IS NULL OR repeat_until > ?)',
      whereArgs: [...ruleArgs, day, day],
    );
    // Keep the original rule as a reference even when the first day is edited.
    await txn.update(
      'tasks',
      {'repeat_until': day},
      where: 'id = ? AND scheduled_date >= ?',
      whereArgs: [series, day],
    );
    await txn.delete(
      'tasks',
      where: 'series_id = ? AND id NOT LIKE ? AND scheduled_date >= ?',
      whereArgs: [series, 'occ:%', day],
    );
    final start = updated.scheduledDate;
    final weekdays = updated.repeatWeekdays;
    if (weekdays.isEmpty) {
      await txn.insert('tasks', {
        ...updated.toMap(),
        'id': current.id,
        'series_id': null,
        'repeat_weekdays': null,
        'repeat_until': null,
        'is_skipped': 0,
        'is_done': current.isDone ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    await txn.insert('tasks', {
      ...updated.toMap(),
      'id': 'rule:$series:$start',
      'series_id': series,
      'repeat_weekdays': weekdays.join(','),
      'repeat_until': null,
      'is_skipped': 0,
      'is_done': 0,
    });
    // If this date already had a saved completion or override, keep its status
    // and apply the user's edits to that occurrence too.
    if (start == day) {
      final existing = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [current.id],
      );
      if (existing.isNotEmpty) await _saveOccurrence(txn, current, updated);
    }
  });

  Future<List<Task>> all() => readAll(_db);

  static Future<List<Task>> readAll(DatabaseExecutor db) async {
    final rows = await db.query('tasks', orderBy: 'scheduled_date DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<int> countAll() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM tasks');
    return rows.first['c'] as int? ?? 0;
  }

  Future<void> deleteAll() async {
    await _db.delete('tasks');
  }
}
