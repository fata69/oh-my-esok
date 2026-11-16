import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:provider/provider.dart';

import 'backup/auto_backup.dart';
import 'backup/backup_service.dart';
import 'state/money_store.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'widget/widget_sync.dart';

class EsokApp extends StatelessWidget {
  const EsokApp({
    super.key,
    required this.store,
    required this.moneyStore,
    required this.settings,
    this.restoreCandidate,
  });

  final TaskStore store;
  final MoneyStore moneyStore;
  final SettingsStore settings;
  final BackupData? restoreCandidate;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskStore>.value(value: store),
        ChangeNotifierProvider<MoneyStore>.value(value: moneyStore),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Esok',
            debugShowCheckedModeBanner: false,
            theme: EsokTheme.light(),
            darkTheme: EsokTheme.dark(),
            themeMode: settings.themeMode,
            locale: const Locale('id', 'ID'),
            supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: _BackupOnPause(
              child: restoreCandidate == null
                  ? const EsokShell()
                  : _RestoreGate(
                      candidate: restoreCandidate!,
                      child: const EsokShell(),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _BackupOnPause extends StatefulWidget {
  const _BackupOnPause({required this.child});

  final Widget child;

  @override
  State<_BackupOnPause> createState() => _BackupOnPauseState();
}

class _BackupOnPauseState extends State<_BackupOnPause>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(AutoBackup.runIfChanged());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RestoreGate extends StatefulWidget {
  const _RestoreGate({required this.candidate, required this.child});

  final BackupData candidate;
  final Widget child;

  @override
  State<_RestoreGate> createState() => _RestoreGateState();
}

class _RestoreGateState extends State<_RestoreGate> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_asked || !mounted) return;
    _asked = true;

    final candidate = widget.candidate;
    final restore = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => _RestoreSheet(candidate: candidate),
    );
    if (restore != true || !mounted) return;

    final taskStore = context.read<TaskStore>();
    final moneyStore = context.read<MoneyStore>();
    await BackupService.replaceAll(candidate);
    await taskStore.refresh();
    await moneyStore.refresh();
    await WidgetSync.push();
    await AutoBackup.runIfChanged(force: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({required this.candidate});

  final BackupData candidate;

  @override
  Widget build(BuildContext context) {
    final tasks = candidate.tasks.length;
    final transactions = candidate.transactions.length;

    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EsokColors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Cadangan ditemukan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ada $tasks catatan dan $transactions transaksi dari cadangan '
              'terakhir di Download/Esok. Pulihkan sekarang?',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: EsokColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: EsokColors.accent,
                  foregroundColor: EsokColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Pulihkan'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EsokColors.ink,
                  side: BorderSide(color: EsokColors.lineStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(fontSize: 13.5),
                ),
                child: const Text('Mulai baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
