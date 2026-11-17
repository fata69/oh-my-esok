import 'dart:math' as math;

import 'package:intl/intl.dart';
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
      final selected = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: EsokColors.of(context).canvas,
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
  final _format = DateFormat.MMMM('id_ID');
  late int _year = widget.month.year;
  late final int _firstYear = math.min(widget.month.year, _now.year - 100);
  late final int _lastYear = math.max(widget.month.year, _now.year + 50);
  bool _pickYear = false;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _pickYear ? 'Pilih tahun' : 'Pilih bulan',
                    style: text.titleLarge,
                  ),
                ),
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
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 6.0;
                      final minWidth =
                          92 * MediaQuery.textScalerOf(context).scale(13) / 13;
                      final count =
                          ((constraints.maxWidth + gap) / (minWidth + gap))
                              .floor()
                              .clamp(1, 3);
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
                  const SizedBox(height: 10),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: colors.ink),
                    onPressed: () => _select(context, _now.year, _now.month),
                    child: const Text('Bulan ini'),
                  ),
                ],
              ],
            ),
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
    return Semantics(
      selected: selected,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          backgroundColor: selected ? colors.control : null,
          foregroundColor: colors.ink,
          side: selected ? BorderSide(color: colors.outline) : null,
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onPressed: () => _select(context, _year, month),
        child: Text(
          _format.format(DateTime(_year, month)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
