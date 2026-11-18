import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/account.dart';
import '../data/account_dao.dart';
import '../data/category.dart';
import '../data/category_dao.dart';
import '../data/database.dart';
import '../data/day_note.dart';
import '../data/money_transaction.dart';
import '../data/money_transaction_dao.dart';
import '../data/note_dao.dart';
import '../data/payday_dao.dart';
import '../data/task.dart';
import '../data/task_dao.dart';

class BackupData {
  const BackupData({
    required this.tasks,
    required this.categories,
    required this.accounts,
    required this.transactions,
    this.notes = const [],
    this.paydayPlan = const PaydayPlan(),
  });

  final List<Task> tasks;
  final List<MoneyCategory> categories;
  final List<Account> accounts;
  final List<MoneyTransaction> transactions;
  final List<DayNote> notes;
  final PaydayPlan paydayPlan;

  bool get isEmpty =>
      tasks.isEmpty &&
      categories.isEmpty &&
      accounts.isEmpty &&
      transactions.isEmpty &&
      notes.isEmpty &&
      paydayPlan.isEmpty;
}

class BackupService {
  BackupService._();

  static const schemaVersion = 7;

  static Future<BackupData> collect() async {
    final db = await AppDatabase.open();
    // A conversion or payment link can change two tables in the same write.
    return db.transaction((txn) async {
      return BackupData(
        tasks: await TaskDao.readAll(txn),
        categories: await CategoryDao(txn).all(),
        accounts: await AccountDao(txn).all(),
        transactions: await MoneyTransactionDao(txn).all(),
        notes: await NoteDao.readAll(txn),
        paydayPlan: await PaydayDao.readFrom(txn),
      );
    });
  }

  static Map<String, Object?> toJsonMap(BackupData data) {
    final version = data.notes.isNotEmpty || !data.paydayPlan.isEmpty
        ? schemaVersion
        : data.tasks.any((task) => task.isRecurring)
        ? 6
        : 5;
    return {
      'app': 'esok',
      'schemaVersion': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': {
        'tasks': data.tasks.length,
        'transactions': data.transactions.length,
        'categories': data.categories.length,
        'accounts': data.accounts.length,
        if (version >= 7) 'notes': data.notes.length,
      },
      'tasks': data.tasks.map(_taskJson).toList(),
      'categories': data.categories.map(_categoryJson).toList(),
      'accounts': data.accounts.map(_accountJson).toList(),
      'transactions': data.transactions
          .map((transaction) => transaction.toJson())
          .toList(),
      if (version >= 7) 'notes': data.notes.map(_noteJson).toList(),
      if (!data.paydayPlan.isEmpty) 'paydayPlan': data.paydayPlan.toJson(),
    };
  }

  static Map<String, Object?> _noteJson(DayNote note) => {
    'id': note.id,
    'title': note.title,
    'body': note.body,
    'createdAt': note.createdAt,
    'updatedAt': note.updatedAt,
  };

  static Map<String, Object?> _taskJson(Task task) => {
    'id': task.id,
    'title': task.title,
    'date': task.scheduledDate,
    'time': task.scheduledTime,
    'notes': task.notes,
    'isDone': task.isDone,
    'createdAt': task.createdAt,
    if (task.isRecurring) 'repeatWeekdays': task.repeatWeekdays,
    if (task.seriesId != null) 'seriesId': task.seriesId,
    if (task.repeatUntil != null) 'repeatUntil': task.repeatUntil,
    if (task.isSkipped) 'isSkipped': true,
    if (task.isSkipped && task.isProjected) 'isProjected': true,
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
    // An additive v5 field: legacy readers ignore it and legacy files omit it.
    'iconKey': ?account.iconKey,
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
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('Berkas cadangan rusak atau tidak lengkap.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'esok') {
      throw const FormatException('Berkas ini bukan cadangan Esok.');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version < 1) {
      throw const FormatException('Versi skema cadangan tidak valid.');
    }
    if (version > schemaVersion) {
      throw const FormatException(
        'Versi skema berkas lebih baru dari aplikasi ini.',
      );
    }
    if (decoded.containsKey('counts') &&
        decoded['counts'] is! Map<String, dynamic>) {
      throw const FormatException('Jumlah data cadangan tidak valid.');
    }

    final data = BackupData(
      notes: version >= 7
          ? _parseRows(
              decoded,
              'notes',
              (json) => DayNote(
                id: json['id'] as String,
                title: json['title'] as String,
                body: json['body'] as String,
                createdAt: json['createdAt'] as int,
                updatedAt: json['updatedAt'] as int,
              ),
            )
          : const [],
      paydayPlan: version >= 7 && decoded.containsKey('paydayPlan')
          ? _parsePaydayPlan(decoded['paydayPlan'])
          : const PaydayPlan(),
      tasks: _parseRows(
        decoded,
        'tasks',
        (json) => Task(
          id: json['id'] as String,
          title: json['title'] as String,
          scheduledDate: (json['date'] ?? json['scheduled_date']) as String,
          scheduledTime: (json['time'] ?? json['scheduled_time']) as String?,
          notes: json['notes'] as String?,
          isDone: json['isDone'] == true || json['isDone'] == 1,
          createdAt: _epoch(json['createdAt']),
          repeatWeekdays: version >= 6
              ? (json['repeatWeekdays'] as List?)?.cast<int>().toList() ??
                    const []
              : const [],
          seriesId: version >= 6 ? json['seriesId'] as String? : null,
          repeatUntil: version >= 6 ? json['repeatUntil'] as String? : null,
          isSkipped: version >= 6 && json['isSkipped'] == true,
          isProjected:
              version >= 6 &&
              json['isSkipped'] == true &&
              json['isProjected'] == true,
        ),
      ),
      categories: _parseRows(
        decoded,
        'categories',
        (json) => MoneyCategory(
          id: json['id'] as String,
          name: json['name'] as String,
          kind: json['kind'] as String,
          sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
          archived: json['archived'] == true || json['archived'] == 1,
          createdAt: _epoch(json['createdAt']),
          iconId: json['iconId'] as String?,
        ),
      ),
      accounts: _parseRows(
        decoded,
        'accounts',
        (json) => Account(
          id: json['id'] as String,
          name: json['name'] as String,
          type: json['type'] as String,
          sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
          archived: json['archived'] == true || json['archived'] == 1,
          createdAt: _epoch(json['createdAt']),
          openingBalance: (json['openingBalance'] as num?)?.toInt() ?? 0,
          iconKey: json['iconKey'] as String?,
        ),
      ),
      transactions: _parseRows(
        decoded,
        'transactions',
        (json) => MoneyTransaction.fromJson({
          'id': json['id'],
          'amount': json['amount'] as int,
          'kind': json['kind'] as String,
          'categoryId': json['categoryId'] ?? json['category_id'],
          'accountId': (json['accountId'] ?? json['account_id']) as String,
          'toAccountId': json['toAccountId'] ?? json['to_account_id'],
          'date': json['date'] as String,
          'time': json['time'],
          'note': json['note'],
          'detail': json['detail'],
          'createdAt': _epoch(json['createdAt']),
        }),
      ),
    );
    validate(data);
    return data;
  }

  // Run for parsed files and typed callers before opening or changing SQLite.
  static void validate(BackupData data) {
    Set<String> uniqueIds(Iterable<String> values) {
      final ids = <String>{};
      for (final id in values) {
        if (id.isEmpty || id != id.trim() || !ids.add(id)) {
          throw const FormatException('ID cadangan kosong, rusak, atau ganda.');
        }
      }
      return ids;
    }

    uniqueIds([
      ...data.tasks.map((task) => task.id),
      ...data.notes.map((note) => note.id),
    ]);
    if (data.notes.any((note) => note.isEmpty)) {
      throw const FormatException('Catatan cadangan masih kosong.');
    }
    final seriesRoots = {
      for (final task in data.tasks)
        if (task.isRepeatRule && task.seriesId == null) task.id,
    };
    uniqueIds(data.transactions.map((transaction) => transaction.id));
    final accountIds = uniqueIds(data.accounts.map((account) => account.id));
    uniqueIds(data.categories.map((category) => category.id));
    final categories = {
      for (final category in data.categories) category.id: category,
    };
    for (final task in data.tasks) {
      _validateDateAndTime(task.scheduledDate, task.scheduledTime);
      if (task.repeatWeekdays.any((day) => day < 1 || day > 7) ||
          task.repeatWeekdays.toSet().length != task.repeatWeekdays.length ||
          (task.seriesId != null && !seriesRoots.contains(task.seriesId)) ||
          (task.isSkipped && !task.isOccurrence) ||
          (task.isRecurring && task.repeatWeekdays.isEmpty)) {
        throw const FormatException('Aturan agenda berulang tidak valid.');
      }
      if (task.repeatUntil case final until?) {
        _validateDateAndTime(until, null);
        if (!task.isRepeatRule || until.compareTo(task.scheduledDate) < 0) {
          throw const FormatException('Akhir agenda berulang tidak valid.');
        }
      }
      if (task.isOccurrence) {
        if (task.id.length < 16 ||
            task.id !=
                Task.occurrenceId(task.recurrenceId, task.occurrenceDay)) {
          throw const FormatException('ID kejadian agenda tidak valid.');
        }
        _validateDateAndTime(task.occurrenceDay, null);
      }
    }
    for (final transaction in data.transactions) {
      _validateDateAndTime(transaction.date, transaction.time);
      if (!const [
        'expense',
        'income',
        'transfer',
        'adjustment',
      ].contains(transaction.kind)) {
        throw const FormatException('Jenis transaksi cadangan tidak valid.');
      }
      if (!accountIds.contains(transaction.accountId)) {
        throw const FormatException('Sumber dana transaksi tidak ditemukan.');
      }
      final destination = transaction.toAccountId;
      if (transaction.isTransfer) {
        if (destination == null ||
            !accountIds.contains(destination) ||
            destination == transaction.accountId) {
          throw const FormatException('Tujuan pindah dana tidak valid.');
        }
      } else if (destination != null) {
        throw const FormatException('Tujuan dana hanya berlaku untuk pindah.');
      }
      final categoryId = transaction.categoryId;
      if (categoryId != null) {
        final category = categories[categoryId];
        if (category == null ||
            ((transaction.isExpense || transaction.isIncome) &&
                category.kind != transaction.kind)) {
          throw const FormatException('Kategori transaksi tidak valid.');
        }
      }
    }
    data.paydayPlan.validate(
      accounts: data.accounts,
      transactions: data.transactions,
    );
  }

  static PaydayPlan _parsePaydayPlan(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Rencana Sampai Gajian tidak valid.');
    }
    try {
      return PaydayPlan.fromJson(raw);
    } on TypeError {
      throw const FormatException('Rencana Sampai Gajian tidak valid.');
    }
  }

  static void _validateDateAndTime(String day, String? time) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    if (match == null) {
      throw const FormatException('Tanggal cadangan tidak valid.');
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final number = int.parse(match[3]!);
    final date = DateTime.utc(year, month, number);
    if (year < 1 ||
        month < 1 ||
        month > 12 ||
        date.year != year ||
        date.month != month ||
        date.day != number) {
      throw const FormatException('Tanggal cadangan tidak valid.');
    }
    if (time != null &&
        time.isNotEmpty &&
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw const FormatException('Jam cadangan tidak valid.');
    }
  }

  static List<T> _parseRows<T>(
    Map<String, dynamic> backup,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    // Esok exports all four arrays, even when they contain no rows.
    final raw = backup[key];
    if (raw is! List) {
      throw FormatException('Bagian "$key" hilang atau bukan daftar.');
    }
    final counts = backup['counts'];
    if (counts is Map<String, dynamic> && counts.containsKey(key)) {
      final count = counts[key];
      if (count is! int || count != raw.length) {
        throw FormatException('Jumlah data pada bagian "$key" tidak cocok.');
      }
    }

    final rows = <T>[];
    for (var index = 0; index < raw.length; index++) {
      final entry = raw[index];
      final message = 'Baris ${index + 1} pada bagian "$key" tidak valid.';
      if (entry is! Map<String, dynamic>) throw FormatException(message);
      try {
        rows.add(parse(entry));
      } on TypeError {
        throw FormatException(message);
      }
    }
    return rows;
  }

  static int _epoch(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  static Future<void> replaceAll(BackupData data) async {
    validate(data);
    if (data.isEmpty) {
      throw const FormatException(
        'Cadangan kosong. Data saat ini tidak diubah.',
      );
    }
    final db = await AppDatabase.open();
    await db.transaction((txn) async {
      await PaydayDao.replaceIn(txn, const PaydayPlan());
      await txn.delete(NoteDao.table);
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
      for (final note in data.notes) {
        await txn.insert(NoteDao.table, note.toMap());
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
      if (data.categories.isEmpty || data.accounts.isEmpty) {
        await AppDatabase.seedDefaults(
          txn,
          categories: data.categories.isEmpty,
          accounts: data.accounts.isEmpty,
        );
      }
      if (!data.paydayPlan.isEmpty) {
        await PaydayDao.replaceIn(txn, data.paydayPlan);
      }
    });
  }

  static Future<void> clearAll() async {
    final db = await AppDatabase.open();
    await db.transaction((txn) async {
      await PaydayDao.replaceIn(txn, const PaydayPlan());
      await txn.delete(NoteDao.table);
      await txn.delete('tasks');
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('accounts');
    });
    await AppDatabase.seedDefaults(db);
  }
}
