import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:provider/provider.dart';

import 'backup/auto_backup.dart';
import 'backup/backup_recovery.dart';
import 'backup/backup_service.dart';
import 'notify/notifier.dart';
import 'state/money_store.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';
import 'ui/motion.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'widget/widget_sync.dart';

class EsokStartup extends StatefulWidget {
  const EsokStartup({
    super.key,
    required this.settings,
    required this.initialize,
  });

  final SettingsStore settings;
  final Future<EsokApp> Function() initialize;

  @override
  State<EsokStartup> createState() => _EsokStartupState();
}

class _EsokStartupState extends State<EsokStartup> {
  static const _startupKey = ValueKey('startup');
  late Future<EsokApp> _ready = widget.initialize();

  void _retry() {
    final next = widget.initialize();
    setState(() {
      _ready = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EsokApp>(
      future: _ready,
      builder: (context, snapshot) {
        final app = snapshot.data;
        final failed =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError;
        return AnimatedBuilder(
          animation: widget.settings,
          builder: (context, _) {
            final mode = widget.settings.themeMode;
            final dark =
                mode == ThemeMode.dark ||
                (mode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) ==
                        Brightness.dark);
            final theme = dark ? EsokTheme.dark() : EsokTheme.light();
            return ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: EsokMotion.reduced(context)
                    ? Duration.zero
                    : EsokMotion.enter,
                switchInCurve: EsokMotion.settle,
                // Keep the shared chrome opaque while Hari fades in over it.
                transitionBuilder: (child, animation) =>
                    child.key == _startupKey
                    ? child
                    : FadeTransition(opacity: animation, child: child),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    for (final child in previous)
                      IgnorePointer(child: ExcludeSemantics(child: child)),
                    ?current,
                  ],
                ),
                child:
                    app ??
                    MaterialApp(
                      key: _startupKey,
                      debugShowCheckedModeBanner: false,
                      theme: theme,
                      darkTheme: dark ? theme : null,
                      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                      home: EsokLoadingShell(onRetry: failed ? _retry : null),
                    ),
              ),
            );
          },
        );
      },
    );
  }
}

class EsokApp extends StatelessWidget {
  const EsokApp({
    super.key,
    required this.store,
    required this.moneyStore,
    required this.settings,
    this.restoreCandidate,
    this.unreadableBackup = false,
  });

  final TaskStore store;
  final MoneyStore moneyStore;
  final SettingsStore settings;
  final BackupData? restoreCandidate;
  final bool unreadableBackup;

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
            title: 'Oh My Esok',
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
              child: restoreCandidate == null && !unreadableBackup
                  ? const EsokShell()
                  : _RestoreGate(
                      candidate: restoreCandidate,
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
    if (state == AppLifecycleState.paused &&
        !AutoBackup.recovery.blocksBackup) {
      unawaited(AutoBackup.runIfChanged());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RestoreGate extends StatefulWidget {
  const _RestoreGate({required this.candidate, required this.child});

  final BackupData? candidate;
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
    final taskStore = context.read<TaskStore>();
    final moneyStore = context.read<MoneyStore>();
    var restoring = false;
    String? error;
    var warnings = <RecoveryWarning>[];
    final restored = await showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => _RestoreSheet(
            candidate: candidate,
            restoring: restoring,
            error: error,
            onRestore: candidate == null || restoring
                ? null
                : () async {
                    setSheetState(() {
                      restoring = true;
                      error = null;
                    });
                    try {
                      warnings = await AutoBackup.recovery.restore(
                        replace: () => BackupService.replaceAll(candidate),
                        refreshStores: () async {
                          await WidgetSync.drainPendingToggles(taskStore);
                          await Future.wait([
                            taskStore.refresh(),
                            taskStore.loadMonth(taskStore.selectedDate),
                            moneyStore.refresh(),
                          ]);
                        },
                        rescheduleReminders:
                            TaskNotifier.instance.syncFromDatabase,
                        syncWidgets: WidgetSync.push,
                      );
                    } catch (_) {
                      if (!sheetContext.mounted) return;
                      setSheetState(() {
                        restoring = false;
                        error =
                            'Pemulihan gagal. Berkas cadangan dipertahankan.';
                      });
                      return;
                    }
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(true);
                    }
                  },
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (restored == false) AutoBackup.recovery.startFresh();
    if (restored == true && warnings.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data dipulihkan. Sebagian pengingat atau tampilan belum '
            'tersinkron; coba buka ulang aplikasi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({
    required this.candidate,
    required this.restoring,
    required this.error,
    required this.onRestore,
  });

  final BackupData? candidate;
  final bool restoring;
  final String? error;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final tasks = candidate?.tasks.length ?? 0;
    final notes = candidate?.notes.length ?? 0;
    final transactions = candidate?.transactions.length ?? 0;
    final hasPayday = candidate?.paydayPlan.isEmpty == false;

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
              candidate == null
                  ? 'Cadangan tidak terbaca'
                  : 'Cadangan ditemukan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              candidate == null
                  ? 'Simpan salinan berkas lama sebelum mulai baru. '
                        'Cadangan otomatis berikutnya dapat menggantinya.'
                  : tasks == 0 && notes == 0 && transactions == 0 && !hasPayday
                  ? 'Cadangan hanya berisi kategori atau sumber dana. '
                        'Pulihkan dan ganti kategori serta sumber dana yang ada?'
                  : '$tasks agenda, $notes catatan, dan $transactions transaksi.'
                        '${hasPayday ? ' Rencana Sampai Gajian juga ikut dipulihkan.' : ''}'
                        ' Pulihkan dari Download/Oh My Esok?',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: EsokColors.muted,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: EsokColors.lateInk)),
            ],
            const SizedBox(height: 18),
            if (candidate != null) ...[
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: onRestore,
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
                  child: Text(restoring ? 'Memulihkan…' : 'Pulihkan'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: restoring
                    ? null
                    : () => Navigator.of(context).pop(false),
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
