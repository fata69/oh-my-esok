import 'package:sqflite/sqflite.dart';

import 'category.dart';

class CategoryDao {
  CategoryDao(this._db);

  final DatabaseExecutor _db;

  Future<List<MoneyCategory>> all() async {
    final rows = await _db.query(
      'categories',
      orderBy: 'archived ASC, sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(MoneyCategory.fromMap).toList();
  }

  Future<List<MoneyCategory>> active(String kind) async {
    final rows = await _db.query(
      'categories',
      where: 'kind = ? AND archived = 0',
      whereArgs: [kind],
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(MoneyCategory.fromMap).toList();
  }

  Future<MoneyCategory?> byId(String id) async {
    final rows = await _db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MoneyCategory.fromMap(rows.first);
  }

  Future<int> maxSortOrder(String kind) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(sort_order) AS m FROM categories WHERE kind = ?',
      [kind],
    );
    return (rows.first['m'] as int?) ?? -1;
  }

  Future<int> transactionCount(String id) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      [id],
    );
    return rows.first['c'] as int? ?? 0;
  }

  Future<void> insert(MoneyCategory category) async {
    await _db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(MoneyCategory category) async {
    await _db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    await _db.delete('categories');
  }

  Future<void> updateSortOrders(Map<String, int> orders) async {
    final batch = _db.batch();
    for (final entry in orders.entries) {
      batch.update(
        'categories',
        {'sort_order': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }
}
