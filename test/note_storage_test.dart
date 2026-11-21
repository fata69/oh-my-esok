import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/day_note.dart';
import 'package:jadwal/data/note_dao.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'note and agenda conversions reuse ID and move inside a transaction',
    () async {
      databaseFactory = databaseFactorySqflitePlugin;
      addTearDown(() => databaseFactory = null);
      const channel = MethodChannel('com.tekartik.sqflite');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final writes = <(String, Map<Object?, Object?>)>[];
      var notePresent = true;
      var agendaPresent = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openDatabase') return 1;
        if (call.method == 'closeDatabase') return null;
        final arguments = call.arguments as Map<Object?, Object?>;
        final sql = arguments['sql'] as String;
        writes.add((sql, arguments));
        if (call.method == 'execute') {
          return sql.startsWith('BEGIN') ? {'transactionId': 17} : null;
        }
        if (sql.startsWith('DELETE FROM day_notes')) {
          final changed = notePresent;
          notePresent = false;
          return changed ? 1 : 0;
        }
        if (sql.startsWith('DELETE FROM tasks')) {
          final changed = agendaPresent;
          agendaPresent = false;
          return changed ? 1 : 0;
        }
        if (sql.startsWith('INSERT INTO tasks')) {
          expect(notePresent, isFalse);
          agendaPresent = true;
          return 1;
        }
        if (sql.startsWith('INSERT INTO day_notes')) {
          expect(agendaPresent, isFalse);
          notePresent = true;
          return 1;
        }
        throw StateError('Unexpected SQLite method: ${call.method} $sql');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final database = await openDatabase(inMemoryDatabasePath);
      addTearDown(database.close);
      final dao = NoteDao(database);
      const note = DayNote(
        id: 'note-1',
        title: 'Ambil paket',
        body: 'Bawa identitas.',
        createdAt: 1,
        updatedAt: 2,
      );
      final day = DateTime(2026, 11, 19);

      final task = (await dao.schedule(note, day, '09:30'))!;
      expect(task.id, note.id);
      expect(task.title, note.title);
      expect(task.notes, note.body);
      expect(task.createdAt, note.createdAt);
      expect(task.scheduledDate, '2026-11-19');
      expect(task.scheduledTime, '09:30');
      expect(await dao.schedule(note, day, '09:30'), isNull);

      final draft = task.copyWith(
        title: 'Ambil paket kantor',
        notes: 'Bawa PIN.',
      );
      final restored = (await dao.unschedule(draft))!;
      expect(restored.id, note.id);
      expect(restored.title, draft.title);
      expect(restored.body, draft.notes);
      expect(restored.createdAt, note.createdAt);
      expect(await dao.unschedule(draft), isNull);

      final mutations = writes.where(
        (write) =>
            write.$1.startsWith('INSERT') || write.$1.startsWith('DELETE'),
      );
      expect(mutations.map((write) => write.$1.split(' ').take(3).join(' ')), [
        'DELETE FROM day_notes',
        'INSERT INTO tasks',
        'DELETE FROM day_notes',
        'DELETE FROM tasks',
        'INSERT INTO day_notes',
        'DELETE FROM tasks',
      ]);
      expect(
        mutations.map((write) => write.$2['transactionId']),
        everyElement(17),
      );
      expect(
        writes
            .firstWhere((write) => write.$1.startsWith('DELETE FROM tasks'))
            .$1,
        contains('repeat_weekdays IS NULL AND series_id IS NULL'),
      );
    },
  );
}
