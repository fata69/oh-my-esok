import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/category.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/state/money_report.dart';

MoneyTransaction _tx(
  String date,
  String kind,
  int amount, {
  String? category,
}) => MoneyTransaction(
  id: '$date-$kind-$amount',
  date: date,
  kind: kind,
  amount: amount,
  categoryId: category,
  accountId: 'cash',
  toAccountId: kind == 'transfer' ? 'bank' : null,
  createdAt: 0,
);

MoneyCategory _category(String id, String name, {bool archived = false}) =>
    MoneyCategory(
      id: id,
      name: name,
      kind: 'expense',
      sortOrder: 0,
      archived: archived,
      createdAt: 0,
    );

void main() {
  test('month bounds use valid dates and only income/expense cash flow', () {
    final report = MoneyReport.build(
      month: DateTime.utc(2027, 1, 17, 15),
      transactions: [
        _tx('2026-12-31', 'income', 100000),
        _tx('2027-01-01', 'income', 50000),
        _tx('2027-01-31', 'expense', 12000),
        _tx('2027-02-01', 'expense', 90000),
        _tx('2027-01-15', 'transfer', 80000),
        _tx('2027-01-15', 'adjustment', 70000),
        _tx('2027-01-15', 'opening', 60000),
        for (final date in [
          '',
          'not-a-date',
          '2027-01-32',
          '2027-00-01',
          '2027-13-01',
          '2027-02-29',
          '2027-1-02',
          '2027-01-01T00:00:00Z',
        ])
          _tx(date, 'income', 999999),
      ],
      categories: [],
    );
    expect(report.month, DateTime(2027, 1));
    expect(report.income, 50000);
    expect(report.expense, 12000);
    expect(report.net, 38000);
    expect(report.transactionCount, 2);
    expect(report.daily, hasLength(31));
    expect(report.daily.first.income, 50000);
    expect(report.daily.last.expense, 12000);
    expect(report.daily[14].net, 0);
  });

  test(
    'empty leap month includes all days and six chronological zero months',
    () {
      final report = MoneyReport.build(
        month: DateTime(2028, 2),
        transactions: [],
        categories: [],
      );
      expect(report.daily, hasLength(29));
      expect(report.daily.last.date, DateTime(2028, 2, 29));
      expect(report.daily.every((day) => day.net == 0), isTrue);
      expect(report.trend.map((entry) => entry.month), [
        DateTime(2027, 9),
        DateTime(2027, 10),
        DateTime(2027, 11),
        DateTime(2027, 12),
        DateTime(2028, 1),
        DateTime(2028, 2),
      ]);
      expect(
        report.trend.every((entry) => entry.income == 0 && entry.expense == 0),
        isTrue,
      );
      expect(report.income, 0);
      expect(report.expense, 0);
      expect(report.transactionCount, 0);
      expect(report.expensesByCategory, isEmpty);
      expect(
        MoneyReport.build(
          month: DateTime(2027, 2),
          transactions: [],
          categories: [],
        ).daily,
        hasLength(28),
      );
    },
  );

  test('leap day and six-month rollover keep integer totals exact', () {
    const largeAmount = 9007199254740993;
    final report = MoneyReport.build(
      month: DateTime(2028, 2),
      transactions: [
        _tx('2027-08-31', 'income', 900),
        _tx('2027-09-01', 'income', 10),
        _tx('2027-12-31', 'expense', 20),
        _tx('2028-02-29', 'income', largeAmount),
        _tx('2028-03-01', 'income', 800),
      ],
      categories: [],
    );
    expect(report.income, largeAmount);
    expect(report.daily.last.income, largeAmount);
    expect(report.trend.first.income, 10);
    expect(report.trend[3].expense, 20);
    expect(report.trend.last.net, largeAmount);
    expect(
      report.daily.fold<int>(0, (sum, day) => sum + day.income),
      report.income,
    );
  });

  test('category totals merge unresolved IDs and retain archived names', () {
    final report = MoneyReport.build(
      month: DateTime(2026, 11),
      transactions: [
        _tx('2026-11-01', 'expense', 30, category: 'archived'),
        _tx('2026-11-02', 'expense', 20, category: 'z'),
        _tx('2026-11-03', 'expense', 20, category: 'a'),
        _tx('2026-11-04', 'expense', 10),
        _tx('2026-11-05', 'expense', 10, category: 'missing-1'),
        _tx('2026-11-06', 'expense', 10, category: 'missing-2'),
        _tx('2026-11-06', 'income', 500, category: 'a'),
      ],
      categories: [
        _category('archived', 'Lama', archived: true),
        _category('z', 'Zeta'),
        _category('a', 'Alfa'),
      ],
    );
    final categories = report.expensesByCategory;
    expect(categories.map((entry) => entry.name), [
      'Lama',
      'Tanpa kategori',
      'Alfa',
      'Zeta',
    ]);
    expect(categories.map((entry) => entry.categoryId), [
      'archived',
      null,
      'a',
      'z',
    ]);
    expect(
      categories.fold<int>(0, (sum, entry) => sum + entry.total),
      report.expense,
    );
    expect(categories.map((entry) => entry.share), [0.3, 0.3, 0.2, 0.2]);
    expect(
      categories.fold<double>(0, (sum, entry) => sum + entry.share),
      closeTo(1, 1e-12),
    );
    expect(() => report.daily.clear(), throwsUnsupportedError);
    expect(() => report.expensesByCategory.clear(), throwsUnsupportedError);
    expect(() => report.trend.clear(), throwsUnsupportedError);
  });

  test(
    'signed category totals disable percentages without changing totals',
    () {
      for (final refund in [-50, -150]) {
        final report = MoneyReport.build(
          month: DateTime(2026, 11),
          transactions: [
            _tx('2026-11-01', 'expense', 100, category: 'a'),
            _tx('2026-11-02', 'expense', refund),
          ],
          categories: [_category('a', 'Alfa')],
        );
        expect(report.expense, 100 + refund);
        expect(report.net, -(100 + refund));
        expect(report.expensesByCategory.map((entry) => entry.total), [
          100,
          refund,
        ]);
        expect(report.expensesByCategory.map((entry) => entry.share), [0, 0]);
        expect(
          report.expensesByCategory.every(
            (entry) =>
                entry.share.isFinite && entry.share >= 0 && entry.share <= 1,
          ),
          isTrue,
        );
      }
    },
  );
}
