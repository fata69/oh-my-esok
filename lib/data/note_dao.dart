import 'package:sqflite/sqflite.dart';

import 'day_note.dart';
import 'task.dart';

class NoteDao {
  NoteDao(this._db);

  static const table = 'day_notes';
  final Database _db;

  static Future<void> createTable(DatabaseExecutor db) => db.execute('''
CREATE TABLE $table (
  id         TEXT PRIMARY KEY NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

  static Future<List<DayNote>> readAll(DatabaseExecutor db) async {
    final rows = await db.query(table, orderBy: 'updated_at DESC, id ASC');
    return rows.map(DayNote.fromMap).toList(growable: false);
  }

  Future<List<DayNote>> all() => readAll(_db);

  Future<void> save(DayNote note, {required bool creating}) async {
    if (note.isEmpty) throw ArgumentError('Catatan masih kosong.');
    if (creating) {
      await _db.transaction((txn) async {
        final existing = await txn.query(
          'tasks',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [note.id],
          limit: 1,
        );
        if (existing.isNotEmpty) throw StateError('Agenda sudah ada.');
        await txn.insert(table, note.toMap());
      });
      return;
    }
    final count = await _db.update(
      table,
      {'title': note.title, 'body': note.body, 'updated_at': note.updatedAt},
      where: 'id = ? AND created_at = ?',
      whereArgs: [note.id, note.createdAt],
    );
    if (count == 0) throw StateError('Catatan sudah dipindahkan atau dihapus.');
  }

  Future<void> delete(String id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Task?> schedule(DayNote note, DateTime date, String? time) async {
    if (note.isEmpty) throw ArgumentError('Catatan masih kosong.');
    return _db.transaction((txn) async {
      final removed = await txn.delete(
        table,
        where: 'id = ? AND created_at = ?',
        whereArgs: [note.id, note.createdAt],
      );
      if (removed == 0) return null;

      final task = Task(
        id: note.id,
        title: note.displayTitle,
        scheduledDate: dateKey(date),
        scheduledTime: time,
        notes: note.body.isEmpty ? null : note.body,
        isDone: false,
        createdAt: note.createdAt,
      );
      await txn.insert('tasks', task.toMap());
      return task;
    });
  }

  Future<DayNote?> unschedule(Task draft) => _db.transaction((txn) async {
    final removed = await txn.delete(
      'tasks',
      where:
          'id = ? AND scheduled_date = ? AND created_at = ? AND is_done = ? '
          'AND repeat_weekdays IS NULL AND series_id IS NULL',
      whereArgs: [
        draft.id,
        draft.scheduledDate,
        draft.createdAt,
        draft.isDone ? 1 : 0,
      ],
    );
    if (removed == 0) return null;

    final note = DayNote(
      id: draft.id,
      title: draft.title,
      body: draft.notes ?? '',
      createdAt: draft.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (note.isEmpty) throw ArgumentError('Catatan masih kosong.');
    await txn.insert(table, note.toMap());
    return note;
  });
}
