import '../data/category.dart';
import '../data/money_transaction.dart';

class DailyMoneyTotal {
  const DailyMoneyTotal({
    required this.date,
    required this.income,
    required this.expense,
  });

  final DateTime date;
  final int income;
  final int expense;
  int get net => income - expense;
}

class MonthlyMoneyTotal {
  const MonthlyMoneyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final int income;
  final int expense;
  int get net => income - expense;
}

class CategoryExpenseTotal {
  const CategoryExpenseTotal({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.share,
  });

  final String? categoryId;
  final String name;
  final int total;
  final double share;
}

/// A read-only cash-flow snapshot, never an account-balance calculation.
class MoneyReport {
  MoneyReport._({
    required this.month,
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.daily,
    required this.expensesByCategory,
    required this.trend,
  });

  final DateTime month;
  final int income;
  final int expense;
  int get net => income - expense;

  /// Income/expense rows with valid dates in the selected month.
  final int transactionCount;
  final List<DailyMoneyTotal> daily;

  /// Shares are all zero when a category is negative or net expense is not
  /// positive. In that case, present signed totals without a percentage chart.
  final List<CategoryExpenseTotal> expensesByCategory;
  final List<MonthlyMoneyTotal> trend;

  factory MoneyReport.build({
    required DateTime month,
    required Iterable<MoneyTransaction> transactions,
    required Iterable<MoneyCategory> categories,
  }) {
    final selected = DateTime(month.year, month.month);
    final first = DateTime(selected.year, selected.month - 5);
    final days = List.generate(
      DateTime(selected.year, selected.month + 1, 0).day,
      (_) => _CashFlow(),
    );
    final months = List.generate(6, (_) => _CashFlow());
    final knownCategories = {
      for (final category in categories) category.id: category.name,
    };
    final categoryTotals = <String?, int>{};
    var count = 0;
    for (final transaction in transactions) {
      if (!transaction.isIncome && !transaction.isExpense) continue;
      final date = _parseDay(transaction.date);
      if (date == null) continue;
      final index = (date.year - first.year) * 12 + date.month - first.month;
      if (index < 0 || index >= months.length) continue;
      months[index].add(transaction);
      if (index != 5) continue;
      count++;
      days[date.day - 1].add(transaction);
      if (transaction.isExpense) {
        // Archived categories remain known. All unresolved IDs share one bucket.
        final id = knownCategories.containsKey(transaction.categoryId)
            ? transaction.categoryId
            : null;
        categoryTotals[id] = (categoryTotals[id] ?? 0) + transaction.amount;
      }
    }
    final current = months.last;
    final sharesAvailable =
        current.expense > 0 &&
        categoryTotals.values.every((total) => total >= 0);
    final breakdown =
        categoryTotals.entries.map((entry) {
          return CategoryExpenseTotal(
            categoryId: entry.key,
            name: knownCategories[entry.key] ?? 'Tanpa kategori',
            total: entry.value,
            share: sharesAvailable ? entry.value / current.expense : 0.0,
          );
        }).toList()..sort((a, b) {
          final amount = b.total.compareTo(a.total);
          if (amount != 0) return amount;
          final name = a.name.compareTo(b.name);
          return name != 0
              ? name
              : (a.categoryId ?? '').compareTo(b.categoryId ?? '');
        });
    return MoneyReport._(
      month: selected,
      income: current.income,
      expense: current.expense,
      transactionCount: count,
      daily: List.unmodifiable([
        for (var day = 0; day < days.length; day++)
          DailyMoneyTotal(
            date: DateTime(selected.year, selected.month, day + 1),
            income: days[day].income,
            expense: days[day].expense,
          ),
      ]),
      expensesByCategory: List.unmodifiable(breakdown),
      trend: List.unmodifiable([
        for (var index = 0; index < months.length; index++)
          MonthlyMoneyTotal(
            month: DateTime(first.year, first.month + index),
            income: months[index].income,
            expense: months[index].expense,
          ),
      ]),
    );
  }

  static DateTime? _parseDay(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }
}

class _CashFlow {
  int income = 0;
  int expense = 0;

  void add(MoneyTransaction transaction) {
    if (transaction.isIncome) income += transaction.amount;
    if (transaction.isExpense) expense += transaction.amount;
  }
}
