import 'package:flutter/foundation.dart';

import '../data/day_note.dart';
import '../data/note_dao.dart';
import '../data/task.dart';
import '../data/task_dao.dart';

class TaskStore extends ChangeNotifier {
  TaskStore(this._dao, {this._noteDao});

  final TaskDao _dao;
  final NoteDao? _noteDao;
  List<DayNote> _notes = const [];
  int _noteReadVersion = 0;

  DateTime _selectedDate = today();
  List<Task> _tasks = const [];
  List<Task> _nextDayTasks = const [];
  Map<String, int> _monthCounts = const {};
  String? _earliestRecorded;
  bool _loaded = false;
  int _revision = 0;
  DateTime _countsMonth = DateTime(today().year, today().month);

  int get revision => _revision;

  DateTime get selectedDate => _selectedDate;
  List<Task> get tasks => _tasks;
  List<Task> get nextDayTasks => _nextDayTasks;
  List<DayNote> get notes => _notes;
  Map<String, int> get monthCounts => _monthCounts;
  bool get isLoaded => _loaded;
  bool get isToday => _selectedDate == today();

  int get doneCount => _tasks.where((t) => t.isDone).length;
  int get undoneCount => _tasks.length - doneCount;

  int countFor(DateTime date) => _monthCounts[dateKey(date)] ?? 0;

  DateTime get _sevenDaysBack => today().subtract(const Duration(days: 7));

  DateTime get earliestAllowedDate {
    final recorded = _earliestRecorded == null
        ? null
        : DateTime.tryParse(_earliestRecorded!);
    if (recorded == null) return _sevenDaysBack;
    final recordedDay = dateOnly(recorded);
    return recordedDay.isBefore(_sevenDaysBack) ? recordedDay : _sevenDaysBack;
  }

  bool get canGoPrevious => _selectedDate.isAfter(earliestAllowedDate);
  bool get isAtEarliest => !canGoPrevious;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh({bool includeNotes = true}) async {
    final day = dateKey(_selectedDate);
    final next = dateKey(_selectedDate.add(const Duration(days: 1)));
    final results = await Future.wait([
      _dao.forDate(day),
      _dao.forDate(next),
      _dao.earliestDate(),
      if (includeNotes) _reloadNotes(),
    ]);
    _tasks = results[0] as List<Task>;
    _nextDayTasks = results[1] as List<Task>;
    _earliestRecorded = results[2] as String?;
    _loaded = true;
    _revision++;
    notifyListeners();
  }

  Future<List<Task>> tasksFor(DateTime date) => _dao.forDate(dateKey(date));

  Future<void> selectDate(DateTime date) async {
    final normalized = dateOnly(date);
    if (normalized == _selectedDate) return;
    _selectedDate = normalized;
    await refresh(includeNotes: false);
    await ensureMonthLoaded(normalized);
  }

  Future<void> ensureMonthLoaded(DateTime month) async {
    final first = DateTime(month.year, month.month);
    if (first.year == _countsMonth.year &&
        first.month == _countsMonth.month &&
        _monthCounts.isNotEmpty) {
      return;
    }
    await loadMonth(first);
  }

  Future<void> loadMonth(DateTime month) async {
    _countsMonth = DateTime(month.year, month.month);
    final start = DateTime(
      month.year,
      month.month,
    ).subtract(const Duration(days: 7));
    final end = DateTime(
      month.year,
      month.month + 1,
    ).add(const Duration(days: 14));
    _monthCounts = await _dao.countsBetween(dateKey(start), dateKey(end));
    notifyListeners();
  }

  Future<Task?> taskById(String id) => _dao.byId(id);

  NoteDao get _noteStorage =>
      _noteDao ?? (throw StateError('Penyimpanan catatan belum tersedia.'));

  Future<void> _reloadNotes() async {
    final dao = _noteDao;
    if (dao == null) return;
    final version = ++_noteReadVersion;
    final notes = await dao.all();
    if (version == _noteReadVersion) _notes = List.unmodifiable(notes);
  }

  Future<void> saveNote(DayNote note, {bool creating = false}) async {
    await _noteStorage.save(note, creating: creating);
    await _refreshAfterNoteCommit(note.id, note);
  }

  Future<void> deleteNote(String id) async {
    await _noteStorage.delete(id);
    await _refreshAfterNoteCommit(id, null);
  }

  Future<Task?> scheduleNote(
    DayNote note, {
    required DateTime date,
    String? time,
  }) async {
    final task = await _noteStorage.schedule(note, date, time);
    if (task != null) {
      await _refreshAfterNoteCommit(note.id, null, agendaChanged: true);
    }
    return task;
  }

  Future<DayNote?> unscheduleTask(Task draft) async {
    final note = await _noteStorage.unschedule(draft);
    if (note != null) {
      await _refreshAfterNoteCommit(note.id, note, agendaChanged: true);
    }
    return note;
  }

  Future<void> _refreshAfterNoteCommit(
    String id,
    DayNote? note, {
    bool agendaChanged = false,
  }) async {
    // Keep the committed result visible even if a subsequent IO read fails.
    _noteReadVersion++;
    _notes = List.unmodifiable([
      ?note,
      ..._notes.where((existing) => existing.id != id),
    ]);
    try {
      if (agendaChanged) {
        await refresh();
        await loadMonth(_selectedDate);
      } else {
        await _reloadNotes();
        notifyListeners();
      }
    } catch (error, stack) {
      debugPrint('Note committed, cache refresh failed: $error\n$stack');
      if (agendaChanged) _revision++;
      notifyListeners();
    }
  }

  Future<void> add(Task task) async {
    await _dao.insert(task);
    await refresh();
    await loadMonth(_selectedDate);
  }

  Future<void> update(Task task) async {
    await _dao.update(task);
    _selectedDate = dateOnly(task.date);
    await refresh();
    await loadMonth(_selectedDate);
  }

  Future<void> updateOccurrence(
    Task original,
    Task updated, {
    required bool following,
  }) async {
    if (original.isOccurrence) {
      await _dao.updateOccurrence(original, updated, following: following);
      await refresh();
      await loadMonth(_selectedDate);
    } else {
      await update(updated);
    }
  }

  Future<void> skipOccurrence(Task task) => delete(task.id);

  Future<void> undoSkipOccurrence(Task task) async {
    await _dao.undoSkipOccurrence(task);
    await refresh();
    await loadMonth(_selectedDate);
  }

  /// Return the committed row before refreshing caches or platform effects.
  /// A later refresh failure must not be reported as a failed database write.
  /// The review service refreshes this store without changing selectedDate.
  Future<Task?> rescheduleIncomplete({
    required String id,
    required DateTime from,
    required DateTime to,
  }) {
    final source = dateKey(from);
    final target = dateKey(to);
    if (source == target) {
      throw ArgumentError('Tanggal tujuan harus berbeda.');
    }
    return _dao.rescheduleIncomplete(id: id, from: source, to: target);
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    await refresh();
    await loadMonth(_selectedDate);
  }

  Future<Task?> setCompletion(Task task, bool done) async {
    final current = await _dao.byId(task.id);
    if (current == null ||
        current.scheduledDate != task.scheduledDate ||
        current.isDone == done) {
      return null;
    }
    final updated = current.copyWith(isDone: done);
    await _dao.setDone(updated.id, done);
    try {
      await refresh();
    } catch (error, stack) {
      debugPrint('Agenda completion committed, refresh failed: $error\n$stack');
      _revision++;
      notifyListeners();
    }
    return updated;
  }

  Future<void> setDone(String id, bool done) async {
    await _dao.setDone(id, done);
    await refresh();
    await loadMonth(_selectedDate);
  }

  Future<void> restore(Task task) async {
    await _dao.insert(task);
    await refresh();
    await loadMonth(_selectedDate);
  }
}
