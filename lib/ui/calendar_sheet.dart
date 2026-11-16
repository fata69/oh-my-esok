import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/task.dart';
import '../state/task_store.dart';
import '../util/format.dart';
import 'chevron.dart';
import 'theme.dart';

class CalendarSheet extends StatefulWidget {
  const CalendarSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<CalendarSheet> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(widget.initialDate);
    _month = DateTime(_selected.year, _selected.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskStore>().loadMonth(_month);
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    context.read<TaskStore>().loadMonth(_month);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: 560 + bottomInset,
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: EsokColors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  monthTitle(_month),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01,
                    color: EsokColors.ink,
                  ),
                ),
              ),
              _MonthArrow(left: true, onTap: () => _changeMonth(-1)),
              _MonthArrow(left: false, onTap: () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.06,
                        color: EsokColors.muted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 46,
            ),
            itemCount: cells,
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              final date = DateTime(_month.year, _month.month, dayNumber);
              final inMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
              final isToday = dateOnly(date) == today();
              final isSelected = dateOnly(date) == _selected;
              final count = store.countFor(date);

              return _DayCell(
                date: date,
                number: date.day,
                dim: !inMonth,
                isToday: isToday,
                isSelected: isSelected,
                hasTasks: count > 0,
                onTap: () => Navigator.of(context).pop(dateOnly(date)),
              );
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(today()),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Kembali ke hari ini',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Tutup',
                    style: TextStyle(fontSize: 12.5, color: EsokColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.left, required this.onTap});

  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(child: EsokChevron(left: left, size: 17)),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.number,
    required this.dim,
    required this.isToday,
    required this.isSelected,
    required this.hasTasks,
    required this.onTap,
  });

  final DateTime date;
  final int number;
  final bool dim;
  final bool isToday;
  final bool isSelected;
  final bool hasTasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = dim ? EsokColors.muted : EsokColors.ink;
    final dotColor = isSelected
        ? EsokColors.canvas
        : EsokColors.chevron;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? EsokColors.ink : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: EsokColors.ink, width: 1.5)
                  : null,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 14.5,
                color: isSelected ? EsokColors.canvas : baseColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasTasks ? dotColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
