import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/state/money_store.dart';

class _Categories implements CategoryDao {
  List<MoneyCategory> rows = [
    const MoneyCategory(
      id: 'category',
      name: 'Awal',
      kind: 'expense',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
    ),
  ];
  @override
  Future<List<MoneyCategory>> all() async => List.of(rows);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected category operation: ${invocation.memberName}',
  );
}

class _Accounts implements AccountDao {
  @override
  Future<List<Account>> all() async => const [
    Account(
      id: 'cash',
      name: 'Tunai',
      type: 'cash',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
      openingBalance: 900000,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected account operation: ${invocation.memberName}',
  );
}

class _Transactions implements MoneyTransactionDao {
  List<MoneyTransaction> rows = [
    const MoneyTransaction(
      id: 'expense',
      kind: 'expense',
      amount: 15000,
      categoryId: 'category',
      date: '2027-01-01',
      accountId: 'cash',
      createdAt: 0,
    ),
  ];
  @override
  Future<List<MoneyTransaction>> all() async => List.of(rows);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected transaction operation: ${invocation.memberName}',
  );
}

void main() {
  test(
    'report follows selected month, refreshed rows and archived labels',
    () async {
      final categories = _Categories();
      final transactions = _Transactions();
      final store = MoneyStore(categories, _Accounts(), transactions);
      addTearDown(store.dispose);
      await store.init();
      await store.setMonth(DateTime(2027, 1));
      final original = store.monthReport;
      final revision = store.revision;
      expect(original.net, -15000);
      expect(original.expensesByCategory.single.name, 'Awal');
      expect(store.totalBalance, 885000);
      expect(original.income, 0); // Opening balance is never report cash flow.

      transactions.rows = [
        transactions.rows.single.copyWith(amount: 20000),
        const MoneyTransaction(
          id: 'income',
          kind: 'income',
          amount: 50000,
          date: '2027-02-01',
          accountId: 'cash',
          createdAt: 0,
        ),
      ];
      categories.rows = [
        categories.rows.single.copyWith(name: 'Arsip', archived: true),
      ];
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.refresh();
      expect(notifications, greaterThan(0));
      expect(store.revision, greaterThan(revision));
      expect(store.monthReport.expense, 20000);
      expect(store.monthReport.expensesByCategory.single.name, 'Arsip');
      expect(original.expense, 15000);

      await store.nextMonth();
      final next = store.monthReport;
      expect(next.month, DateTime(2027, 2));
      expect(next.income, 50000);
      expect(next.expense, 0);
      expect(next.trend[4].expense, 20000);
      expect(next.transactionCount, 1);
      await store.previousMonth();
      expect(store.monthReport.month, original.month);
    },
  );
}
