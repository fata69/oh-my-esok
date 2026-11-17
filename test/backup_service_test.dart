import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/backup/backup_service.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:sqflite/sqflite.dart';

const _detail = '[{"name":"Beras","qty":2,"price":15000}]';
const _account = <String, Object?>{
  'id': 'acc-tunai',
  'name': 'Tunai',
  'type': 'cash',
  'sortOrder': 0,
  'archived': false,
  'createdAt': 1794787200000,
  'openingBalance': 50000,
};
const _category = <String, Object?>{
  'id': 'cat-exp-makan',
  'name': 'Makan',
  'kind': 'expense',
  'sortOrder': 0,
  'archived': false,
  'createdAt': 1794787200000,
  'iconId': 'makan',
};

final _otherAccount = <String, Object?>{
  ..._account,
  'id': 'acc-bank',
  'name': 'Bank',
  'type': 'bank',
  'archived': true,
};
const _task = <String, Object?>{
  'id': 'task-1',
  'title': 'Contoh pengingat',
  'date': '2028-02-29',
  'time': '09:00',
  'notes': null,
  'isDone': false,
  'createdAt': 1794787200000,
};

Map<String, Object?> _transaction(String id, {String? detail}) => {
  'id': id,
  'amount': 30000,
  'kind': 'expense',
  'categoryId': 'cat-exp-makan',
  'accountId': 'acc-tunai',
  'toAccountId': null,
  'date': '2026-11-16',
  'time': null,
  'note': 'Belanja',
  'detail': detail,
  'createdAt': 1794787200000,
};

// Shape emitted by the tagged Esok exporters, with synthetic rows.
Map<String, Object?> _backup({
  List<Object?> tasks = const [],
  List<Map<String, Object?>> categories = const [],
  List<Map<String, Object?>> accounts = const [],
  List<Map<String, Object?>> transactions = const [],
}) => {
  'app': 'esok',
  'schemaVersion': 5,
  'exportedAt': '2026-11-16T12:00:00.000',
  'counts': {
    'tasks': tasks.length,
    'categories': categories.length,
    'accounts': accounts.length,
    'transactions': transactions.length,
  },
  'tasks': tasks,
  'categories': categories,
  'accounts': accounts,
  'transactions': transactions,
};

Future<BackupData> _parseText(String text) =>
    BackupService.parseJsonBytes(Uint8List.fromList(utf8.encode(text)));

Future<BackupData> _parse(Map<String, Object?> json) =>
    _parseText(jsonEncode(json));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v5 backups retain selected icons and accept missing or null keys',
    () async {
      final data = await _parse(
        _backup(
          categories: [_category],
          accounts: [
            _account,
            {..._otherAccount, 'iconKey': 'bank-building'},
          ],
          transactions: [_transaction('purchase', detail: _detail)],
        ),
      );

      final json = BackupService.toJsonMap(data);
      expect(json['schemaVersion'], 5);
      final accounts = json['accounts'] as List<Map<String, Object?>>;
      expect(accounts.first.containsKey('iconKey'), isFalse);
      expect(accounts.last['iconKey'], 'bank-building');

      accounts.first['iconKey'] = null;
      final restored = await _parse(json);
      expect(restored.accounts.map((account) => account.iconKey), [
        null,
        'bank-building',
      ]);
      expect(restored.accounts.last.archived, isTrue);
      expect(restored.accounts.last.openingBalance, 50000);
      expect(restored.categories.single.iconId, 'makan');
      expect(restored.transactions.single.detail, _detail);
    },
  );

  test('v5 backup with a non-string account icon is rejected', () async {
    await expectLater(
      _parse(
        _backup(
          accounts: [
            {..._account, 'iconKey': 42},
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'v5 upgrade and category-only restore preserve a cleared icon',
    () async {
      databaseFactory = databaseFactorySqflitePlugin;
      addTearDown(() => databaseFactory = null);
      const channel = MethodChannel('com.tekartik.sqflite');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final writes = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getDatabasesPath':
            return 'synthetic-ledger';
          case 'openDatabase':
            return 1;
          case 'query':
            return [
              {'user_version': 5},
            ];
          case 'execute':
          case 'batch':
            writes.add(call);
            return null;
          case 'insert':
          case 'update':
            writes.add(call);
            return 1;
          default:
            throw StateError('Unexpected SQLite method: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final backup = await _parse(
        _backup(
          categories: [
            {..._category, 'iconId': null},
          ],
        ),
      );
      await BackupService.replaceAll(backup);

      final migration = writes.where((call) => call.method == 'execute');
      final sql = migration.map((call) => call.arguments['sql']);
      expect(sql.where((s) => s.toString().startsWith('ALTER TABLE')), [
        'ALTER TABLE accounts ADD COLUMN icon_key TEXT',
      ]);
      expect(sql, contains('PRAGMA user_version = 6'));
      final category = writes.singleWhere((call) => call.method == 'insert');
      expect(category.arguments['sql'], contains('icon_id) VALUES'));
      expect(category.arguments['sql'], endsWith('NULL)'));
      final seed = writes.singleWhere((call) => call.method == 'batch');
      final operations = seed.arguments['operations'] as List<Object?>;
      expect(operations, hasLength(1));
      expect(operations.single.toString(), contains('INTO accounts'));
    },
  );

  test('Esok v5 preserves optional transaction detail', () async {
    final data = await _parse(
      _backup(
        categories: [_category],
        accounts: [_account],
        transactions: [
          _transaction('with-detail', detail: _detail),
          _transaction('null-detail'),
          _transaction('missing-detail')..remove('detail'),
        ],
      ),
    );

    expect(data.transactions.map((transaction) => transaction.detail), [
      _detail,
      null,
      null,
    ]);
    expect(data.transactions.first.toMap()['detail'], _detail);
    expect(data.accounts.single.openingBalance, 50000);
  });

  test('truncated JSON is rejected', () async {
    final json = jsonEncode(_backup());
    await expectLater(
      _parseText(json.substring(0, json.length - 1)),
      throwsFormatException,
    );
  });

  test('a header alone is not an empty Esok backup', () async {
    await expectLater(
      _parseText('{"app":"esok","schemaVersion":5}'),
      throwsFormatException,
    );
  });

  for (final key in ['tasks', 'categories', 'accounts', 'transactions']) {
    test('a missing $key array is rejected', () async {
      await expectLater(_parse(_backup()..remove(key)), throwsFormatException);
    });
  }

  test('malformed data arrays and rows are rejected', () async {
    await expectLater(
      _parse(_backup()..['tasks'] = null),
      throwsFormatException,
    );
    await expectLater(_parse(_backup(tasks: [null])), throwsFormatException);
  });

  test('an explicit count that disagrees with the array is rejected', () async {
    await expectLater(
      _parse(_backup()..['counts'] = {'tasks': 1}),
      throwsFormatException,
    );
  });

  test('a backup with only account and category data is still valid', () async {
    final data = await _parse(
      _backup(categories: [_category], accounts: [_account]),
    );

    expect(data.isEmpty, isFalse);
    expect(data.accounts.single.id, 'acc-tunai');
    expect(data.categories.single.id, 'cat-exp-makan');
  });

  test('impossible task dates and times fail before overwrite', () async {
    for (final row in [
      {..._task, 'date': 'bukan-tanggal'},
      {..._task, 'date': '2026-02-29'},
      {..._task, 'date': '2026-13-01'},
      {..._task, 'time': '24:00'},
      {..._task, 'time': '09:60'},
    ]) {
      await expectLater(_parse(_backup(tasks: [row])), throwsFormatException);
    }
    final accepted = await _parse(
      _backup(
        tasks: [
          _task,
          {..._task, 'id': 'no-time', 'time': null},
        ],
      ),
    );
    expect(accepted.tasks.first.scheduledDateTime, DateTime(2028, 2, 29, 9));
    expect(accepted.tasks.last.scheduledDateTime, isNull);
  });

  test('invalid transaction dates and times fail before overwrite', () async {
    for (final entry in [
      MapEntry('date', 'bukan-tanggal'),
      MapEntry('time', '25:00'),
    ]) {
      await expectLater(
        _parse(
          _backup(
            accounts: [_account],
            categories: [_category],
            transactions: [_transaction('txn')..[entry.key] = entry.value],
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'an archived destination and nullable category work in a v5 transfer',
    () async {
      final transfer = _transaction('transfer')
        ..['kind'] = 'transfer'
        ..['categoryId'] = null
        ..['toAccountId'] = 'acc-bank';
      final data = await _parse(
        _backup(
          accounts: [_account, _otherAccount],
          categories: [_category],
          transactions: [transfer, _transaction('same-source')],
        ),
      );
      expect(data.transactions.first.toAccountId, 'acc-bank');
      expect(data.accounts.last.archived, isTrue);
    },
  );

  test('a transfer must refer to two different accounts in the file', () async {
    for (final destination in [null, '', 'missing-account', 'acc-tunai']) {
      final transfer = _transaction('transfer')
        ..['kind'] = 'transfer'
        ..['categoryId'] = null
        ..['toAccountId'] = destination;
      await expectLater(
        _parse(
          _backup(
            accounts: [_account, _otherAccount],
            transactions: [transfer],
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test('unresolved and duplicate references are rejected', () async {
    final row = _transaction('txn');
    for (final json in [
      _backup(categories: [_category], transactions: [row]),
      _backup(accounts: [_account], transactions: [row]),
      _backup(
        accounts: [_account, _account],
        categories: [_category],
        transactions: [row],
      ),
      _backup(
        accounts: [_account],
        categories: [_category],
        transactions: [row, row],
      ),
      _backup(
        accounts: [_account],
        categories: [
          {..._category, 'kind': 'income'},
        ],
        transactions: [row],
      ),
    ]) {
      await expectLater(_parse(json), throwsFormatException);
    }
  });

  test('replaceAll validates typed data before accessing SQLite', () async {
    final valid = await _parse(_backup(accounts: [_account]));
    final invalid = BackupData(
      tasks: valid.tasks,
      categories: valid.categories,
      accounts: valid.accounts,
      transactions: const [
        MoneyTransaction(
          id: 'transfer',
          amount: 1000,
          kind: 'transfer',
          accountId: 'acc-tunai',
          date: '2026-11-16',
          createdAt: 1794787200000,
        ),
      ],
    );
    await expectLater(BackupService.replaceAll(invalid), throwsFormatException);
  });

  test('an explicitly empty Esok backup cannot replace local data', () async {
    final data = await _parse(_backup());

    expect(data.isEmpty, isTrue);
    await expectLater(
      BackupService.replaceAll(data),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Cadangan kosong'),
        ),
      ),
    );
  });
}
