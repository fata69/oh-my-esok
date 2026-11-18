import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/day_note.dart';
import '../data/task.dart';
import '../notify/notifier.dart';
import '../receipt/receipt_inbox.dart';
import '../state/day_review.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../state/task_store.dart';
import '../util/format.dart';
import '../util/sound_fx.dart';
import '../widget/widget_sync.dart';
import 'agenda_loading.dart';
import 'calendar_sheet.dart';
import 'day_review_sheet.dart';
import 'motion.dart';
import 'note_editor_page.dart';
import 'notes_library.dart';
import 'payday_page.dart';
import 'patch_notes.dart';
import 'tab_layout.dart';
import 'task_editor.dart';
import 'task_repeat.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenMoney, this.onNotesChanged});

  final VoidCallback? onOpenMoney;
  final ValueChanged<bool>? onNotesChanged;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _basePage = 10000;
  static const _settingsChannel = MethodChannel('esok/settings');

  late final PageController _controller;
  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<void>? _sharedReceipts;
  Set<Uri>? _startupWidgetLinks = <Uri>{};
  bool _widgetAddPending = false;
  bool _taskEditorOpen = false;
  bool _dayReviewOpen = false;
  bool _showNotes = false;
  bool _receiptPromptOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _basePage);
    WidgetsBinding.instance.addObserver(this);
    _widgetClicks = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null || !mounted) return;
      final startup = _startupWidgetLinks;
      if (startup != null) {
        startup.add(uri);
      } else {
        unawaited(_openFromWidget(uri));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TaskNotifier.instance.requestPermissions().catchError((Object error) {
        debugPrint('Notification permission request failed: $error');
      });
      unawaited(_readStartupWidgetLinks());
      if (Platform.isAndroid) {
        _sharedReceipts = ReceiptInbox.changes.listen((_) {
          unawaited(_offerSharedReceipt());
        }, onError: (Object error) => debugPrint('Receipt listener: $error'));
        unawaited(_offerSharedReceipt());
      }
    });
  }

  Future<void> _readStartupWidgetLinks() async {
    Uri? initial;
    try {
      initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (error) {
      debugPrint('Reading initial widget link failed: $error');
    }
    if (!mounted) return;
    final queued = {?initial, ...?_startupWidgetLinks};
    _startupWidgetLinks = null;
    for (final uri in queued) {
      if (!mounted) break;
      await _openFromWidget(uri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    _sharedReceipts?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _dayReviewOpen) return;
    final store = context.read<TaskStore>();
    WidgetSync.drainPendingToggles(store).then((changed) async {
      if (changed) await _syncRecurringEffects();
      await store.refresh();
    });
  }

  DateTime _dateForPage(int page) =>
      today().add(Duration(days: page - _basePage));

  int _pageForDate(DateTime date) => _basePage + daysBetween(today(), date);

  Future<void> _jumpTo(DateTime date, {bool animate = true}) async {
    if (!mounted) return;
    final page = _pageForDate(date).clamp(0, _basePage * 2);
    if (!_controller.hasClients) {
      await context.read<TaskStore>().selectDate(date);
      return;
    }
    if (!animate ||
        EsokMotion.reduced(context) ||
        (page - (_controller.page ?? page)).abs() > 1) {
      _controller.jumpToPage(page);
      return;
    }
    await _controller.animateToPage(
      page,
      duration: EsokMotion.enter,
      curve: EsokMotion.settle,
    );
  }

  Future<void> _openCalendar() async {
    final store = context.read<TaskStore>();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (context) => CalendarSheet(initialDate: store.selectedDate),
    );
    if (picked != null) {
      await _jumpTo(picked);
    }
  }

  Future<void> _openDayReview(DateTime date) async {
    if (_dayReviewOpen) return;
    final tasks = context.read<TaskStore>();
    final service = DayReviewService(
      tasks: tasks,
      transactionsForDate: context.read<MoneyStore>().transactionsForDate,
      reconcileWidget: () async {
        if (await WidgetSync.drainPendingToggles(tasks, reportErrors: true)) {
          await _syncRecurringEffects();
        }
      },
      rescheduleReminder: TaskNotifier.instance.reschedule,
      pushWidget: () => WidgetSync.push(reportErrors: true),
    );
    _dayReviewOpen = true;
    try {
      await showDayReviewSheet(
        context,
        date: date,
        service: service,
        reviewReceipts: Platform.isAndroid ? _openSharedReceipt : null,
        onOpenPayday: () => openPaydayPage(context),
      );
    } finally {
      _dayReviewOpen = false;
    }
  }

  Future<void> _offerSharedReceipt() async {
    if (!mounted || _receiptPromptOpen || _taskEditorOpen) return;
    _receiptPromptOpen = true;
    try {
      final files = await ReceiptInbox.pendingImages();
      if (!mounted ||
          files.isEmpty ||
          ModalRoute.isCurrentOf(context) == false) {
        return;
      }
      final file = files.first;
      final scan = await showDialog<bool>(
        context: context,
        animationStyle: EsokMotion.presentation(context),
        builder: (context) => AlertDialog(
          title: const Text('Struk diterima'),
          content: const Text(
            'Gambar disimpan sebagai draf. Kamu bisa memindainya sekarang '
            'atau membukanya lagi dari Tutup hari.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nanti saja'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pindai struk'),
            ),
          ],
        ),
      );
      if (scan == true && mounted) await _openSharedReceipt(file);
    } catch (error) {
      debugPrint('Opening shared receipt failed: $error');
    } finally {
      _receiptPromptOpen = false;
    }
  }

  Future<void> _openSharedReceipt(File file) async {
    if (!mounted) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TxEditorPage(receiptImage: file)),
    );
  }

  void _selectNotes(bool value) {
    if (_showNotes == value) return;
    setState(() => _showNotes = value);
    widget.onNotesChanged?.call(value);
  }

  Future<void> createEntry() => _showNotes ? _openNote() : _openEditor();

  Future<void> _openNote([DayNote? note]) async {
    if (_taskEditorOpen || !mounted) return;
    _taskEditorOpen = true;
    final store = context.read<TaskStore>();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => NoteEditorPage(
            note: note,
            onDelete: note == null ? null : () => store.deleteNote(note.id),
            onSave: (draft, date, time) async {
              if (date == null) {
                await store.saveNote(draft, creating: note == null);
                return;
              }
              final Task task;
              if (note != null) {
                final scheduled = await store.scheduleNote(
                  draft,
                  date: date,
                  time: time,
                );
                if (scheduled == null) {
                  throw StateError('Catatan sudah dipindahkan.');
                }
                task = scheduled;
              } else {
                task = Task(
                  id: draft.id,
                  title: draft.displayTitle,
                  notes: draft.body.isEmpty ? null : draft.body,
                  scheduledDate: dateKey(date),
                  scheduledTime: time,
                  isDone: false,
                  createdAt: draft.createdAt,
                );
                await store.add(task);
              }
              if (mounted) {
                _selectNotes(false);
                await _jumpTo(task.date, animate: false);
              }
              await _syncNoteSchedule(task);
            },
          ),
        ),
      );
    } finally {
      _taskEditorOpen = false;
    }
  }

  Future<void> _syncNoteSchedule(Task task, {bool cancel = false}) async {
    try {
      if (cancel) {
        await TaskNotifier.instance.cancel(task.id);
      } else {
        await TaskNotifier.instance.schedule(task);
      }
      await WidgetSync.push(reportErrors: true);
    } catch (error, stack) {
      debugPrint('Note schedule sync failed: $error\n$stack');
      _showMessage('Tersimpan. Pengingat atau widget belum diperbarui.');
    }
  }

  Future<void> _openEditor({
    Task? task,
    DateTime? initialDate,
    TaskEditScope? scope,
  }) async {
    if (_taskEditorOpen || !mounted) return;
    _taskEditorOpen = true;
    try {
      await _editTask(task, initialDate, scope);
    } finally {
      _taskEditorOpen = false;
    }
  }

  Future<void> _editTask(
    Task? task,
    DateTime? initialDate,
    TaskEditScope? scope,
  ) async {
    final store = context.read<TaskStore>();
    final result = await showModalBottomSheet<TaskEditorResult>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (_) => TaskEditorSheet(
        task: task,
        initialDate: initialDate ?? store.selectedDate,
        scope: scope,
      ),
    );
    if (result == null || !mounted) return;

    if (result.deleted) {
      if (task == null) return;
      await store.delete(task.id);
      await TaskNotifier.instance.cancel(task.id);
      await WidgetSync.push();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tugas dihapus.'),
          action: SnackBarAction(
            label: 'Urungkan',
            textColor: EsokColors.of(context).canvas,
            onPressed: () async {
              await store.restore(task);
              await TaskNotifier.instance.schedule(task);
              await WidgetSync.push();
            },
          ),
        ),
      );
      return;
    }

    final saved = result.task;
    if (saved == null) return;

    if (result.removeSchedule) {
      try {
        final note = await store.unscheduleTask(saved);
        if (note == null) {
          _showMessage('Agenda ini sudah berubah. Coba buka lagi.');
          return;
        }
        if (mounted) _selectNotes(true);
        await _syncNoteSchedule(saved, cancel: true);
      } catch (error, stack) {
        debugPrint('Removing schedule failed: $error\n$stack');
        _showMessage('Agenda belum bisa dipindahkan ke Catatan.');
      }
      return;
    }

    final recurring = saved.isRecurring || (task?.isRecurring ?? false);
    if (task == null) {
      await store.add(saved);
    } else if (scope != null) {
      try {
        await store.updateOccurrence(
          task,
          saved,
          following: scope == TaskEditScope.following,
        );
      } on ArgumentError catch (error) {
        final message = error.message;
        _showMessage(
          message is String ? message : 'Jadwal ini belum bisa diubah.',
        );
        return;
      }
    } else {
      await store.update(saved);
    }
    if (recurring) {
      await _syncRecurringEffects();
    } else {
      await TaskNotifier.instance.schedule(saved);
      await WidgetSync.push();
    }
    if (!mounted) return;
    var destination = saved.date;
    if (saved.repeatWeekdays.isNotEmpty && scope != TaskEditScope.occurrence) {
      for (var offset = 0; offset < 7; offset++) {
        final date = DateTime(
          saved.date.year,
          saved.date.month,
          saved.date.day + offset,
        );
        if (saved.repeatWeekdays.contains(date.weekday)) {
          destination = date;
          break;
        }
      }
    }
    await _jumpTo(destination);
  }

  Future<void> _openTask(Task task) async {
    if (!task.isRecurring) {
      await _openEditor(task: task);
      return;
    }
    final edit = await _showTaskOptions<bool>(
      title: task.title,
      date: task.date,
      time: task.scheduledTime,
      options: (sheet) => [
        _TaskAction(
          label: 'Ubah jadwal',
          icon: Icons.chevron_right,
          onTap: () => Navigator.pop(sheet, true),
        ),
        _TaskAction(
          label: 'Lewati kali ini',
          detail: 'Hanya untuk tanggal ini',
          icon: Icons.skip_next_outlined,
          onTap: () => Navigator.pop(sheet, false),
        ),
      ],
    );
    if (edit == null || !mounted) return;
    if (!edit) {
      await _skipTask(task);
      return;
    }
    final scope = await _showTaskOptions<TaskEditScope>(
      title: 'Ubah jadwal',
      date: task.date,
      options: (sheet) => [
        _TaskAction(
          label: 'Hanya kali ini',
          detail: 'Ubah tugas untuk tanggal ini saja.',
          icon: Icons.chevron_right,
          onTap: () => Navigator.pop(sheet, TaskEditScope.occurrence),
        ),
        _TaskAction(
          label: 'Kali ini dan seterusnya',
          detail: 'Jadwal sebelum tanggal ini tetap sama.',
          icon: Icons.chevron_right,
          onTap: () => Navigator.pop(sheet, TaskEditScope.following),
        ),
      ],
    );
    if (scope != null && mounted) await _openEditor(task: task, scope: scope);
  }

  Future<T?> _showTaskOptions<T>({
    required String title,
    required DateTime date,
    String? time,
    required List<Widget> Function(BuildContext) options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: EsokColors.of(context).canvas,
      barrierColor: EsokColors.scrim,
      builder: (sheet) {
        final colors = EsokColors.of(sheet);
        final text = Theme.of(sheet).textTheme;
        final actions = options(sheet);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: text.titleLarge),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheet),
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                Text(
                  '${weekdayName(date)}, ${dateTitle(date)}'
                  '${time == null ? '' : ' · ${timeText(time)}'}',
                  style: text.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 12),
                Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, action) in actions.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        action,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _skipTask(Task task) async {
    final store = context.read<TaskStore>();
    await store.skipOccurrence(task);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tugas dilewati untuk ${dateTitle(task.date)}.'),
          action: SnackBarAction(
            label: 'Urungkan',
            textColor: EsokColors.of(context).canvas,
            onPressed: () async {
              await store.undoSkipOccurrence(task);
              await _syncRecurringEffects();
            },
          ),
        ),
      );
    }
    await _syncRecurringEffects();
  }

  Future<void> _syncRecurringEffects() async {
    try {
      await TaskNotifier.instance.syncFromDatabase();
    } catch (error, stack) {
      debugPrint('Agenda reminder sync failed: $error\n$stack');
    }
    await WidgetSync.push();
  }

  Future<void> _toggle(Task task) async {
    final store = context.read<TaskStore>();
    final settings = context.read<SettingsStore>();
    final updated = await store.toggle(task);
    if (updated.isDone) {
      final dayTasks = await store.tasksFor(updated.date);
      final allDone =
          dayTasks.isNotEmpty && dayTasks.every((item) => item.isDone);
      if (settings.soundEnabled) {
        SoundFx.play(allDone ? settings.soundComplete : settings.soundCheck);
      }
      if (!task.isRecurring) await TaskNotifier.instance.cancel(task.id);
    } else {
      if (settings.soundEnabled) SoundFx.play(settings.soundUncheck);
      if (!task.isRecurring) await TaskNotifier.instance.schedule(updated);
    }
    if (task.isRecurring) {
      await _syncRecurringEffects();
    } else {
      await WidgetSync.push();
    }
  }

  Future<void> _openFromWidget(Uri? uri) async {
    if (!mounted || uri == null || uri.scheme != 'ohmyesok') return;

    if (uri.host == 'money') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'new') {
        if (!mounted) return;
        await Navigator.of(context).push<String>(
          MaterialPageRoute<String>(
            builder: (_) =>
                TxEditorPage(initialDate: today(), initialKind: 'expense'),
          ),
        );
      } else {
        widget.onOpenMoney?.call();
      }
      return;
    }

    if (uri.host == 'day') {
      if (uri.pathSegments.isEmpty) return;
      final date = DateTime.tryParse(uri.pathSegments.first);
      if (date == null) return;
      final day = dateOnly(date);
      _selectNotes(false);
      if (uri.queryParameters['add'] != '1') {
        await _jumpTo(day);
        return;
      }
      if (_widgetAddPending || _taskEditorOpen) return;
      _widgetAddPending = true;
      try {
        final store = context.read<TaskStore>();
        await _jumpTo(day);
        if (!mounted) return;
        await store.selectDate(day);
        if (mounted) await _openEditor(initialDate: day);
      } finally {
        _widgetAddPending = false;
      }
      return;
    }

    if (uri.host != 'task' || uri.pathSegments.isEmpty) return;
    final store = context.read<TaskStore>();
    final task = await store.taskById(uri.pathSegments.first);
    if (task == null || !mounted) return;
    _selectNotes(false);
    await _jumpTo(task.date);
    if (!mounted) return;
    await _openTask(task);
  }

  Future<void> _openBatterySettings() async {
    try {
      await _settingsChannel.invokeMethod<void>('openBatterySettings');
    } catch (error) {
      debugPrint('openBatterySettings failed: $error');
    }
  }

  Future<void> _pinWidget() async {
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      if (supported != true) {
        _showMessage(
          'Launcher ini tidak mendukung pemasangan widget dari aplikasi.',
        );
        return;
      }
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: WidgetSync.androidProvider,
      );
    } catch (error) {
      _showMessage('Widget belum bisa dipasang.');
      debugPrint('requestPinWidget failed: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openReleaseNotes() async {
    var version = '1.1.0';
    var buildNumber = '2';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      buildNumber = info.buildNumber;
    } catch (error) {
      debugPrint('PackageInfo failed: $error');
    }
    if (!mounted) return;
    await showPatchNotes(context, version: version, buildNumber: buildNumber);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final store = context.watch<TaskStore>();
    final selected = store.selectedDate;

    return EsokTabLayout(
      headerAction: PopupMenuButton<String>(
        tooltip: 'Pengaturan',
        icon: Icon(Icons.more_horiz, size: 20, color: colors.muted),
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        onSelected: (value) {
          if (value == 'alarms') {
            TaskNotifier.instance.requestExactAlarms();
          } else if (value == 'battery') {
            _openBatterySettings();
          } else if (value == 'widget') {
            _pinWidget();
          } else if (value == 'release_notes') {
            _openReleaseNotes();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'alarms', child: Text('Alarm & pengingat')),
          PopupMenuItem(value: 'battery', child: Text('Baterai tanpa batas')),
          PopupMenuItem(value: 'widget', child: Text('Pasang widget')),
          PopupMenuItem(value: 'release_notes', child: Text('Catatan rilis')),
        ],
      ),
      period: Column(
        children: [
          if (_showNotes)
            NotesToolbar(count: store.notes.length)
          else
            EsokPeriodHeader(
              title: dateTitle(selected),
              detail:
                  '${weekdayName(selected)} · ${positionLabel(selected)}'
                  '${selected.year == today().year ? '' : ' · ${selected.year}'}',
              selectLabel: 'Pilih tanggal',
              previousLabel: 'Hari sebelumnya',
              nextLabel: 'Hari berikutnya',
              onPrevious: store.canGoPrevious
                  ? () => _jumpTo(selected.subtract(const Duration(days: 1)))
                  : null,
              onNext: () => _jumpTo(selected.add(const Duration(days: 1))),
              onSelect: _openCalendar,
            ),
          DaySectionSwitch(notes: _showNotes, onChanged: _selectNotes),
        ],
      ),
      child: IndexedStack(
        index: _showNotes ? 1 : 0,
        sizing: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _basePage * 2 + 1,
            onPageChanged: (index) {
              context.read<TaskStore>().selectDate(_dateForPage(index));
            },
            itemBuilder: (context, index) {
              final date = _dateForPage(index);
              return _DayPane(
                key: ValueKey(index),
                date: date,
                revision: store.revision,
                atEarliest: date == store.earliestAllowedDate,
                onToggle: _toggle,
                onOpen: _openTask,
                onCreate: _openEditor,
                onCloseDay: () => _openDayReview(date),
                onJumpToday: () => _jumpTo(today()),
                onJumpNext: () => _jumpTo(date.add(const Duration(days: 1))),
              );
            },
          ),
          NotesLibrary(
            notes: store.notes,
            onOpen: _openNote,
            onCreate: _openNote,
          ),
        ],
      ),
    );
  }
}

class _DayData {
  const _DayData({required this.tasks, required this.nextDayTasks});

  final List<Task> tasks;
  final List<Task> nextDayTasks;
}

class _DayPane extends StatefulWidget {
  const _DayPane({
    super.key,
    required this.date,
    required this.revision,
    required this.atEarliest,
    required this.onToggle,
    required this.onOpen,
    required this.onCreate,
    required this.onCloseDay,
    required this.onJumpToday,
    required this.onJumpNext,
  });

  final DateTime date;
  final int revision;
  final bool atEarliest;
  final Future<void> Function(Task) onToggle;
  final ValueChanged<Task> onOpen;
  final VoidCallback onCreate;
  final VoidCallback onCloseDay;
  final VoidCallback onJumpToday;
  final VoidCallback onJumpNext;

  @override
  State<_DayPane> createState() => _DayPaneState();
}

class _DayPaneState extends State<_DayPane> {
  late Future<_DayData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DayPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _load();
    }
  }

  void _load() {
    final store = context.read<TaskStore>();
    _future =
        Future.wait([
          store.tasksFor(widget.date),
          store.tasksFor(widget.date.add(const Duration(days: 1))),
        ]).then((results) {
          return _DayData(tasks: results[0], nextDayTasks: results[1]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DayData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          if (!snapshot.hasError) {
            return const AgendaLoading();
          }
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: EsokTabLayout.gutter,
            ),
            children: [
              const Text('Agenda belum bisa dimuat.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          );
        }
        final tasks = [...data.tasks]
          ..sort((a, b) {
            final time = (a.scheduledTime ?? '24:00').compareTo(
              b.scheduledTime ?? '24:00',
            );
            return time == 0 ? a.createdAt.compareTo(b.createdAt) : time;
          });
        final undone = tasks.where((task) => !task.isDone).length;
        final isPast = widget.date.isBefore(today());

        return ListView(
          padding: EdgeInsets.fromLTRB(
            EsokTabLayout.gutter,
            4,
            EsokTabLayout.gutter,
            EsokTabLayout.scrollBottomOf(context),
          ),
          children: [
            AgendaHeading(
              progress: tasks.isEmpty
                  ? 'Belum ada agenda'
                  : '${tasks.length - undone} dari ${tasks.length} selesai',
              onCloseDay: widget.onCloseDay,
            ),
            if (tasks.isEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: widget.onCreate,
                  child: const Text('Tambah agenda'),
                ),
              )
            else ...[
              for (final (index, task) in tasks.indexed)
                _TaskRow(
                  key: ValueKey(task.id),
                  task: task,
                  showDivider: index != tasks.length - 1,
                  onToggle: () => widget.onToggle(task),
                  onOpen: () => widget.onOpen(task),
                ),
            ],
            if (isPast && undone > 0) ...[
              const SizedBox(height: 20),
              _LateNote(count: undone),
            ],
            const SizedBox(height: 22),
            _BottomRow(
              date: widget.date,
              nextDayTasks: data.nextDayTasks,
              atEarliest: widget.atEarliest,
              onJumpToday: widget.onJumpToday,
              onJumpNext: widget.onJumpNext,
            ),
          ],
        );
      },
    );
  }
}

class _TaskAction extends StatelessWidget {
  const _TaskAction({
    required this.label,
    this.detail,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.showDivider,
    required this.onToggle,
    required this.onOpen,
  });

  final Task task;
  final bool showDivider;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final duration = EsokMotion.reduced(context)
        ? Duration.zero
        : EsokMotion.feedback;
    final checkedColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF63D99A)
        : const Color(0xFF08754A);
    final titleStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: task.isDone ? colors.muted : colors.ink,
      decoration: task.isDone ? TextDecoration.lineThrough : null,
      decorationThickness: 1,
      decorationColor: colors.muted,
    );

    return Column(
      children: [
        Semantics(
          label: '${task.title}, ${task.isDone ? 'selesai' : 'belum selesai'}',
          child: Row(
            children: [
              Semantics(
                label: task.title,
                checked: task.isDone,
                onTap: onToggle,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onToggle,
                  child: SizedBox(
                    width: 48,
                    height: 56,
                    child: Center(
                      child: AnimatedContainer(
                        duration: duration,
                        curve: EsokMotion.settle,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.isDone
                              ? checkedColor
                              : Colors.transparent,
                          border: Border.all(
                            color: task.isDone ? checkedColor : colors.muted,
                            width: 1.5,
                          ),
                        ),
                        child: task.isDone
                            ? Icon(Icons.check, size: 13, color: colors.canvas)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        0,
                        8,
                        task.isRecurring ? 0 : 12,
                        8,
                      ),
                      child: task.isRecurring
                          ? _RecurringTaskDetails(
                              task: task,
                              titleStyle: titleStyle,
                              duration: duration,
                            )
                          : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AnimatedDefaultTextStyle(
                                          duration: duration,
                                          curve: EsokMotion.settle,
                                          style: titleStyle,
                                          child: Text(
                                            task.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (task.scheduledTime != null) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          timeText(task.scheduledTime),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.muted,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (task.notes case final note?
                                      when note.isNotEmpty)
                                    Text(
                                      note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (task.isRecurring)
                IconButton(
                  onPressed: onOpen,
                  icon: Icon(Icons.more_horiz, color: colors.muted, size: 20),
                  tooltip: 'Tindakan untuk ${task.title}',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 48, endIndent: 12),
      ],
    );
  }
}

class _RecurringTaskDetails extends StatelessWidget {
  const _RecurringTaskDetails({
    required this.task,
    required this.titleStyle,
    required this.duration,
  });

  final Task task;
  final TextStyle titleStyle;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final repeat = TaskRepeatRule.fromWeekdays(task.repeatWeekdays, task.date);
    final metaStyle = TextStyle(
      fontSize: 12,
      color: colors.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: duration,
          style: titleStyle,
          child: Text(task.title),
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (task.scheduledTime != null)
              Text(timeText(task.scheduledTime), style: metaStyle),
            Semantics(
              label: repeat.summary(task.date),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 14, color: colors.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      repeat.summary(task.date, compact: true),
                      style: metaStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LateNote extends StatelessWidget {
  const _LateNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.lateSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$count tugas belum dicentang',
              style: TextStyle(fontSize: 12, color: colors.lateInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.date,
    required this.nextDayTasks,
    required this.atEarliest,
    required this.onJumpToday,
    required this.onJumpNext,
  });

  final DateTime date;
  final List<Task> nextDayTasks;
  final bool atEarliest;
  final VoidCallback onJumpToday;
  final VoidCallback onJumpNext;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today();
    final next = date.add(const Duration(days: 1));

    if (atEarliest) {
      return _BottomCard(
        label: 'Tidak ada catatan sebelum ini',
        action: 'KE HARI INI',
        onTap: onJumpToday,
      );
    }

    if (isToday) {
      return _BottomCard(
        label:
            'Besok, ${shortDateTitle(next)} · ${taskCountLabel(nextDayTasks.length)}',
        boldPrefix: 'Besok, ${shortDateTitle(next)}',
        action: 'LIHAT',
        onTap: onJumpNext,
      );
    }

    return _BottomCard(
      label:
          '${weekdayName(next)}, ${shortDateTitle(next)} · ${taskCountLabel(nextDayTasks.length)}',
      action: 'KE HARI INI',
      onTap: onJumpToday,
    );
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.label,
    required this.action,
    required this.onTap,
    this.boldPrefix,
  });

  final String label;
  final String action;
  final VoidCallback onTap;
  final String? boldPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final prefix = boldPrefix;
    return Material(
      color: colors.soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: colors.inkSoft),
                    children: [
                      if (prefix != null)
                        TextSpan(
                          text: prefix,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (prefix != null)
                        TextSpan(text: label.substring(prefix.length)),
                      if (prefix == null) TextSpan(text: label),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$action ›',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.03,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
