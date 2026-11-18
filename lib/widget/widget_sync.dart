import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/money_transaction_dao.dart';
import '../data/task.dart';
import '../data/task_dao.dart';
import '../state/task_store.dart';
import '../util/format.dart';
import '../util/sound_library.dart';

class WidgetSync {
  WidgetSync._();

  // Kotlin classes keep their upstream namespace; the installed app ID differs.
  static const androidProvider = 'com.habib.jadwal.TaskWidgetProvider';

  static Future<void> push({bool reportErrors = false}) async {
    try {
      final db = await AppDatabase.open();
      final now = today();
      final taskDays = _agendaSnapshot(await TaskDao(db).all(), now);
      await _saveTaskSnapshot(jsonEncode(taskDays), reportErrors: reportErrors);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);

      final moneyDao = MoneyTransactionDao(db);
      final todayTransactions = await moneyDao.forDate(dateKey(now));
      final monthTransactions = await moneyDao.between(
        dateKey(DateTime(now.year, now.month)),
        dateKey(DateTime(now.year, now.month + 1, 0)),
      );
      var todayOut = 0;
      for (final transaction in todayTransactions) {
        if (transaction.isExpense) todayOut += transaction.amount;
      }
      var monthOut = 0;
      var monthIn = 0;
      for (final transaction in monthTransactions) {
        if (transaction.isExpense) monthOut += transaction.amount;
        if (transaction.isIncome) monthIn += transaction.amount;
      }
      final prefs = await SharedPreferences.getInstance();
      final masked = prefs.getBool('hide_amounts') ?? false;
      await HomeWidget.saveWidgetData<String>(
        'money_summary_json',
        jsonEncode({
          'today': todayOut,
          'month': monthOut,
          'monthIn': monthIn,
          'masked': masked,
        }),
      );

      final soundEnabled = prefs.getBool('sound_enabled') ?? true;
      final checkId =
          prefs.getString('sound_check_id') ??
          prefs.getString('sound_done_id') ??
          SoundLibrary.builtIn[1].id;
      final uncheckId =
          prefs.getString('sound_uncheck_id') ?? SoundLibrary.builtIn[2].id;
      final completeId =
          prefs.getString('sound_complete_id') ?? SoundLibrary.builtIn[0].id;
      final imported = _decodeImportedSounds(prefs.getString('sound_imports'));
      final check = SoundLibrary.resolve(
        checkId,
        imported,
        fallback: SoundLibrary.builtIn[1],
      );
      final uncheck = SoundLibrary.resolve(
        uncheckId,
        imported,
        fallback: SoundLibrary.builtIn[2],
      );
      final complete = SoundLibrary.resolve(
        completeId,
        imported,
        fallback: SoundLibrary.builtIn[0],
      );
      await HomeWidget.saveWidgetData<bool>('sound_enabled', soundEnabled);
      await HomeWidget.saveWidgetData<String>(
        'sound_check_raw',
        check.raw ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'sound_check_file',
        check.file ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'sound_uncheck_raw',
        uncheck.raw ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'sound_uncheck_file',
        uncheck.file ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'sound_complete_raw',
        complete.raw ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'sound_complete_file',
        complete.file ?? '',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.habib.jadwal.MoneyWidgetProvider',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.habib.jadwal.MoneyWidgetBarProvider',
      );
    } catch (error, stack) {
      debugPrint('WidgetSync.push failed: $error\n$stack');
      if (reportErrors) rethrow;
    }
  }

  static Map<String, Object?> _agendaSnapshot(List<Task> rows, DateTime now) {
    final first = dateKey(DateTime(now.year, now.month, now.day - 1));
    final last = dateKey(DateTime(now.year, now.month, now.day + 27));
    final currentDay = dateKey(now);
    final tasks = TaskDao.expandTasks(rows, first, last);
    if (!tasks.any(
      (task) => !task.isDone && task.scheduledDate.compareTo(currentDay) > 0,
    )) {
      // A one-time task or a series starting after the widget's regular window
      // can still be the nearest appointment. A full week reaches each
      // possible start weekday after its anchor date.
      final laterDates =
          rows
              .where(
                (task) =>
                    !task.isDone &&
                    !task.isSkipped &&
                    task.scheduledDate.compareTo(last) > 0,
              )
              .map((task) => task.scheduledDate)
              .toSet()
              .toList()
            ..sort();
      for (final firstDate in laterDates) {
        final date = DateTime.parse(firstDate);
        final lastDate = dateKey(DateTime(date.year, date.month, date.day + 6));
        final later = TaskDao.expandTasks(rows, firstDate, lastDate);
        if (later.any((task) => !task.isDone)) {
          tasks.addAll(later);
          break;
        }
      }
    }

    final byDay = <String, List<Task>>{};
    for (final task in tasks) {
      byDay.putIfAbsent(task.scheduledDate, () => []).add(task);
    }
    return {
      for (final entry in byDay.entries)
        entry.key: {
          'total': entry.value.length,
          'done': entry.value.where((task) => task.isDone).length,
          'label': shortDayDate(DateTime.parse(entry.key)),
          'tasks': entry.value.map((task) => task.toWidgetJson()).toList(),
        },
    };
  }

  static Future<void> _saveTaskSnapshot(
    String json, {
    required bool reportErrors,
  }) async {
    final saved = await HomeWidget.saveWidgetData<String>('tasks_json', json);
    if (reportErrors && saved != true) {
      throw StateError('Task widget snapshot could not be saved');
    }
  }

  static Future<bool> drainPendingToggles(
    TaskStore store, {
    bool reportErrors = false,
  }) async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_toggles');
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (reportErrors) throw const FormatException('Invalid widget queue');
        return false;
      }

      if (reportErrors &&
          decoded.entries.any((entry) => entry.value is! bool)) {
        throw const FormatException('Invalid widget checkmark');
      }

      var changed = false;
      for (final entry in decoded.entries) {
        final id = entry.key.toString();
        final done = entry.value == true;
        await store.setDone(id, done);
        changed = true;
      }
      final cleared = await HomeWidget.saveWidgetData<String>(
        'pending_toggles',
        '{}',
      );
      if (reportErrors && cleared != true) {
        throw StateError('Widget queue could not be cleared');
      }
      return changed;
    } catch (error, stack) {
      debugPrint('WidgetSync.drainPendingToggles failed: $error\n$stack');
      if (reportErrors) rethrow;
      return false;
    }
  }

  static List<SoundOption> _decodeImportedSounds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => SoundOption.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
