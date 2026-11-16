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

  static const androidProvider = 'TaskWidgetProvider';

  static Future<void> push() async {
    try {
      final db = await AppDatabase.open();
      final dao = TaskDao(db);
      final start = today();
      final taskDays = <String, Object?>{};
      for (var offset = 0; offset < 14; offset++) {
        final date = start.add(Duration(days: offset));
        final tasks = await dao.forDate(dateKey(date));
        taskDays[dateKey(date)] = {
          'total': tasks.length,
          'done': tasks.where((task) => task.isDone).length,
          'label': offset == 0
              ? 'Hari ini'
              : offset == 1
              ? 'Besok'
              : shortDayDate(date),
          'tasks': tasks.map((task) => task.toWidgetJson()).toList(),
        };
      }

      await HomeWidget.saveWidgetData<String>(
        'tasks_json',
        jsonEncode(taskDays),
      );
      await HomeWidget.updateWidget(androidName: androidProvider);

      final now = today();
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
      await HomeWidget.updateWidget(androidName: 'MoneyWidgetProvider');
      await HomeWidget.updateWidget(
        androidName: 'MoneyWidgetBarProvider',
      );
    } catch (error, stack) {
      debugPrint('WidgetSync.push failed: $error\n$stack');
    }
  }

  static Future<bool> drainPendingToggles(TaskStore store) async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_toggles');
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;

      var changed = false;
      for (final entry in decoded.entries) {
        final id = entry.key.toString();
        final done = entry.value == true;
        await store.setDone(id, done);
        changed = true;
      }
      await HomeWidget.saveWidgetData<String>('pending_toggles', '{}');
      return changed;
    } catch (error, stack) {
      debugPrint('WidgetSync.drainPendingToggles failed: $error\n$stack');
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
