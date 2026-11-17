import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/account.dart';
import '../data/account_dao.dart';
import '../data/category.dart';
import '../data/category_dao.dart';
import '../data/money_transaction.dart';
import '../data/money_transaction_dao.dart';
import '../data/task.dart';
import '../widget/widget_sync.dart';
import 'money_report.dart';

class NameConflictException implements Exception {}

class ItemInUseException implements Exception {}

class MoneyStore extends ChangeNotifier {
  MoneyStore(this._categoryDao, this._accountDao, this._transactionDao);

  final CategoryDao _categoryDao;
  final AccountDao _accountDao;
  final MoneyTransactionDao _transactionDao;

  DateTime _month = DateTime(today().year, today().month);
  List<MoneyCategory> _categories = const [];
  List<Account> _accounts = const [];
  List<MoneyTransaction> _allTransactions = const [];
  List<MoneyTransaction> _monthTransactions = const [];
  int _revision = 0;

  DateTime get month => _month;
  List<MoneyCategory> get categories => _categories;
  List<Account> get accounts => _accounts;
  List<MoneyTransaction> get monthTransactions => _monthTransactions;
  int get revision => _revision;

  MoneyReport get monthReport => MoneyReport.build(
    month: _month,
    transactions: _allTransactions,
    categories: _categories,
  );

  List<MoneyCategory> get expenseCategories => _activeCategories('expense');
  List<MoneyCategory> get incomeCategories => _activeCategories('income');

  List<MoneyCategory> _activeCategories(String kind) {
    return _categories
        .where((category) => category.kind == kind && !category.archived)
        .toList();
  }

  List<Account> get activeAccounts {
    return _accounts.where((account) => !account.archived).toList();
  }

  List<MoneyCategory> get archivedCategories {
    return _categories.where((category) => category.archived).toList();
  }

  List<Account> get archivedAccounts {
    return _accounts.where((account) => account.archived).toList();
  }

  Account? accountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  int balanceForAccount(String id) {
    final account = accountById(id);
    if (account == null) return 0;
    var balance = account.openingBalance;
    for (final transaction in _allTransactions) {
      if (transaction.kind == 'income' && transaction.accountId == id) {
        balance += transaction.amount;
      } else if (transaction.kind == 'expense' &&
          transaction.accountId == id) {
        balance -= transaction.amount;
      } else if (transaction.kind == 'transfer') {
        if (transaction.accountId == id) balance -= transaction.amount;
        if (transaction.toAccountId == id) balance += transaction.amount;
      } else if (transaction.kind == 'adjustment' &&
          transaction.accountId == id) {
        balance += transaction.amount;
      }
    }
    return balance;
  }

  int get totalBalance {
    return activeAccounts.fold(
      0,
      (sum, account) => sum + balanceForAccount(account.id),
    );
  }

  int get monthIncome => _monthTransactions
      .where((transaction) => transaction.isIncome)
      .fold(0, (sum, transaction) => sum + transaction.amount);

  int get monthExpense => _monthTransactions
      .where((transaction) => transaction.isExpense)
      .fold(0, (sum, transaction) => sum + transaction.amount);

  int get monthNet => monthIncome - monthExpense;

  Map<String, int> get monthExpenseByCategory {
    final result = <String, int>{};
    for (final transaction in _monthTransactions) {
      if (!transaction.isExpense) continue;
      final key = transaction.categoryId ?? '';
      result[key] = (result[key] ?? 0) + transaction.amount;
    }
    return result;
  }

  Map<String, List<MoneyTransaction>> get monthByDay {
    final result = <String, List<MoneyTransaction>>{};
    for (final transaction in _monthTransactions) {
      result.putIfAbsent(transaction.date, () => []).add(transaction);
    }
    return result;
  }

  int netForDay(List<MoneyTransaction> transactions) {
    var net = 0;
    for (final transaction in transactions) {
      if (transaction.isIncome) net += transaction.amount;
      if (transaction.isExpense) net -= transaction.amount;
    }
    return net;
  }

  int get monthCount => _monthTransactions.length;

  String categoryName(String? id) {
    if (id == null) return 'Tanpa kategori';
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return 'Tanpa kategori';
  }

  String accountName(String? id) {
    if (id == null) return 'Tanpa dompet';
    for (final account in _accounts) {
      if (account.id == id) return account.name;
    }
    return 'Tanpa dompet';
  }

  Future<void> init() async {
    await _loadMeta();
    await _loadMonth();
  }

  Future<void> refresh() async {
    await _loadMeta();
    await _loadMonth();
  }

  Future<void> _loadMeta() async {
    final results = await Future.wait([_categoryDao.all(), _accountDao.all()]);
    _categories = results[0] as List<MoneyCategory>;
    _accounts = results[1] as List<Account>;
  }

  Future<void> _loadMonth() async {
    final all = await _transactionDao.all();
    _allTransactions = all;
    final start = dateKey(_month);
    final end = dateKey(DateTime(_month.year, _month.month + 1, 0));
    _monthTransactions = all
        .where(
          (transaction) =>
              transaction.date.compareTo(start) >= 0 &&
              transaction.date.compareTo(end) <= 0,
        )
        .toList();
    _revision++;
    notifyListeners();
  }

  Future<void> setMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month);
    if (normalized == _month) return;
    _month = normalized;
    await _loadMonth();
  }

  Future<void> nextMonth() => setMonth(DateTime(_month.year, _month.month + 1));

  Future<void> previousMonth() =>
      setMonth(DateTime(_month.year, _month.month - 1));

  Future<List<MoneyTransaction>> transactionsForDate(DateTime date) {
    return _transactionDao.forDate(dateKey(date));
  }

  Future<MoneyTransaction?> transactionById(String id) =>
      _transactionDao.byId(id);

  Future<List<MoneyTransaction>> allTransactions() => _transactionDao.all();

  Future<int> countTransactions() => _transactionDao.countAll();

  Future<void> addTransaction(MoneyTransaction transaction) async {
    await _transactionDao.insert(transaction);
    await _loadMonth();
    await WidgetSync.push();
  }

  Future<void> updateTransaction(MoneyTransaction transaction) async {
    await _transactionDao.update(transaction);
    await _loadMonth();
    await WidgetSync.push();
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionDao.delete(id);
    await _loadMonth();
    await WidgetSync.push();
  }

  Future<MoneyCategory> addCategory(
    String name,
    String kind, {
    String? iconId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama kategori kosong');
    final duplicate = _categories.any(
      (category) =>
          category.kind == kind &&
          category.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw NameConflictException();

    final sortOrder = await _categoryDao.maxSortOrder(kind) + 1;
    final category = MoneyCategory(
      id: const Uuid().v4(),
      name: trimmed,
      kind: kind,
      sortOrder: sortOrder,
      archived: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      iconId: iconId,
    );
    await _categoryDao.insert(category);
    await _loadMeta();
    notifyListeners();
    return category;
  }

  Future<void> renameCategory(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama kategori kosong');
    final current = _categories.firstWhere((category) => category.id == id);
    final duplicate = _categories.any(
      (category) =>
          category.id != id &&
          category.kind == current.kind &&
          category.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw NameConflictException();
    await _categoryDao.update(current.copyWith(name: trimmed));
    await _loadMeta();
    notifyListeners();
  }

  Future<void> setCategoryArchived(String id, bool archived) async {
    final current = _categories.firstWhere((category) => category.id == id);
    await _categoryDao.update(current.copyWith(archived: archived));
    await _loadMeta();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    final count = await _categoryDao.transactionCount(id);
    if (count > 0) throw ItemInUseException();
    await _categoryDao.delete(id);
    await _loadMeta();
    notifyListeners();
  }

  Future<int> categoryTransactionCount(String id) =>
      _categoryDao.transactionCount(id);

  Future<void> reorderCategories(String kind, List<String> orderedIds) async {
    final orders = <String, int>{};
    for (var i = 0; i < orderedIds.length; i++) {
      orders[orderedIds[i]] = i;
    }
    await _categoryDao.updateSortOrders(orders);
    await _loadMeta();
    notifyListeners();
  }

  Future<Account> addAccount(
    String name,
    String type, {
    int openingBalance = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama dompet kosong');
    final duplicate = _accounts.any(
      (account) => account.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw NameConflictException();

    final sortOrder = await _accountDao.maxSortOrder() + 1;
    final account = Account(
      id: const Uuid().v4(),
      name: trimmed,
      type: type,
      sortOrder: sortOrder,
      archived: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      openingBalance: openingBalance,
    );
    await _accountDao.insert(account);
    await _loadMeta();
    notifyListeners();
    return account;
  }

  Future<void> renameAccount(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama dompet kosong');
    final current = _accounts.firstWhere((account) => account.id == id);
    final duplicate = _accounts.any(
      (account) =>
          account.id != id &&
          account.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw NameConflictException();
    await _accountDao.update(current.copyWith(name: trimmed));
    await _loadMeta();
    notifyListeners();
  }

  Future<void> setAccountArchived(String id, bool archived) async {
    final current = _accounts.firstWhere((account) => account.id == id);
    await _accountDao.update(current.copyWith(archived: archived));
    await _loadMeta();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final count = await _accountDao.transactionCount(id);
    if (count > 0) throw ItemInUseException();
    await _accountDao.delete(id);
    await _loadMeta();
    notifyListeners();
  }

  Future<int> accountTransactionCount(String id) =>
      _accountDao.transactionCount(id);

  Future<void> reorderAccounts(List<String> orderedIds) async {
    final orders = <String, int>{};
    for (var i = 0; i < orderedIds.length; i++) {
      orders[orderedIds[i]] = i;
    }
    await _accountDao.updateSortOrders(orders);
    await _loadMeta();
    notifyListeners();
  }

  Future<void> setOpeningBalance(String id, int value) async {
    final current = _accounts.firstWhere((account) => account.id == id);
    await _accountDao.update(current.copyWith(openingBalance: value));
    await _loadMeta();
    notifyListeners();
  }

  Future<void> adjustBalance(String id, int actual) async {
    final current = balanceForAccount(id);
    final delta = actual - current;
    if (delta == 0) return;
    final transaction = MoneyTransaction(
      id: const Uuid().v4(),
      amount: delta,
      kind: 'adjustment',
      accountId: id,
      date: dateKey(today()),
      note: 'Koreksi saldo',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _transactionDao.insert(transaction);
    await _loadMonth();
    await WidgetSync.push();
  }
}
