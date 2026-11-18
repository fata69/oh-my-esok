import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'backup/auto_backup.dart';
import 'backup/backup_service.dart';
import 'data/account_dao.dart';
import 'data/category_dao.dart';
import 'data/database.dart';
import 'data/money_transaction_dao.dart';
import 'data/task_dao.dart';
import 'notify/notifier.dart';
import 'state/money_store.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';
import 'ui/theme.dart';
import 'widget/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  final settings = SettingsStore();
  await settings.init();

  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  EsokColors.useDark(
    settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark),
  );

  final database = await AppDatabase.open();
  final store = TaskStore(TaskDao(database));
  final moneyStore = MoneyStore(
    CategoryDao(database),
    AccountDao(database),
    MoneyTransactionDao(database),
  );
  await store.init();
  await moneyStore.init();

  final empty = await _isDatabaseEmpty(database);
  BackupData? restoreCandidate;
  var unreadableBackup = false;
  if (empty) {
    AutoBackup.recovery.awaitDecision();
    final backup = await AutoBackup.readForRecovery();
    restoreCandidate = backup.data;
    unreadableBackup = backup.unreadable;
    if (restoreCandidate == null && !unreadableBackup) {
      AutoBackup.recovery.startFresh();
    }
  }

  final recoveryPending = AutoBackup.recovery.blocksBackup;
  if (!recoveryPending) await WidgetSync.drainPendingToggles(store);

  try {
    TaskNotifier.instance.configureLead(
      enabled: settings.leadEnabled,
      minutes: settings.leadMinutes,
    );
    await TaskNotifier.instance.configureSound(
      settings.soundReminder.raw ?? 'coin',
    );
    await TaskNotifier.instance.init();
    await TaskNotifier.instance.rescheduleAll(await TaskDao(database).all());
  } catch (error, stack) {
    debugPrint('Notification init failed: $error\n$stack');
  }
  if (!recoveryPending) await WidgetSync.push();

  _startReminderTopUps();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: EsokColors.isDark
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: EsokColors.isDark
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: EsokColors.canvas,
      systemNavigationBarDividerColor: EsokColors.canvas,
      systemNavigationBarIconBrightness: EsokColors.isDark
          ? Brightness.light
          : Brightness.dark,
    ),
  );

  runApp(
    EsokApp(
      store: store,
      moneyStore: moneyStore,
      settings: settings,
      restoreCandidate: restoreCandidate,
      unreadableBackup: unreadableBackup,
    ),
  );

  if (!empty) {
    unawaited(AutoBackup.runIfChanged());
  }
}

void _startReminderTopUps() {
  Future<void> topUp() async {
    if (AutoBackup.recovery.blocksBackup) return;
    try {
      await TaskNotifier.instance.topUpRecurring();
    } catch (error, stack) {
      debugPrint('Reminder top-up failed: $error\n$stack');
    }
  }

  Timer? timer;
  AppLifecycleListener(
    onResume: () {
      unawaited(topUp());
      timer ??= Timer.periodic(
        const Duration(minutes: 15),
        (_) => unawaited(topUp()),
      );
    },
    onPause: () {
      timer?.cancel();
      timer = null;
    },
  );
  // main() may finish after the initial resume event.
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    timer ??= Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(topUp()),
    );
  }
}

Future<bool> _isDatabaseEmpty(Database database) async {
  final tasks =
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM tasks'),
      ) ??
      0;
  final transactions =
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM transactions'),
      ) ??
      0;
  return tasks == 0 && transactions == 0;
}
