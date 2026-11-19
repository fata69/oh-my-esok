import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task.dart';
import '../state/task_store.dart';
import '../util/format.dart';
import 'tab_layout.dart';
import 'theme.dart';

class CalendarSheet extends StatefulWidget {
  const CalendarSheet({
    super.key,
    required this.initialDate,
    this.title = 'Pilih tanggal',
    this.lockToInitialMonth = false,
    this.showAgenda = true,
  });

  final DateTime initialDate;
  final String title;
  final bool lockToInitialMonth;
  final bool showAgenda;

  @override
  State<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<CalendarSheet> {
  late DateTime _month;
  late final DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(widget.initialDate);
    _month = DateTime(_selected.year, _selected.month);
    if (widget.showAgenda) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<TaskStore>().loadMonth(_month);
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    if (widget.showAgenda) context.read<TaskStore>().loadMonth(_month);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.showAgenda ? context.watch<TaskStore>() : null;
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (_month.weekday + 6) % 7;
    final weeks = (leading + daysInMonth + 6) ~/ 7;
    final todayDate = today();
    final canSelectToday =
        !widget.lockToInitialMonth ||
        DateTime(todayDate.year, todayDate.month) == first;
    final textScaler = MediaQuery.textScalerOf(context);
    final dayMarkerSize = (textScaler.scale(14) * 1.4 + 10).clamp(34.0, 50.0);
    return EsokPickerSheet(
      title: widget.title,
      footer: canSelectToday
          ? TextButton(
              onPressed: () => Navigator.pop(context, todayDate),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Kembali ke hari ini'),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EsokPeriodHeader(
            title: monthTitle(first),
            previousLabel: 'Bulan sebelumnya',
            nextLabel: 'Bulan berikutnya',
            selectLabel: '',
            onPrevious: widget.lockToInitialMonth
                ? null
                : () => _changeMonth(-1),
            onNext: widget.lockToInitialMonth ? null : () => _changeMonth(1),
            onSelect: null,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final weekday in const [
                'Sen',
                'Sel',
                'Rab',
                'Kam',
                'Jum',
                'Sab',
                'Min',
              ])
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      textScaler.scale(10) >= 28 ? weekday[0] : weekday,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < weeks; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _dayCell(
                      DateTime(
                        _month.year,
                        _month.month,
                        week * 7 + weekday - leading + 1,
                      ),
                      todayDate: todayDate,
                      store: store,
                      side: dayMarkerSize,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    DateTime date, {
    required DateTime todayDate,
    required TaskStore? store,
    required double side,
  }) {
    final outsideMonth = date.month != _month.month;
    if (outsideMonth && widget.lockToInitialMonth) {
      return const SizedBox.shrink();
    }
    return _DayCell(
      date: date,
      side: side,
      dim: outsideMonth,
      isToday: date == todayDate,
      isSelected: date == _selected,
      taskCount: store?.countFor(date) ?? 0,
      onTap: () => Navigator.pop(context, date),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.side,
    required this.dim,
    required this.isToday,
    required this.isSelected,
    required this.taskCount,
    required this.onTap,
  });

  final DateTime date;
  final double side;
  final bool dim;
  final bool isToday;
  final bool isSelected;
  final int taskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme.bodyMedium;
    final ink = isSelected
        ? colors.onAction
        : dim
        ? colors.muted
        : colors.ink;
    final label =
        '${weekdayName(date)}, ${dateTitle(date)} ${date.year}'
        '${isToday ? ', Hari ini' : ''}'
        '${taskCount > 0 ? ', $taskCount agenda' : ''}';
    return Semantics(
      container: true,
      label: label,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: side,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: isSelected ? colors.action : null,
                        shape: CircleBorder(
                          side: isToday && !isSelected
                              ? BorderSide(color: colors.outline, width: 1.5)
                              : BorderSide.none,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          maxLines: 1,
                          style: text?.copyWith(
                            color: ink,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox.square(
                    dimension: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: taskCount > 0 ? colors.ink : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
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
