import 'package:sqflite/sqflite.dart';

import 'account.dart';

class AccountDao {
  AccountDao(this._db);

  final Database _db;

  Future<List<Account>> all() async {
    final rows = await _db.query(
      'accounts',
      orderBy: 'archived ASC, sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<List<Account>> active() async {
    final rows = await _db.query(
      'accounts',
      where: 'archived = 0',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> byId(String id) async {
    final rows = await _db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<int> maxSortOrder() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(sort_order) AS m FROM accounts',
    );
    return (rows.first['m'] as int?) ?? -1;
  }

  Future<int> transactionCount(String id) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE account_id = ? OR to_account_id = ?',
      [id, id],
    );
    return rows.first['c'] as int? ?? 0;
  }

  Future<void> insert(Account account) async {
    await _db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Account account) async {
    await _db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    await _db.delete('accounts');
  }

  Future<void> updateSortOrders(Map<String, int> orders) async {
    final batch = _db.batch();
    for (final entry in orders.entries) {
      batch.update(
        'accounts',
        {'sort_order': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }
}
