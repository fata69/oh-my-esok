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
    if (oldWidget.points.last.date != widget.points.last.date) _selected = null;
  }

  void _select(int index) {
    if (index == (_selected ?? widget.points.length - 1)) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final selected = _selected ?? points.length - 1;
    final current = points[selected];
    final theme = Theme.of(context);
    final income = reportIncomeColor(theme.brightness);
    final expense = reportExpenseColor(theme.brightness);
    final monthFormat = DateFormat('MMM', 'id_ID');
    final heading = widget.monthly
        ? DateFormat('MMM yyyy', 'id_ID').format(current.date)
        : DateFormat('d MMMM yyyy', 'id_ID').format(current.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                heading,
                key: const ValueKey('report-point-date'),
                style: theme.textTheme.titleMedium,
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
        const SizedBox(height: 8),
        ReportAmounts(
          income: current.income,
          expense: current.expense,
          incomeColor: income,
          expenseColor: expense,
        ),
        const SizedBox(height: 15),
        if (points.every((point) => point.income == 0 && point.expense == 0))
          Text(
            widget.monthly
                ? 'Belum ada arus kas dalam enam bulan.'
                : 'Belum ada arus kas harian.',
            style: theme.textTheme.bodyMedium,
          )
        else
          ExcludeSemantics(
            child: _FlowPlot(
              points: points,
              selected: selected,
              monthly: widget.monthly,
              income: income,
              expense: expense,
              onSelect: _select,
            ),
          ),
        if (widget.monthly) ...[
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final minWidth = math.max(
                48.0,
                MediaQuery.textScalerOf(context).scale(34),
              );
              final plotWidth = box.maxWidth - _axisGutterOf(context);
              final widthAvailable = plotWidth >= minWidth * points.length
                  ? plotWidth
                  : box.maxWidth;
              final columns = (widthAvailable / minWidth).floor().clamp(
                1,
                points.length,
              );
              // Keep equal cells offset by the axis gutter when they all fit.
              final width = (widthAvailable / columns).floorToDouble();
              return Wrap(
                children: [
                  for (var i = 0; i < points.length; i++)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        excludeSemantics: true,
                        button: true,
                        selected: i == selected,
                        label: monthTitle(points[i].date),
                        value:
                            'Pemasukan ${reportAmount(points[i].income)}, '
                            'Pengeluaran ${reportAmount(points[i].expense)}',
                        onTap: () => _select(i),
                        child: TextButton(
                          key: ValueKey('report-month-$i'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 48),
                            foregroundColor: i == selected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => _select(i),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthFormat.format(points[i].date),
                                style: TextStyle(
                                  fontWeight: i == selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 16,
                                height: 2,
                                child: ColoredBox(
                                  color: i == selected
                                      ? income
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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

class _FlowPlot extends StatelessWidget {
  const _FlowPlot({
    required this.points,
    required this.selected,
    required this.monthly,
    required this.income,
    required this.expense,
    required this.onSelect,
  });

  final List<ReportFlowPoint> points;
  final int selected;
  final bool monthly;
  final Color income;
  final Color expense;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final axis = _ReportAxis(points);
    final compact = NumberFormat.compact(locale: 'id_ID');
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: c.onSurfaceVariant,
    );
    final plotHeight = math.max(
      146.0,
      MediaQuery.textScalerOf(context).scale(11) * 10,
    );
    final axisPadding = MediaQuery.textScalerOf(context).scale(8);
    final axisWidth = _axisGutterOf(context) - 8;
    final last = points.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rupiah', style: axisStyle),
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
                      final width = math.min(monthly ? 24.0 : 7.0, slot * .52);
                      void snap(double x) =>
                          onSelect((x / slot).floor().clamp(0, last));

                      BarChartGroupData group(int i) {
                        final inbound = points[i].income.toDouble();
                        final outbound = -points[i].expense.toDouble();
                        // Imported negatives can put both effects on the same side.
                        // Separate those marks so neither amount hides the other.
                        final separate =
                            (inbound > 0 && outbound > 0) ||
                            (inbound < 0 && outbound < 0);
                        final gap = width * .12;
                        final barWidth = separate ? (width - gap) / 2 : width;
                        BarChartRodData rod(double value, Color color) {
                          // fl_chart extends rods shorter than their radius.
                          // Cap the radius so a small amount keeps its scale.
                          final trueHeight =
                              value.abs() / (axis.high - axis.low) * plotHeight;
                          final round = Radius.circular(
                            math.min(barWidth / 2, trueHeight),
                          );
                          return BarChartRodData(
                            toY: value,
                            width: barWidth,
                            color: value == 0 ? Colors.transparent : color,
                            borderRadius: value < 0
                                ? BorderRadius.vertical(bottom: round)
                                : BorderRadius.vertical(top: round),
                          );
                        }

                        return BarChartGroupData(
                          x: i,
                          groupVertically: !separate,
                          barsSpace: gap,
                          barRods: [
                            rod(inbound, income),
                            rod(outbound, expense),
                          ],
                        );
                      }

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
                              left: selected * slot + slot * .06,
                              width: slot * .88,
                              top: 0,
                              bottom: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.onSurface.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                barGroups: [
                                  for (var i = 0; i < points.length; i++)
                                    group(i),
                                ],
                                baselineY: 0,
                                minY: axis.low,
                                maxY: axis.high,
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  drawVerticalLine: false,
                                  horizontalInterval: axis.step,
                                  getDrawingHorizontalLine: (_) => FlLine(
                                    color: c.outlineVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                    strokeWidth: 1,
                                  ),
                                ),
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: 0,
                                      color: c.outline,
                                      strokeWidth: 1,
                                    ),
                                  ],
                                ),
                                barTouchData: const BarTouchData(
                                  enabled: false,
                                ),
                              ),
                              // Scrubbing and opening another month must never interpolate values.
                              duration: Duration.zero,
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
        if (!monthly)
          Padding(
            padding: EdgeInsets.only(right: axisWidth + 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1', style: axisStyle),
                Text('${points.length}', style: axisStyle),
              ],
            ),
          ),
      ],
    );
  }
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
