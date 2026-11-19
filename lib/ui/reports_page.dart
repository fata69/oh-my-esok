import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/money_report.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../util/format.dart';
import 'month_picker.dart';
import 'report_chart.dart';
import 'tab_layout.dart';
import 'theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _ReportPeriod { months, days }

class _ReportsPageState extends State<ReportsPage> {
  _ReportPeriod _period = _ReportPeriod.months;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final report = store.monthReport;
    final hidden = context.watch<SettingsStore?>()?.hideAmounts ?? false;
    final daily = _period == _ReportPeriod.days;
    final colors = EsokColors.of(context);
    return EsokTabLayout(
      period: EsokMonthHeader(
        month: report.month,
        onPrevious: store.previousMonth,
        onNext: store.nextMonth,
        onSelected: store.setMonth,
      ),
      child: ListView(
        key: const PageStorageKey('reports'),
        padding: EdgeInsets.fromLTRB(
          EsokTabLayout.gutter,
          12,
          EsokTabLayout.gutter,
          EsokTabLayout.scrollBottomOf(context),
        ),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Arus kas',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (hidden) ...[
            const SizedBox(height: 14),
            const _HiddenChart(),
          ] else ...[
            ReportFlowChart(
              monthly: !daily,
              key: ValueKey(daily ? 'report-daily' : 'report-trend'),
              points: daily
                  ? [
                      for (final day in report.daily)
                        (
                          date: day.date,
                          income: day.income,
                          expense: day.expense,
                        ),
                    ]
                  : [
                      for (final point in report.trend)
                        (
                          date: point.month,
                          income: point.income,
                          expense: point.expense,
                        ),
                    ],
              rangeControls: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final (period, label) in const [
                    (_ReportPeriod.months, '6 bulan'),
                    (_ReportPeriod.days, 'Harian'),
                  ])
                    Semantics(
                      selected: _period == period,
                      inMutuallyExclusiveGroup: true,
                      child: TextButton(
                        onPressed: () => setState(() => _period = period),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(72, 48),
                          foregroundColor: _period == period
                              ? colors.ink
                              : colors.muted,
                          backgroundColor: _period == period
                              ? colors.control
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(label),
                      ),
                    ),
                ],
              ),
            ),
            if (daily && report.transactionCount != 0) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                key: const PageStorageKey('report-daily-details'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Rincian per hari'),
                children: [
                  for (final day in report.daily)
                    if (day.income != 0 || day.expense != 0) ...[
                      const Divider(height: 16),
                      _DayDetail(day: day),
                    ],
                ],
              ),
            ],
          ],
          _ReportSection(
            'Pengeluaran per kategori',
            period: DateFormat('MMM yyyy', 'id_ID').format(report.month),
          ),
          hidden
              ? const _HiddenChart()
              : _CategoryBreakdown(categories: report.expensesByCategory),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection(this.title, {required this.period});

  final String title;
  final String period;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(period, style: text.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final DailyMoneyTotal day;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          dateTitle(day.date),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 5),
        ReportAmounts(income: day.income, expense: day.expense),
      ],
    ),
  );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.categories});

  final List<CategoryExpenseTotal> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('Belum ada pengeluaran untuk bulan ini.');
    }
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final showShares = categories.any((entry) => entry.share > 0);
    final percent = NumberFormat('0.#', 'id_ID');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showShares) ...[
          Text(
            'Proporsi tidak ditampilkan karena total bertanda atau nol.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < categories.length; i++) ...[
          if (i != 0) const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(categories[i].name, style: theme.textTheme.bodyMedium),
              Text(
                showShares
                    ? '${reportAmount(categories[i].total)} · '
                          '${percent.format(categories[i].share * 100)}%'
                    : reportAmount(categories[i].total),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (showShares) ...[
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: ValueKey('report-allocation-$i'),
                  value: categories[i].share,
                  minHeight: 5,
                  color: c.onSurfaceVariant,
                  backgroundColor: c.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _HiddenChart extends StatelessWidget {
  const _HiddenChart();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.visibility_off_outlined),
      SizedBox(width: 10),
      Expanded(child: Text('Grafik dan nominal disembunyikan.')),
    ],
  );
}
