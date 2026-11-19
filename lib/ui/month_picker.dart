import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../util/format.dart';
import 'tab_layout.dart';
import 'theme.dart';

class EsokMonthHeader extends StatelessWidget {
  const EsokMonthHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => EsokPeriodHeader(
    title: monthTitle(month),
    previousLabel: 'Bulan sebelumnya',
    nextLabel: 'Bulan berikutnya',
    selectLabel: 'Pilih bulan',
    onPrevious: onPrevious,
    onNext: onNext,
    onSelect: () async {
      final selected = await showEsokPickerSheet<DateTime>(
        context,
        builder: (_) => _MonthPicker(month: month),
      );
      if (selected != null && context.mounted) onSelected(selected);
    },
  );
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.month});

  final DateTime month;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  final _now = DateTime.now();
  final _monthName = DateFormat.MMMM('id_ID');
  final _shortMonth = DateFormat.MMM('id_ID');
  late int _year = widget.month.year;
  late final int _firstYear = math.min(widget.month.year, _now.year - 100);
  late final int _lastYear = math.max(widget.month.year, _now.year + 50);
  bool _pickYear = false;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return EsokPickerSheet(
      title: _pickYear ? 'Pilih tahun' : 'Pilih bulan',
      footer: _pickYear
          ? null
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.ink,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => _select(context, _now.year, _now.month),
              child: const Text('Bulan ini'),
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EsokPeriodHeader(
                title: '$_year',
                previousLabel: 'Tahun sebelumnya',
                nextLabel: 'Tahun berikutnya',
                selectLabel: _pickYear ? 'Kembali ke bulan' : 'Pilih tahun',
                onPrevious: _year > _firstYear ? () => _shiftYear(-1) : null,
                onNext: _year < _lastYear ? () => _shiftYear(1) : null,
                onSelect: () => setState(() => _pickYear = !_pickYear),
              ),
              if (_pickYear)
                SizedBox(
                  height: 208,
                  child: YearPicker(
                    key: ValueKey(_year),
                    firstDate: DateTime(_firstYear),
                    lastDate: DateTime(_lastYear, 12),
                    selectedDate: DateTime(_year),
                    onChanged: (date) => setState(() {
                      _year = date.year;
                      _pickYear = false;
                    }),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 4.0;
                    final minWidth =
                        54 * MediaQuery.textScalerOf(context).scale(13) / 13;
                    final count =
                        ((constraints.maxWidth + gap) / (minWidth + gap))
                            .floor()
                            .clamp(1, 4);
                    final width =
                        (constraints.maxWidth - gap * (count - 1)) / count;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var month = 1; month <= 12; month++)
                          SizedBox(
                            width: width,
                            child: _monthButton(context, month),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _shiftYear(int delta) => setState(() => _year += delta);

  void _select(BuildContext context, int year, int month) =>
      Navigator.of(context).pop(DateTime(year, month));

  Widget _monthButton(BuildContext context, int month) {
    final colors = EsokColors.of(context);
    final selected = _year == widget.month.year && month == widget.month.month;
    final date = DateTime(_year, month);
    return Semantics(
      container: true,
      selected: selected,
      label: '${_monthName.format(date)} $_year',
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
          foregroundColor: colors.ink,
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onPressed: () => _select(context, _year, month),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: selected
              ? BoxDecoration(
                  color: colors.control,
                  borderRadius: BorderRadius.circular(18),
                )
              : null,
          child: ExcludeSemantics(
            child: Text(_shortMonth.format(date), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
