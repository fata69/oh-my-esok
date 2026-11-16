import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/account.dart';
import '../data/account_dao.dart';
import '../data/category.dart';
import '../data/category_dao.dart';
import '../data/database.dart';
import '../data/money_transaction.dart';
import '../data/money_transaction_dao.dart';
import '../data/task.dart';
import '../data/task_dao.dart';

class BackupData {
  const BackupData({
    required this.tasks,
    required this.categories,
    required this.accounts,
    required this.transactions,
  });

  final List<Task> tasks;
  final List<MoneyCategory> categories;
  final List<Account> accounts;
  final List<MoneyTransaction> transactions;
}

class BackupService {
  BackupService._();

  static const schemaVersion = 5;

  static Future<BackupData> collect() async {
    final db = await AppDatabase.open();
    final results = await Future.wait([
      TaskDao(db).all(),
      CategoryDao(db).all(),
      AccountDao(db).all(),
      MoneyTransactionDao(db).all(),
    ]);
    return BackupData(
      tasks: results[0] as List<Task>,
      categories: results[1] as List<MoneyCategory>,
      accounts: results[2] as List<Account>,
      transactions: results[3] as List<MoneyTransaction>,
    );
  }

  static Map<String, Object?> toJsonMap(BackupData data) => {
    'app': 'esok',
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'counts': {
      'tasks': data.tasks.length,
      'transactions': data.transactions.length,
      'categories': data.categories.length,
      'accounts': data.accounts.length,
    },
    'tasks': data.tasks.map(_taskJson).toList(),
    'categories': data.categories.map(_categoryJson).toList(),
    'accounts': data.accounts.map(_accountJson).toList(),
    'transactions': data.transactions
        .map((transaction) => transaction.toJson())
        .toList(),
  };

  static Map<String, Object?> _taskJson(Task task) => {
    'id': task.id,
    'title': task.title,
    'date': task.scheduledDate,
    'time': task.scheduledTime,
    'notes': task.notes,
    'isDone': task.isDone,
    'createdAt': task.createdAt,
  };

  static Map<String, Object?> _categoryJson(MoneyCategory category) => {
    'id': category.id,
    'name': category.name,
    'kind': category.kind,
    'sortOrder': category.sortOrder,
    'archived': category.archived,
    'createdAt': category.createdAt,
    'iconId': category.iconId,
  };

  static Map<String, Object?> _accountJson(Account account) => {
    'id': account.id,
    'name': account.name,
    'type': account.type,
    'sortOrder': account.sortOrder,
    'archived': account.archived,
    'createdAt': account.createdAt,
    'openingBalance': account.openingBalance,
  };

  static Future<File> createJsonFile(BackupData data) async {
    final directory = await getTemporaryDirectory();
    final name =
        'esok-backup-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.json';
    final file = File(p.join(directory.path, name));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJsonMap(data)),
    );
    return file;
  }

  static Future<File> createCsvFile(BackupData data) async {
    final directory = await getTemporaryDirectory();
    final name =
        'esok-backup-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.csv';
    final file = File(p.join(directory.path, name));
    final categoryNames = {
      for (final category in data.categories) category.id: category.name,
    };
    final accountNames = {
      for (final account in data.accounts) account.id: account.name,
    };
    final buffer = StringBuffer(
      'Tanggal,Jenis,Kategori,Sumber dana,Ke sumber dana,Nominal,Catatan\r\n',
    );
    for (final transaction in data.transactions) {
      buffer
        ..write(_csv(transaction.date))
        ..write(',')
        ..write(_csv(transaction.kind))
        ..write(',')
        ..write(_csv(categoryNames[transaction.categoryId] ?? ''))
        ..write(',')
        ..write(_csv(accountNames[transaction.accountId] ?? ''))
        ..write(',')
        ..write(_csv(accountNames[transaction.toAccountId] ?? ''))
        ..write(',')
        ..write(transaction.amount)
        ..write(',')
        ..write(_csv(transaction.note ?? ''))
        ..write('\r\n');
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  static String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<BackupData> parseJsonBytes(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Berkas bukan JSON objek.');
    }
    if (decoded['app'] != 'esok') {
      throw const FormatException('Berkas ini bukan cadangan Esok.');
    }
    final version = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version > schemaVersion) {
      throw const FormatException(
        'Versi skema berkas lebih baru dari aplikasi ini.',
      );
    }

    final tasks = <Task>[];
    final rawTasks = decoded['tasks'];
    if (rawTasks is List) {
      for (final item in rawTasks) {
        if (item is! Map) continue;
        final json = item.cast<String, dynamic>();
        tasks.add(
          Task(
            id: (json['id'] as String?) ?? const Uuid().v4(),
            title: (json['title'] as String?) ?? 'Tanpa judul',
            scheduledDate:
                (json['date'] as String?) ??
                (json['scheduled_date'] as String?) ??
                dateKey(today()),
            scheduledTime:
                (json['time'] as String?) ??
                (json['scheduled_time'] as String?),
            notes: json['notes'] as String?,
            isDone: json['isDone'] == true || json['isDone'] == 1,
            createdAt: _epoch(json['createdAt']),
          ),
        );
      }
    }

    final categories = <MoneyCategory>[];
    final rawCategories = decoded['categories'];
    if (rawCategories is List) {
      for (final item in rawCategories) {
        if (item is! Map) continue;
        final json = item.cast<String, dynamic>();
        categories.add(
          MoneyCategory(
            id: (json['id'] as String?) ?? const Uuid().v4(),
            name: (json['name'] as String?) ?? 'Tanpa nama',
            kind: (json['kind'] as String?) ?? 'expense',
            sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
            archived: json['archived'] == true || json['archived'] == 1,
            createdAt: _epoch(json['createdAt']),
            iconId: json['iconId'] as String?,
          ),
        );
      }
    }

    final accounts = <Account>[];
    final rawAccounts = decoded['accounts'];
    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is! Map) continue;
        final json = item.cast<String, dynamic>();
        accounts.add(
          Account(
            id: (json['id'] as String?) ?? const Uuid().v4(),
            name: (json['name'] as String?) ?? 'Tanpa nama',
            type: (json['type'] as String?) ?? 'cash',
            sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
            archived: json['archived'] == true || json['archived'] == 1,
            createdAt: _epoch(json['createdAt']),
            openingBalance: (json['openingBalance'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }

    final transactions = <MoneyTransaction>[];
    final rawTransactions = decoded['transactions'];
    if (rawTransactions is List) {
      for (final item in rawTransactions) {
        if (item is! Map) continue;
        final json = item.cast<String, dynamic>();
        transactions.add(
          MoneyTransaction.fromJson({
            'id': json['id'] ?? const Uuid().v4(),
            'amount': (json['amount'] as num?)?.toInt() ?? 0,
            'kind': json['kind'] ?? 'expense',
            'categoryId': json['categoryId'] ?? json['category_id'],
            'accountId': json['accountId'] ?? json['account_id'] ?? '',
            'toAccountId': json['toAccountId'] ?? json['to_account_id'],
            'date': json['date'] ?? dateKey(today()),
            'time': json['time'],
            'note': json['note'],
            'createdAt': _epoch(json['createdAt']),
          }),
        );
      }
    }

    return BackupData(
      tasks: tasks,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
    );
  }

  static int _epoch(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  static Future<void> replaceAll(BackupData data) async {
    final db = await AppDatabase.open();
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('accounts');

      for (final task in data.tasks) {
        await txn.insert(
          'tasks',
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final category in data.categories) {
        await txn.insert(
          'categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final account in data.accounts) {
        await txn.insert(
          'accounts',
          account.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final transaction in data.transactions) {
        await txn.insert(
          'transactions',
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    if (data.categories.isEmpty || data.accounts.isEmpty) {
      await AppDatabase.seedDefaults(db);
    }
  }

  static Future<void> clearAll() async {
    final db = await AppDatabase.open();
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('accounts');
    });
    await AppDatabase.seedDefaults(db);
  }
}
