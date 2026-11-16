import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/money_transaction.dart';
import '../data/task.dart';
import '../state/money_store.dart';
import '../util/format.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

class DayMoneySection extends StatefulWidget {
  const DayMoneySection({super.key, required this.date, this.onOpenMoney});

  final DateTime date;
  final VoidCallback? onOpenMoney;

  @override
  State<DayMoneySection> createState() => _DayMoneySectionState();
}

class _DayMoneySectionState extends State<DayMoneySection> {
  late Future<List<MoneyTransaction>> _future;
  int _revision = -1;
  DateTime? _date;

  void _load(MoneyStore store) {
    _future = store.transactionsForDate(widget.date);
    _revision = store.revision;
    _date = widget.date;
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final store = context.watch<MoneyStore>();
    if (_revision != store.revision || _date != widget.date) {
      _load(store);
    }

    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.lineStrong)),
      ),
      child: FutureBuilder<List<MoneyTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? const <MoneyTransaction>[];
          final expenses = transactions
              .where((transaction) => transaction.isExpense)
              .toList();
          final income = transactions
              .where((transaction) => transaction.isIncome)
              .fold(0, (sum, transaction) => sum + transaction.amount);
          final expense = expenses.fold(
            0,
            (sum, transaction) => sum + transaction.amount,
          );
          final hasIncome = income > 0;
          final big = hasIncome ? income - expense : expense;
          final categoryTotals = <String, int>{};
          for (final transaction in expenses) {
            final key = transaction.categoryId ?? '';
            categoryTotals[key] =
                (categoryTotals[key] ?? 0) + transaction.amount;
          }
          final topCategories = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final shown = topCategories.take(3).toList();
          final maxValue = expense.abs() == 0 ? 1 : expense.abs();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (widget.date == today()
                              ? 'Uang hari ini'
                              : 'Uang hari itu')
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.09,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onOpenMoney,
                    child: Text(
                      'BUKU KAS ›',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: colors.disabled,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'belum ada transaksi',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ],
                )
              else ...[
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      hasIncome ? signedNumberText(big) : numberText(big),
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.02,
                        color: hasIncome
                            ? (big < 0
                                  ? colors.negative
                                  : big > 0
                                  ? colors.positive
                                  : colors.ink)
                            : (big > 0
                                  ? colors.negative
                                  : colors.ink),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      hasIncome ? 'selisih' : 'keluar',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.muted,
                        ),
                        children: [
                          const TextSpan(text: 'Masuk '),
                          TextSpan(
                            text: rupiahText(income),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.positive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.muted,
                        ),
                        children: [
                          const TextSpan(text: 'Keluar '),
                          TextSpan(
                            text: rupiahText(expense),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final entry in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  store.categoryName(entry.key),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.inkSoft,
                                  ),
                                ),
                              ),
                              Text(
                                numberText(entry.value),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.negative,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Container(
                              height: 3,
                              color: colors.line,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (entry.value.abs() / maxValue)
                                    .clamp(0.0, 1.0),
                                child: Container(
                                  color: colors.barFill,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<String>(
                        builder: (_) => TxEditorPage(
                          initialDate: widget.date,
                          initialKind: 'expense',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: colors.lineStrong),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 15, color: colors.ink),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            transactions.isEmpty
                                ? 'Catat transaksi'
                                : 'Catat pengeluaran',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            ),
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
    );
  }
}
