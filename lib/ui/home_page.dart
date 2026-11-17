import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/task.dart';
import '../notify/notifier.dart';
import '../state/day_review.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../state/task_store.dart';
import '../util/format.dart';
import '../util/sound_fx.dart';
import '../widget/widget_sync.dart';
import 'calendar_sheet.dart';
import 'day_money_section.dart';
import 'day_review_sheet.dart';
import 'patch_notes.dart';
import 'tab_layout.dart';
import 'task_editor.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenMoney});

  final VoidCallback? onOpenMoney;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _basePage = 10000;
  static const _settingsChannel = MethodChannel('esok/settings');

  late final PageController _controller;
  StreamSubscription<Uri?>? _widgetClicks;
  bool _dayReviewOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _basePage);
    WidgetsBinding.instance.addObserver(this);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openFromWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TaskNotifier.instance.requestPermissions().catchError((Object error) {
        debugPrint('Notification permission request failed: $error');
      });
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (mounted) _openFromWidget(uri);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _dayReviewOpen) return;
    final store = context.read<TaskStore>();
    WidgetSync.drainPendingToggles(store).then((changed) async {
      if (changed) await WidgetSync.push();
      await store.refresh();
    });
  }

  DateTime _dateForPage(int page) =>
      today().add(Duration(days: page - _basePage));

  int _pageForDate(DateTime date) => _basePage + daysBetween(today(), date);

  Future<void> _jumpTo(DateTime date) async {
    if (!mounted) return;
    final page = _pageForDate(date).clamp(0, _basePage * 2);
    if (!_controller.hasClients) {
      await context.read<TaskStore>().selectDate(date);
      return;
    }
    if (MediaQuery.reduceMotionOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _controller.jumpToPage(page);
      return;
    }
    await _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openCalendar() async {
    final store = context.read<TaskStore>();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
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
        await WidgetSync.drainPendingToggles(tasks, reportErrors: true);
      },
      rescheduleReminder: TaskNotifier.instance.reschedule,
      pushWidget: () => WidgetSync.push(reportErrors: true),
    );
    _dayReviewOpen = true;
    try {
      await showDayReviewSheet(context, date: date, service: service);
    } finally {
      _dayReviewOpen = false;
    }
  }

  Future<void> createNote() => _openEditor();

  Future<void> _openEditor({Task? task}) async {
    final store = context.read<TaskStore>();
    final result = await showModalBottomSheet<TaskEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (context) =>
          TaskEditorSheet(task: task, initialDate: store.selectedDate),
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

    final isNew = task == null;
    if (isNew) {
      await store.add(saved);
      await TaskNotifier.instance.schedule(saved);
    } else {
      await store.update(saved);
      await TaskNotifier.instance.reschedule(saved);
    }
    await WidgetSync.push();
    if (!mounted) return;
    await _jumpTo(saved.date);
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
      await TaskNotifier.instance.cancel(task.id);
    } else {
      if (settings.soundEnabled) SoundFx.play(settings.soundUncheck);
      await TaskNotifier.instance.schedule(updated);
    }
    await WidgetSync.push();
  }

  Future<void> _openFromWidget(Uri? uri) async {
    if (uri == null || uri.scheme != 'ohmyesok') return;

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
      if (date != null) await _jumpTo(dateOnly(date));
      return;
    }

    if (uri.host != 'task' || uri.pathSegments.isEmpty) return;
    final store = context.read<TaskStore>();
    final task = await store.taskById(uri.pathSegments.first);
    if (task == null || !mounted) return;
    await _jumpTo(task.date);
    if (!mounted) return;
    await _openEditor(task: task);
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
      period: EsokPeriodHeader(
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
      child: PageView.builder(
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
            onOpen: (task) => _openEditor(task: task),
            onCloseDay: () => _openDayReview(date),
            onJumpToday: () => _jumpTo(today()),
            onJumpNext: () => _jumpTo(date.add(const Duration(days: 1))),
            onOpenMoney: widget.onOpenMoney,
          );
        },
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
    required this.onCloseDay,
    required this.onJumpToday,
    required this.onJumpNext,
    this.onOpenMoney,
  });

  final DateTime date;
  final int revision;
  final bool atEarliest;
  final Future<void> Function(Task) onToggle;
  final ValueChanged<Task> onOpen;
  final VoidCallback onCloseDay;
  final VoidCallback onJumpToday;
  final VoidCallback onJumpNext;
  final VoidCallback? onOpenMoney;

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
    final colors = EsokColors.of(context);
    return FutureBuilder<_DayData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }
        final tasks = data.tasks;
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onCloseDay,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.ink,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Tutup hari'),
                ),
              ],
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Belum ada catatan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  '${tasks.length - undone} dari ${tasks.length} selesai',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final (index, task) in tasks.indexed)
                EsokGroupedRow(
                  key: ValueKey(task.id),
                  first: index == 0,
                  last: index == tasks.length - 1,
                  child: _TaskRow(
                    task: task,
                    showDivider: index != tasks.length - 1,
                    onToggle: () => widget.onToggle(task),
                    onOpen: () => widget.onOpen(task),
                  ),
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
            const SizedBox(height: 24),
            DayMoneySection(date: widget.date, onOpenMoney: widget.onOpenMoney),
          ],
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
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
    final duration =
        MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.reduceMotionOf(context) ||
            MediaQuery.accessibleNavigationOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 100);
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
              InkWell(
                onTap: onToggle,
                child: SizedBox(
                  width: 48,
                  height: 56,
                  child: Center(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: Curves.easeOutQuart,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isDone ? checkedColor : Colors.transparent,
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
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        0,
                        8,
                        12,
                        8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              curve: Curves.easeOutQuart,
                              style: titleStyle,
                              child: Text(task.title),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeText(task.scheduledTime),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.muted,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                child: RichText(
                  text: TextSpan(
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
