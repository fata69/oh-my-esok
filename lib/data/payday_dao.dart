import 'package:sqflite/sqflite.dart';

import 'account.dart';
import 'money_transaction.dart';
import 'task.dart' show dateKey;

class PaydaySchedule {
  const PaydaySchedule({
    required this.accountId,
    required this.date,
    required this.monthly,
  });

  final String accountId;
  final String date;
  final bool monthly;

  Map<String, Object?> toMap() => {
    'account_id': accountId,
    'date': date,
    'monthly': monthly ? 1 : 0,
  };

  factory PaydaySchedule.fromMap(Map<String, Object?> row) => PaydaySchedule(
    accountId: row['account_id'] as String,
    date: row['date'] as String,
    monthly: _readMonthly(row),
  );

  String? nextOnOrAfter(String day) {
    if (date.compareTo(day) >= 0) return date;
    if (!monthly) return null;
    final anchor = DateTime.parse(date);
    final from = DateTime.parse(day);
    final offset = (from.year - anchor.year) * 12 + from.month - anchor.month;
    final current = _monthlyDate(anchor, offset);
    return current.compareTo(day) >= 0
        ? current
        : _monthlyDate(anchor, offset + 1);
  }
}

class PlannedBill {
  const PlannedBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.accountId,
    required this.date,
    required this.monthly,
  });

  final String id;
  final String name;
  final int amount;
  final String accountId;
  final String date;
  final bool monthly;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'account_id': accountId,
    'date': date,
    'monthly': monthly ? 1 : 0,
  };

  factory PlannedBill.fromMap(Map<String, Object?> row) => PlannedBill(
    id: row['id'] as String,
    name: row['name'] as String,
    amount: row['amount'] as int,
    accountId: row['account_id'] as String,
    date: row['date'] as String,
    monthly: _readMonthly(row),
  );

  bool occursOn(String day) {
    if (day == date) return true;
    if (!monthly || day.compareTo(date) < 0 || !_isDay(day)) return false;
    final anchor = DateTime.parse(date);
    final occurrence = DateTime.parse(day);
    final offset =
        (occurrence.year - anchor.year) * 12 + occurrence.month - anchor.month;
    return _monthlyDate(anchor, offset) == day;
  }

  Iterable<String> dueBefore(String first, String exclusiveEnd) sync* {
    if (date.compareTo(exclusiveEnd) >= 0) return;
    if (!monthly) {
      // One-off bills stay outstanding until paid or removed.
      yield date;
      return;
    }
    final anchor = DateTime.parse(date);
    final from = DateTime.parse(first);
    final months = (from.year - anchor.year) * 12 + from.month - anchor.month;
    // Include the last monthly occurrence so an overdue bill carries forward.
    final current = months < 0 ? null : _monthlyDate(anchor, months);
    final offset = current == null
        ? 0
        : current.compareTo(first) >= 0
        ? (months == 0 ? 0 : months - 1)
        : months;
    for (var index = offset; ; index++) {
      final due = _monthlyDate(anchor, index);
      if (due.compareTo(exclusiveEnd) >= 0) break;
      yield due;
    }
  }

  bool matchesPayment(MoneyTransaction transaction) =>
      transaction.isExpense &&
      transaction.accountId == accountId &&
      transaction.amount == amount;
}

class BillPayment {
  const BillPayment({
    required this.billId,
    required this.dueDate,
    required this.transactionId,
  });

  final String billId;
  final String dueDate;
  final String transactionId;

  Map<String, Object?> toMap() => {
    'bill_id': billId,
    'due_date': dueDate,
    'transaction_id': transactionId,
  };

  factory BillPayment.fromMap(Map<String, Object?> row) => BillPayment(
    billId: row['bill_id'] as String,
    dueDate: row['due_date'] as String,
    transactionId: row['transaction_id'] as String,
  );
}

class PaydayPlan {
  const PaydayPlan({
    this.schedule,
    this.bills = const [],
    this.payments = const [],
  });

  final PaydaySchedule? schedule;
  final List<PlannedBill> bills;
  final List<BillPayment> payments;

  bool get isEmpty => schedule == null && bills.isEmpty && payments.isEmpty;

  Map<String, Object?> toJson() => {
    'schedule': schedule?.toMap(),
    'bills': bills.map((bill) => bill.toMap()).toList(),
    'payments': payments.map((payment) => payment.toMap()).toList(),
  };

  factory PaydayPlan.fromJson(Map<String, Object?> json) {
    try {
      final schedule = json['schedule'] as Map<String, Object?>?;
      return PaydayPlan(
        schedule: schedule == null ? null : PaydaySchedule.fromMap(schedule),
        bills: (json['bills'] as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(PlannedBill.fromMap)
            .toList(),
        payments: (json['payments'] as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(BillPayment.fromMap)
            .toList(),
      );
    } on TypeError {
      throw const FormatException('Format Sampai Gajian tidak valid.');
    }
  }

  void validate({
    required List<Account> accounts,
    required List<MoneyTransaction> transactions,
  }) {
    final accountIds = accounts.map((account) => account.id).toSet();
    if (schedule case final value?) {
      if (!_isDay(value.date) || !accountIds.contains(value.accountId)) {
        throw const FormatException('Jadwal gajian tidak valid.');
      }
    }
    final billsById = <String, PlannedBill>{};
    for (final bill in bills) {
      if (!_validBill(bill) ||
          !accountIds.contains(bill.accountId) ||
          billsById.containsKey(bill.id)) {
        throw const FormatException('Data tagihan tidak valid.');
      }
      billsById[bill.id] = bill;
    }
    final transactionsById = {
      for (final transaction in transactions) transaction.id: transaction,
    };
    final paidBills = <(String, String)>{};
    final usedTransactions = <String>{};
    for (final payment in payments) {
      final bill = billsById[payment.billId];
      final transaction = transactionsById[payment.transactionId];
      if (bill == null ||
          transaction == null ||
          !bill.occursOn(payment.dueDate) ||
          !bill.matchesPayment(transaction) ||
          !paidBills.add((payment.billId, payment.dueDate)) ||
          !usedTransactions.add(payment.transactionId)) {
        throw const FormatException('Tautan pembayaran tidak valid.');
      }
    }
  }
}

class PaydayWriteException implements Exception {
  const PaydayWriteException(this.message);

  final String message;
}

enum AccountDeleteBlock { transactions, payday }

class PaydayDao {
  const PaydayDao(this._db);

  final Database _db;

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE payday_schedule (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  account_id TEXT NOT NULL,
  date TEXT NOT NULL,
  monthly INTEGER NOT NULL CHECK (monthly IN (0, 1))
)''');
    await db.execute('''
CREATE TABLE planned_bills (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  account_id TEXT NOT NULL,
  date TEXT NOT NULL,
  monthly INTEGER NOT NULL CHECK (monthly IN (0, 1))
)''');
    await db.execute('''
CREATE TABLE planned_bill_payments (
  bill_id TEXT NOT NULL,
  due_date TEXT NOT NULL,
  transaction_id TEXT NOT NULL UNIQUE,
  PRIMARY KEY (bill_id, due_date)
)''');
    await db.execute('''
CREATE TRIGGER planned_bill_payment_deleted_transaction
AFTER DELETE ON transactions BEGIN
  DELETE FROM planned_bill_payments WHERE transaction_id = OLD.id;
END''');
    await db.execute('''
CREATE TRIGGER planned_bill_payment_changed_transaction
AFTER UPDATE OF kind, amount, account_id ON transactions
WHEN NEW.kind <> OLD.kind OR NEW.amount <> OLD.amount
OR NEW.account_id <> OLD.account_id BEGIN
  DELETE FROM planned_bill_payments WHERE transaction_id = OLD.id;
END''');
  }

  static Future<PaydayPlan> readFrom(DatabaseExecutor db) async {
    final schedule = (await db.query('payday_schedule')).firstOrNull;
    return PaydayPlan(
      schedule: schedule == null ? null : PaydaySchedule.fromMap(schedule),
      bills: (await db.query(
        'planned_bills',
        orderBy: 'date, id',
      )).map(PlannedBill.fromMap).toList(growable: false),
      payments: (await db.query('planned_bill_payments'))
          .map(BillPayment.fromMap)
          .toList(growable: false),
    );
  }

  static Future<void> replaceIn(DatabaseExecutor db, PaydayPlan plan) async {
    await db.delete('planned_bill_payments');
    await db.delete('planned_bills');
    await db.delete('payday_schedule');
    if (plan.schedule case final schedule?) {
      await db.insert('payday_schedule', {'id': 1, ...schedule.toMap()});
    }
    for (final bill in plan.bills) {
      await db.insert('planned_bills', bill.toMap());
    }
    for (final payment in plan.payments) {
      await db.insert('planned_bill_payments', payment.toMap());
    }
  }

  Future<PaydayPlan> read() => _db.transaction(readFrom);

  Future<void> saveSchedule(PaydaySchedule schedule) =>
      _db.transaction((db) async {
        if (!_isDay(schedule.date)) {
          throw const PaydayWriteException('Pilih tanggal gajian yang valid.');
        }
        await _requireActiveAccount(db, schedule.accountId);
        await db.insert('payday_schedule', {
          'id': 1,
          ...schedule.toMap(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

  Future<void> addBill(PlannedBill bill) => _db.transaction((db) async {
    if (!_validBill(bill)) {
      throw const PaydayWriteException(
        'Lengkapi nama, tanggal, dan nominal tagihan.',
      );
    }
    await _requireActiveAccount(db, bill.accountId);
    await db.insert('planned_bills', bill.toMap());
  });

  Future<void> deleteBill(String billId) => _db.transaction((db) async {
    await db.delete(
      'planned_bill_payments',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    await db.delete('planned_bills', where: 'id = ?', whereArgs: [billId]);
  });

  Future<AccountDeleteBlock?> deleteUnusedAccount(String accountId) =>
      _db.transaction((db) async {
        final transactions = await db.query(
          'transactions',
          columns: ['id'],
          where: 'account_id = ? OR to_account_id = ?',
          whereArgs: [accountId, accountId],
          limit: 1,
        );
        if (transactions.isNotEmpty) return AccountDeleteBlock.transactions;
        final rows = await db.rawQuery(
          '''
SELECT 1 FROM payday_schedule WHERE account_id = ?
UNION ALL SELECT 1 FROM planned_bills WHERE account_id = ? LIMIT 1
''',
          [accountId, accountId],
        );
        if (rows.isNotEmpty) return AccountDeleteBlock.payday;
        await db.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
        return null;
      });

  static Future<void> _requireActiveAccount(
    DatabaseExecutor db,
    String accountId,
  ) async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'id = ? AND archived = 0',
      whereArgs: [accountId],
    );
    if (rows.isEmpty) {
      throw const PaydayWriteException('Pilih dompet yang aktif.');
    }
  }

  Future<void> linkPayment({
    required String billId,
    required String dueDate,
    required String transactionId,
  }) => _db.transaction((db) async {
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    final row = rows.firstOrNull;
    if (row == null) {
      throw const PaydayWriteException('Transaksi sudah dihapus.');
    }
    await _link(db, billId, dueDate, MoneyTransaction.fromMap(row));
  });

  Future<void> recordPayment({
    required String billId,
    required String dueDate,
    required MoneyTransaction transaction,
  }) => _db.transaction((db) async {
    await _requireActiveAccount(db, transaction.accountId);
    await _link(db, billId, dueDate, transaction);
    await db.insert('transactions', transaction.toMap());
  });

  Future<void> unlinkPayment(BillPayment payment) async {
    await _db.delete(
      'planned_bill_payments',
      where: 'bill_id = ? AND due_date = ? AND transaction_id = ?',
      whereArgs: [payment.billId, payment.dueDate, payment.transactionId],
    );
  }

  static Future<void> _link(
    DatabaseExecutor db,
    String billId,
    String dueDate,
    MoneyTransaction transaction,
  ) async {
    final billRow = (await db.query(
      'planned_bills',
      where: 'id = ?',
      whereArgs: [billId],
    )).firstOrNull;
    final bill = billRow == null ? null : PlannedBill.fromMap(billRow);
    if (bill == null || !bill.occursOn(dueDate)) {
      throw const PaydayWriteException(
        'Tagihan sudah berubah. Buka kembali tagihan.',
      );
    }
    if (!bill.matchesPayment(transaction)) {
      throw const PaydayWriteException(
        'Dompet, nominal, dan jenis transaksi harus sesuai dengan tagihan.',
      );
    }
    final existing = await db.query(
      'planned_bill_payments',
      columns: ['transaction_id'],
      where: '(bill_id = ? AND due_date = ?) OR transaction_id = ?',
      whereArgs: [billId, dueDate, transaction.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const PaydayWriteException(
        'Tagihan atau transaksi ini sudah terhubung.',
      );
    }
    await db.insert(
      'planned_bill_payments',
      BillPayment(
        billId: billId,
        dueDate: dueDate,
        transactionId: transaction.id,
      ).toMap(),
    );
  }
}

bool _validBill(PlannedBill bill) =>
    bill.id.isNotEmpty &&
    bill.name.trim().isNotEmpty &&
    bill.name.length <= 54 &&
    bill.amount > 0 &&
    bill.amount <= 999999999 &&
    _isDay(bill.date);

bool _readMonthly(Map<String, Object?> row) => switch (row['monthly']) {
  0 => false,
  1 => true,
  _ => throw const FormatException('Pengulangan tagihan tidak valid.'),
};

bool _isDay(String key) {
  final date = DateTime.tryParse(key);
  return date != null && key.length == 10 && dateKey(date) == key;
}

String _monthlyDate(DateTime anchor, int offset) {
  final lastDay = DateTime(anchor.year, anchor.month + offset + 1, 0).day;
  return dateKey(
    DateTime(
      anchor.year,
      anchor.month + offset,
      anchor.day > lastDay ? lastDay : anchor.day,
    ),
  );
}
