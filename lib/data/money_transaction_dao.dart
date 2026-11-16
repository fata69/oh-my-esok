import 'package:sqflite/sqflite.dart';

import 'money_transaction.dart';

class MoneyTransactionDao {
  MoneyTransactionDao(this._db);

  final Database _db;

  Future<List<MoneyTransaction>> between(String start, String end) async {
    final rows = await _db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<List<MoneyTransaction>> forDate(String date) async {
    final rows = await _db.query(
      'transactions',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
    );
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<List<MoneyTransaction>> all() async {
    final rows = await _db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<MoneyTransaction?> byId(String id) async {
    final rows = await _db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MoneyTransaction.fromMap(rows.first);
  }

  Future<int> countAll() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return rows.first['c'] as int? ?? 0;
  }

  Future<void> insert(MoneyTransaction transaction) async {
    await _db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(MoneyTransaction transaction) async {
    await _db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    await _db.delete('transactions');
  }
}
