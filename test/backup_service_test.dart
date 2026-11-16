import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/backup/backup_service.dart';

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
