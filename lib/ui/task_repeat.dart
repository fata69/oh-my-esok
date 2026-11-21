import 'package:material_ui/material_ui.dart';

import '../util/format.dart';
import 'motion.dart';
import 'theme.dart';

enum TaskRepeatMode {
  once('Tidak berulang'),
  daily('Setiap hari'),
  workdays('Senin–Jumat'),
  weekly('Setiap minggu'),
  custom('Pilih hari');

  const TaskRepeatMode(this.label);

  final String label;
}

class TaskRepeatRule {
  const TaskRepeatRule(this.mode, [this.days = const []]);

  factory TaskRepeatRule.fromWeekdays(List<int> weekdays, DateTime date) {
    if (weekdays.isEmpty) return const TaskRepeatRule(TaskRepeatMode.once);
    if (weekdays.length == 7) return const TaskRepeatRule(TaskRepeatMode.daily);
    if (weekdays.length == 5 && _workdays.every(weekdays.contains)) {
      return const TaskRepeatRule(TaskRepeatMode.workdays);
    }
    if (weekdays.length == 1 && weekdays.single == date.weekday) {
      return const TaskRepeatRule(TaskRepeatMode.weekly);
    }
    return TaskRepeatRule(TaskRepeatMode.custom, weekdays);
  }

  static const _allDays = [1, 2, 3, 4, 5, 6, 7];
  static const _workdays = [1, 2, 3, 4, 5];
  static const _days = [
    ('Sen', 'Senin'),
    ('Sel', 'Selasa'),
    ('Rab', 'Rabu'),
    ('Kam', 'Kamis'),
    ('Jum', 'Jumat'),
    ('Sab', 'Sabtu'),
    ('Min', 'Minggu'),
  ];

  final TaskRepeatMode mode;
  final List<int> days;

  List<int> weekdaysFor(DateTime date) => switch (mode) {
    TaskRepeatMode.once => const [],
    TaskRepeatMode.daily => _allDays,
    TaskRepeatMode.workdays => _workdays,
    TaskRepeatMode.weekly => [date.weekday],
    TaskRepeatMode.custom => _allDays.where(days.contains).toList(),
  };

  String summary(DateTime date, {bool compact = false}) => switch (mode) {
    TaskRepeatMode.weekly =>
      compact
          ? 'Setiap ${_days[date.weekday - 1].$2}'
          : 'Setiap minggu pada ${_days[date.weekday - 1].$2}',
    TaskRepeatMode.custom =>
      days.isEmpty
          ? 'Pilih minimal satu hari'
          : compact
          ? weekdaysFor(date).map((day) => _days[day - 1].$1).join(', ')
          : 'Setiap ${weekdaysFor(date).map((day) => _days[day - 1].$2).join(', ')}',
    _ => mode.label,
  };
}

Future<TaskRepeatRule?> showTaskRepeatPicker(
  BuildContext context, {
  required TaskRepeatRule current,
  required DateTime date,
  required String? time,
}) {
  return showModalBottomSheet<TaskRepeatRule>(
    context: context,
    sheetAnimationStyle: EsokMotion.presentation(context),
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: EsokColors.of(context).canvas,
    barrierColor: EsokColors.scrim,
    builder: (_) => _RepeatPicker(current: current, date: date, time: time),
  );
}

class _RepeatPicker extends StatefulWidget {
  const _RepeatPicker({
    required this.current,
    required this.date,
    required this.time,
  });

  final TaskRepeatRule current;
  final DateTime date;
  final String? time;

  @override
  State<_RepeatPicker> createState() => _RepeatPickerState();
}

class _RepeatPickerState extends State<_RepeatPicker> {
  late TaskRepeatMode _mode = widget.current.mode;
  late final Set<int> _days = widget.current.days.toSet();

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    final draft = TaskRepeatRule(_mode, _days.toList());
    final valid = _mode != TaskRepeatMode.custom || _days.isNotEmpty;
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
                    child: Text('Ulangi', style: text.titleLarge),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Kembali ke editor',
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final mode in TaskRepeatMode.values) ...[
                    if (mode != TaskRepeatMode.once) const Divider(height: 1),
                    _RepeatOption(
                      mode: mode,
                      selected: mode == _mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                  ],
                ],
              ),
            ),
            if (_mode == TaskRepeatMode.custom) ...[
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text('Hari dalam seminggu', style: text.titleSmall),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 6.0;
                  final columns =
                      MediaQuery.textScalerOf(context).scale(14) > 20 ? 3 : 4;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final day in TaskRepeatRule._allDays)
                        SizedBox(
                          width: width,
                          child: _RepeatDay(
                            day: day,
                            selected: _days.contains(day),
                            onTap: () => setState(() {
                              if (!_days.remove(day)) _days.add(day);
                            }),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                draft.summary(widget.date) +
                    (valid && widget.time != null
                        ? ' · ${timeText(widget.time)}'
                        : ''),
                style: text.bodySmall?.copyWith(color: colors.muted),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(context, draft) : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatOption extends StatelessWidget {
  const _RepeatOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TaskRepeatMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    const weeklyHint = 'Mengikuti hari pada tanggal mulai';
    final weekly = mode == TaskRepeatMode.weekly;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: mode.label,
      hint: weekly ? weeklyHint : null,
      onTap: onTap,
      excludeSemantics: true,
      child: ColoredBox(
        color: selected ? colors.selected : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.label,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: selected ? FontWeight.w700 : null,
                          ),
                        ),
                        if (weekly)
                          Text(
                            weeklyHint,
                            style: text.bodySmall?.copyWith(
                              color: colors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    child: selected ? const Icon(Icons.check, size: 18) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatDay extends StatelessWidget {
  const _RepeatDay({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final (short, full) = TaskRepeatRule._days[day - 1];
    return Semantics(
      button: true,
      selected: selected,
      label: full,
      onTap: onTap,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? colors.onAction : colors.ink,
          backgroundColor: selected ? colors.action : colors.control,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(short),
      ),
    );
  }
}
