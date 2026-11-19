import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../util/format.dart';
import 'theme.dart';

typedef ReportFlowPoint = ({DateTime date, int income, int expense});

Color reportIncomeColor(Brightness brightness) =>
    EsokColors.incomeInk(brightness);

Color reportExpenseColor(Brightness brightness) =>
    EsokColors.expenseInk(brightness);

String reportAmount(int amount) =>
    amount < 0 ? '−${rupiahText(-amount)}' : rupiahText(amount);

/// Leaves the painter out of the accessibility tree. All chart values are
/// reachable via the selected readout, month buttons or the page's day list.
class ReportFlowChart extends StatefulWidget {
  const ReportFlowChart({
    super.key,
    required this.points,
    required this.monthly,
  });

  final List<ReportFlowPoint> points;
  final bool monthly;

  @override
  State<ReportFlowChart> createState() => _ReportFlowChartState();
}

class _ReportFlowChartState extends State<ReportFlowChart> {
  int? _selected;

  @override
  void didUpdateWidget(ReportFlowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.lastOrNull?.date != widget.points.lastOrNull?.date) {
      _selected = null;
    }
  }

  void _select(int index) {
    if (index == (_selected ?? _defaultIndex)) return;
    setState(() => _selected = index);
  }

  int get _defaultIndex {
    final points = widget.points;
    final lastActive = points.lastIndexWhere(
      (point) => point.income != 0 || point.expense != 0,
    );
    return widget.monthly || lastActive < 0 ? points.length - 1 : lastActive;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final theme = Theme.of(context);
    if (points.isEmpty ||
        points.every((point) => point.income == 0 && point.expense == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          widget.monthly
              ? 'Belum ada arus kas dalam enam bulan.'
              : 'Belum ada arus kas harian.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final selected = _selected ?? _defaultIndex;
    final current = points[selected];
    final income = reportIncomeColor(theme.brightness);
    final expense = reportExpenseColor(theme.brightness);
    final heading = widget.monthly
        ? DateFormat('MMM yyyy', 'id_ID').format(current.date)
        : DateFormat('d MMMM yyyy', 'id_ID').format(current.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  heading,
                  key: const ValueKey('report-point-date'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (!widget.monthly) ...[
              IconButton(
                tooltip: 'Hari sebelumnya pada grafik',
                onPressed: selected == 0 ? null : () => _select(selected - 1),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              IconButton(
                tooltip: 'Hari berikutnya pada grafik',
                onPressed: selected == points.length - 1
                    ? null
                    : () => _select(selected + 1),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        ReportAmounts(
          income: current.income,
          expense: current.expense,
          incomeColor: income,
          expenseColor: expense,
        ),
        const SizedBox(height: 14),
        if (widget.monthly)
          _MonthlyPlot(
            points: points,
            selected: selected,
            income: income,
            expense: expense,
            onSelect: _select,
          )
        else
          ExcludeSemantics(
            child: _FlowPlot(
              points: points,
              selected: selected,
              income: income,
              expense: expense,
              onSelect: _select,
            ),
          ),
      ],
    );
  }
}

double _axisGutterOf(BuildContext context) =>
    8 + math.min(86.0, MediaQuery.textScalerOf(context).scale(48));

/// Exact amounts stay available as text, independently of the plot.
class ReportAmounts extends StatelessWidget {
  const ReportAmounts({
    super.key,
    required this.income,
    required this.expense,
    this.incomeColor,
    this.expenseColor,
    this.hidden = false,
  });

  final int income;
  final int expense;
  final Color? incomeColor;
  final Color? expenseColor;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final stack =
            box.maxWidth < 224 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final width = stack ? box.maxWidth : (box.maxWidth - 12) / 2;
        Widget item(String label, int amount, Color? color) => SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (color != null && !hidden) ...[
                    Icon(
                      label == 'Pemasukan'
                          ? Icons.south_west
                          : Icons.north_east,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(child: Text(label, style: t.labelMedium)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                hidden ? '••••' : reportAmount(amount),
                style: t.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: hidden ? null : color,
                ),
              ),
            ],
          ),
        );
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            item('Pemasukan', income, incomeColor),
            item('Pengeluaran', expense, expenseColor),
          ],
        );
      },
    );
  }
}

class _MonthlyPlot extends StatelessWidget {
  const _MonthlyPlot({
    required this.points,
    required this.selected,
    required this.income,
    required this.expense,
    required this.onSelect,
  });

  final List<ReportFlowPoint> points;
  final int selected;
  final Color income;
  final Color expense;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final labelStyle = theme.textTheme.bodyMedium!;
    final rowHeight = math.max(48.0, scale.scale(14) * 1.5 + 16);
    final labelWidth = math.max(54.0, scale.scale(13) * 3.5 + 10);
    final axis = _ReportAxis(points);
    final compact = NumberFormat.compact(locale: 'id_ID');
    final monthFormat = DateFormat('MMM', 'id_ID');
    final tickStyle = theme.textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: rowHeight * points.length,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: selected * rowHeight + 3,
                height: rowHeight - 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.control,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned.fill(
                left: labelWidth,
                right: 8,
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, box) => _volumeBars(
                      context,
                      axis: axis,
                      points: points,
                      valueWidth: box.maxWidth,
                      rodWidth: 12,
                      income: income,
                      expense: expense,
                      horizontal: true,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  for (final (index, point) in points.indexed)
                    SizedBox(
                      height: rowHeight,
                      width: double.infinity,
                      child: Semantics(
                        key: ValueKey('report-month-$index'),
                        button: true,
                        selected: selected == index,
                        label: monthTitle(point.date),
                        value:
                            'Pemasukan ${reportAmount(point.income)}, '
                            'Pengeluaran ${reportAmount(point.expense)}',
                        onTap: () => onSelect(index),
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => onSelect(index),
                          borderRadius: BorderRadius.circular(10),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: Text(
                                monthFormat.format(point.date),
                                style: labelStyle.copyWith(
                                  color: selected == index
                                      ? colors.ink
                                      : colors.muted,
                                  fontWeight: selected == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: labelWidth, right: 8, top: 4),
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, box) {
                final zero = -axis.low / (axis.high - axis.low);
                final gap = scale.scale(46);
                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(compact.format(axis.low), style: tickStyle),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(compact.format(axis.high), style: tickStyle),
                    ),
                    if (math.min(zero, 1 - zero) * box.maxWidth >= gap)
                      Align(
                        alignment: Alignment(2 * zero - 1, 0),
                        child: Text('0', style: tickStyle),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowPlot extends StatelessWidget {
  const _FlowPlot({
    required this.points,
    required this.selected,
    required this.income,
    required this.expense,
    required this.onSelect,
  });

  final List<ReportFlowPoint> points;
  final int selected;
  final Color income;
  final Color expense;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final axis = _ReportAxis(points);
    final compact = NumberFormat.compact(locale: 'id_ID');
    final axisStyle = theme.textTheme.labelSmall;
    final plotHeight = math.max(146.0, scale.scale(11) * 10);
    final axisPadding = scale.scale(8);
    final axisWidth = _axisGutterOf(context) - 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: plotHeight + 2 * axisPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: axisPadding),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final slot = box.maxWidth / points.length;
                      void snap(double x) => onSelect(
                        (x / slot).floor().clamp(0, points.length - 1),
                      );
                      return GestureDetector(
                        key: const ValueKey('report-scrub'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => snap(details.localPosition.dx),
                        onHorizontalDragStart: (details) =>
                            snap(details.localPosition.dx),
                        onHorizontalDragUpdate: (details) =>
                            snap(details.localPosition.dx),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: selected * slot,
                              width: slot,
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(color: colors.control),
                            ),
                            _volumeBars(
                              context,
                              axis: axis,
                              points: points,
                              valueWidth: plotHeight,
                              rodWidth: math.min(7, slot * .62),
                              income: income,
                              expense: expense,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: axisWidth,
                child: Stack(
                  children: [
                    for (final tick in axis.ticks)
                      Positioned(
                        top:
                            (axis.high - tick) /
                            (axis.high - axis.low) *
                            plotHeight,
                        left: 0,
                        right: 0,
                        height: 2 * axisPadding,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(compact.format(tick), style: axisStyle),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: axisWidth + 8),
          child: Stack(
            children: [
              for (final day in [1, 10, 20, points.length])
                Align(
                  alignment: Alignment(2 * (day - .5) / points.length - 1, 0),
                  child: Text('$day', style: axisStyle),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

BarChart _volumeBars(
  BuildContext context, {
  required _ReportAxis axis,
  required List<ReportFlowPoint> points,
  required double valueWidth,
  required double rodWidth,
  required Color income,
  required Color expense,
  bool horizontal = false,
}) {
  final colors = EsokColors.of(context);
  BarChartGroupData group(int index, ReportFlowPoint point) {
    final incoming = point.income.toDouble();
    final outgoing = -point.expense.toDouble();
    // Signed imports can put two effects on the same side of zero.
    final separate =
        (incoming > 0 && outgoing > 0) || (incoming < 0 && outgoing < 0);
    final gap = separate ? rodWidth * .16 : 0.0;
    final width = separate ? (rodWidth - gap) / 2 : rodWidth;
    BarChartRodData rod(double value, Color color) {
      final length = value.abs() / (axis.high - axis.low) * valueWidth;
      final radius = Radius.circular(math.min(width * .28, length));
      return BarChartRodData(
        fromY: 0,
        toY: value,
        width: width,
        color: value == 0 ? Colors.transparent : color,
        borderRadius: value < 0
            ? BorderRadius.vertical(bottom: radius)
            : BorderRadius.vertical(top: radius),
      );
    }

    return BarChartGroupData(
      x: index,
      groupVertically: !separate,
      barsSpace: gap,
      barRods: [rod(incoming, income), rod(outgoing, expense)],
    );
  }

  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: [
        for (final (index, point) in points.indexed) group(index, point),
      ],
      rotationQuarterTurns: horizontal ? 1 : 0,
      baselineY: 0,
      minY: axis.low,
      maxY: axis.high,
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: axis.step,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: colors.line.withValues(alpha: .65), strokeWidth: 1),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [HorizontalLine(y: 0, color: colors.outline)],
      ),
      barTouchData: const BarTouchData(enabled: false),
    ),
    duration: Duration.zero,
  );
}

class _ReportAxis {
  factory _ReportAxis(List<ReportFlowPoint> points) {
    var low = 0;
    var high = 0;
    for (final point in points) {
      low = math.min(low, math.min(point.income, -point.expense));
      high = math.max(high, math.max(point.income, -point.expense));
    }
    final target = math.max(1.0, (high.toDouble() - low.toDouble()) / 3);
    final magnitude = math
        .pow(10, (math.log(target) / math.ln10).floor())
        .toDouble();
    final step = [
      1,
      2,
      5,
      10,
    ].map((factor) => factor * magnitude).firstWhere((step) => step >= target);
    final minY = (low / step).floor() * step;
    final maxY = (high / step).ceil() * step;
    return _ReportAxis._(minY, maxY == minY ? minY + step : maxY, step);
  }

  const _ReportAxis._(this.low, this.high, this.step);

  final double low;
  final double high;
  final double step;
  List<double> get ticks => [
    for (var i = 0; i <= ((high - low) / step).round(); i++) high - i * step,
  ];
}
