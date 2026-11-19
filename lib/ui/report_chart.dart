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

/// The selected interval is readable and can be stepped through with buttons.
class ReportFlowChart extends StatefulWidget {
  const ReportFlowChart({
    super.key,
    required this.points,
    required this.monthly,
    required this.rangeControls,
  });

  final List<ReportFlowPoint> points;
  final bool monthly;
  final Widget rangeControls;

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

  int get _defaultIndex {
    final points = widget.points;
    final lastActive = points.lastIndexWhere(
      (point) => point.income != 0 || point.expense != 0,
    );
    return widget.monthly || lastActive < 0 ? points.length - 1 : lastActive;
  }

  void _select(int index) {
    if (index == (_selected ?? _defaultIndex)) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    if (points.isEmpty ||
        points.every((point) => point.income == 0 && point.expense == 0)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              widget.monthly
                  ? 'Belum ada arus kas dalam enam bulan.'
                  : 'Belum ada arus kas harian.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          widget.rangeControls,
        ],
      );
    }
    final selected = _selected ?? _defaultIndex;
    final current = points[selected];
    final income = reportIncomeColor(theme.brightness);
    final expense = reportExpenseColor(theme.brightness);
    final heading = DateFormat(
      widget.monthly ? 'MMMM yyyy' : 'd MMMM yyyy',
      'id_ID',
    ).format(current.date);
    final net = current.income - current.expense;
    final unit = widget.monthly ? 'Bulan' : 'Hari';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Selisih · $heading',
          key: const ValueKey('report-point-date'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Semantics(
          container: true,
          liveRegion: true,
          label:
              '$heading, selisih ${reportAmount(net)}, '
              'pemasukan ${reportAmount(current.income)}, '
              'pengeluaran ${reportAmount(current.expense)}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                net > 0 ? '+${reportAmount(net)}' : reportAmount(net),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 10),
              ReportAmounts(
                income: current.income,
                expense: current.expense,
                incomeColor: income,
                expenseColor: expense,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: widget.rangeControls),
            IconButton(
              tooltip: '$unit sebelumnya pada grafik',
              onPressed: selected == 0 ? null : () => _select(selected - 1),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
            ),
            IconButton(
              tooltip: '$unit berikutnya pada grafik',
              onPressed: selected == points.length - 1
                  ? null
                  : () => _select(selected + 1),
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

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
    final colors = EsokColors.of(context);
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scale = MediaQuery.textScalerOf(context);
    final axis = _ReportAxis(points);
    final compact = NumberFormat.compact(locale: 'id_ID');
    final monthLabel = DateFormat('MMM', 'id_ID');
    final ticks = [
      for (final tick in axis.ticks)
        (tick, tick < 0 ? '−${compact.format(-tick)}' : compact.format(tick)),
    ];
    final tickWidth = scale.scale(48).clamp(42.0, 86.0);
    final tickHeight = scale.scale(15);
    final plotHeight = math.max(156.0, tickHeight * (ticks.length + 1));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / points.length;
              final focusX = (selected + .5) * slot;
              final labelWidth = scale
                  .scale(monthly ? 34 : 25)
                  .clamp(20.0, 48.0);
              final indexes = monthly
                  ? slot >= labelWidth
                        ? List.generate(points.length, (i) => i)
                        : [0, points.length ~/ 2, points.length - 1]
                  : [0, 9, 19, points.length - 1];
              void snap(double x) =>
                  onSelect((x / slot).floor().clamp(0, points.length - 1));
              String labelFor(int index) => monthly
                  ? monthLabel.format(points[index].date)
                  : '${points[index].date.day}';
              return Column(
                children: [
                  SizedBox(
                    height: plotHeight + tickHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: tickHeight / 2),
                      child: GestureDetector(
                        key: const ValueKey('report-scrub'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => snap(details.localPosition.dx),
                        onHorizontalDragStart: (details) =>
                            snap(details.localPosition.dx),
                        onHorizontalDragUpdate: (details) =>
                            snap(details.localPosition.dx),
                        onLongPressStart: (details) =>
                            snap(details.localPosition.dx),
                        onLongPressMoveUpdate: (details) =>
                            snap(details.localPosition.dx),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: focusX - .5,
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(
                                color: colors.outline,
                                child: const SizedBox(width: 1),
                              ),
                            ),
                            _volumeBars(
                              colors: colors,
                              axis: axis,
                              points: points,
                              plotHeight: plotHeight,
                              rodWidth: math.min(monthly ? 22 : 8, slot * .65),
                              income: income,
                              expense: expense,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: tickHeight + 10,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final index in {...indexes, selected})
                          if (index == selected ||
                              ((index - selected).abs() * slot >= labelWidth))
                            Positioned(
                              top: 0,
                              left: (index + .5) * slot - labelWidth / 2,
                              width: labelWidth,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: index == selected
                                        ? colors.selected
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 3,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        labelFor(index),
                                        maxLines: 1,
                                        style: index == selected
                                            ? style.copyWith(color: colors.ink)
                                            : style,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: tickWidth,
          height: plotHeight + tickHeight,
          child: Stack(
            children: [
              for (final (tick, label) in ticks)
                Positioned(
                  top: (axis.high - tick) / (axis.high - axis.low) * plotHeight,
                  left: 0,
                  right: 0,
                  height: tickHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(label, style: style),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

BarChart _volumeBars({
  required EsokPalette colors,
  required _ReportAxis axis,
  required List<ReportFlowPoint> points,
  required double plotHeight,
  required double rodWidth,
  required Color income,
  required Color expense,
}) {
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: [
        for (final (index, point) in points.indexed)
          BarChartGroupData(
            x: index,
            barRods: [
              _volumeRod(
                net: (point.income - point.expense).toDouble(),
                axis: axis,
                plotHeight: plotHeight,
                rodWidth: rodWidth,
                income: income,
                expense: expense,
              ),
            ],
          ),
      ],
      baselineY: 0,
      minY: axis.low,
      maxY: axis.high,
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: axis.step,
        getDrawingHorizontalLine: (_) => FlLine(color: colors.line),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(y: 0, color: colors.outline, strokeWidth: 1),
        ],
      ),
      barTouchData: const BarTouchData(enabled: false),
    ),
    duration: Duration.zero,
  );
}

BarChartRodData _volumeRod({
  required double net,
  required _ReportAxis axis,
  required double plotHeight,
  required double rodWidth,
  required Color income,
  required Color expense,
}) {
  final length = net.abs() / (axis.high - axis.low) * plotHeight;
  final radius = Radius.circular(math.min(rodWidth * .15, length));
  return BarChartRodData(
    fromY: 0,
    toY: net,
    width: rodWidth,
    color: net > 0
        ? income
        : net < 0
        ? expense
        : Colors.transparent,
    borderRadius: net < 0
        ? BorderRadius.vertical(bottom: radius)
        : BorderRadius.vertical(top: radius),
  );
}

class _ReportAxis {
  factory _ReportAxis(List<ReportFlowPoint> points) {
    var low = 0;
    var high = 0;
    for (final point in points) {
      final net = point.income - point.expense;
      low = math.min(low, net);
      high = math.max(high, net);
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
