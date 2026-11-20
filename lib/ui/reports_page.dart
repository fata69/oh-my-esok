import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/money_report.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../util/format.dart';
import 'glass_controls.dart';
import 'manage_categories.dart';
import 'month_picker.dart';
import 'motion.dart';
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
          8,
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
          const SizedBox(height: 10),
          if (hidden)
            const EsokContentGroup(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: _HiddenChart(),
                ),
              ],
            )
          else ...[
            EsokContentGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: ReportFlowChart(
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
                    rangeControls: EsokSegmentedControl<_ReportPeriod>(
                      value: _period,
                      onChanged: (period) => setState(() => _period = period),
                      segments: const [
                        (_ReportPeriod.months, '6 bulan'),
                        (_ReportPeriod.days, 'Harian'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (daily && report.transactionCount != 0) ...[
              const SizedBox(height: 12),
              EsokContentGroup(
                children: [
                  ExpansionTile(
                    key: const PageStorageKey('report-daily-details'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    title: Text(
                      'Rincian per hari',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      for (final day in report.daily)
                        if (day.income != 0 || day.expense != 0) ...[
                          const Divider(height: 16),
                          _DayDetail(day: day),
                        ],
                    ],
                  ),
                ],
              ),
            ],
          ],
          _ReportSection(
            'Pengeluaran per kategori',
            period: DateFormat('MMM yyyy', 'id_ID').format(report.month),
            action: TextButton(
              onPressed: () => Navigator.of(context).push(
                EsokMotion.route<void>(
                  (_) => const ManageCategoriesPage(initialKind: 'expense'),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: colors.tint,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Kelola'),
            ),
          ),
          hidden
              ? const EsokContentGroup(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: _HiddenChart(),
                    ),
                  ],
                )
              : _CategoryBreakdown(categories: report.expensesByCategory),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection(this.title, {required this.period, this.action});

  final String title;
  final String period;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(period, style: text.bodySmall),
              ],
            ),
          ),
          ?action,
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
      return const EsokContentGroup(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada pengeluaran untuk bulan ini.'),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    final expenseInk = EsokColors.expenseInk(theme.brightness);
    final showShares = categories.any((entry) => entry.share > 0);
    final percent = NumberFormat('0.#', 'id_ID');
    return EsokContentGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                if (i != 0) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      categories[i].name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      showShares
                          ? '${reportAmount(categories[i].total)} · '
                                '${percent.format(categories[i].share * 100)}%'
                          : reportAmount(categories[i].total),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (showShares) ...[
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: ValueKey('report-allocation-$i'),
                        value: categories[i].share,
                        minHeight: 6,
                        color: expenseInk.withValues(alpha: 0.85),
                        backgroundColor: colors.control,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HiddenChart extends StatelessWidget {
  const _HiddenChart();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        CupertinoIcons.eye_slash,
        size: 19,
        color: EsokColors.of(context).muted,
      ),
      const SizedBox(width: 10),
      const Expanded(child: Text('Grafik dan nominal disembunyikan.')),
    ],
  );
}
