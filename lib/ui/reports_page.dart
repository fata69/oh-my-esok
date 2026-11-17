import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/money_report.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../util/format.dart';
import 'report_chart.dart';
import 'tab_layout.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final report = store.monthReport;
    final theme = Theme.of(context);
    final hidden = context.watch<SettingsStore?>()?.hideAmounts ?? false;
    return EsokTabLayout(
      child: ListView(
        key: const PageStorageKey('reports'),
        padding: EdgeInsets.fromLTRB(
          EsokTabLayout.gutter,
          0,
          EsokTabLayout.gutter,
          EsokTabLayout.scrollBottomOf(context),
        ),
        children: [
          EsokPeriodHeader(
            title: monthTitle(report.month),
            previousLabel: 'Bulan sebelumnya',
            nextLabel: 'Bulan berikutnya',
            onPrevious: store.previousMonth,
            onNext: store.nextMonth,
          ),
          const SizedBox(height: 12),
          Text('Selisih bulan', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            hidden ? '••••' : reportAmount(report.net),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pemasukan dikurangi pengeluaran',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ReportAmounts(
            income: report.income,
            expense: report.expense,
            incomeColor: reportIncomeColor(theme.brightness),
            expenseColor: reportExpenseColor(theme.brightness),
            hidden: hidden,
          ),
          if (!hidden && report.transactionCount == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Belum ada arus kas bulan ini.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          _ReportSection(
            'Tren 6 bulan',
            subtitle: hidden
                ? null
                : 'Ketuk atau geser grafik untuk memilih bulan',
          ),
          if (hidden)
            const _HiddenChart()
          else
            ReportFlowChart(
              monthly: true,
              key: const ValueKey('report-trend'),
              points: [
                for (final point in report.trend)
                  (
                    date: point.month,
                    income: point.income,
                    expense: point.expense,
                  ),
              ],
            ),
          const _ReportSection('Arus kas harian'),
          if (hidden)
            const _HiddenChart()
          else ...[
            ReportFlowChart(
              key: const ValueKey('report-daily'),
              monthly: false,
              points: [
                for (final day in report.daily)
                  (date: day.date, income: day.income, expense: day.expense),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const PageStorageKey('report-daily-details'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Rincian per hari'),
              children: [
                for (final day in report.daily) ...[
                  const Divider(height: 16),
                  _DayDetail(day: day),
                ],
              ],
            ),
          ],
          const _ReportSection('Pengeluaran per kategori'),
          hidden
              ? const _HiddenChart()
              : _CategoryBreakdown(categories: report.expensesByCategory),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

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
          Semantics(
            header: true,
            child: Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: text.bodyMedium),
          ],
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
