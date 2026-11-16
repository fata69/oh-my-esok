import 'package:sqflite/sqflite.dart';

import 'task.dart';

class TaskDao {
  TaskDao(this._db);

  final Database _db;

  Future<List<Task>> forDate(String day) async {
    final rows = await _db.query(
      'tasks',
      where: 'scheduled_date = ?',
      whereArgs: [day],
      orderBy: 'created_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> byId(String id) async {
    final rows = await _db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<String?> earliestDate() async {
    final rows = await _db.rawQuery(
      'SELECT MIN(scheduled_date) AS d FROM tasks',
    );
    return rows.first['d'] as String?;
  }

  Future<Map<String, int>> countsBetween(String from, String to) async {
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
    await _db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> setDone(String id, bool done) async {
    await _db.update(
      'tasks',
      {'is_done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> all() async {
    final rows = await _db.query('tasks', orderBy: 'scheduled_date DESC');
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
