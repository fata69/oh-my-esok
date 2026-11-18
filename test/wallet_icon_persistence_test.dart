import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('wallet and category icons survive reload, edit and reset', () async {
    final db = _LedgerDb();
    final store = await _loadStore(db);
    final wallet = await store.addAccount(
      'Pribadi',
      'bank',
      openingBalance: 50000,
      iconKey: 'wallet',
    );
    final category = await store.addCategory(
      'Kopi',
      'expense',
      iconId: 'makan',
    );

    final reloaded = await _loadStore(db);
    expect(reloaded.accounts.single.iconKey, 'wallet');
    expect(reloaded.categories.single.iconId, 'makan');

    await reloaded.renameAccount(wallet.id, 'Pribadi baru');
    await reloaded.renameCategory(category.id, 'Kopi dan teh');
    expect(reloaded.accounts.single.iconKey, 'wallet');
    expect(reloaded.categories.single.iconId, 'makan');

    await reloaded.renameAccount(wallet.id, 'Pribadi baru', iconKey: 'bank');
    await reloaded.renameCategory(
      category.id,
      'Kopi dan teh',
      iconId: 'lainnya',
    );
    await reloaded.setAccountArchived(wallet.id, true);
    await reloaded.setOpeningBalance(wallet.id, -1200);
    await reloaded.setCategoryArchived(category.id, true);

    final edited = await _loadStore(db);
    expect(edited.accounts.single.iconKey, 'bank');
    expect(edited.categories.single.iconId, 'lainnya');
    await edited.renameAccount(wallet.id, 'Pribadi baru', clearIcon: true);
    await edited.renameCategory(category.id, 'Kopi dan teh', clearIcon: true);

    final reset = await _loadStore(db);
    expect(reset.accounts.single.iconKey, isNull);
    expect(reset.accounts.single.archived, isTrue);
    expect(reset.accounts.single.openingBalance, -1200);
    expect(reset.accounts.single.type, 'bank');
    expect(reset.categories.single.iconId, isNull);
    expect(reset.categories.single.archived, isTrue);
  });
}

Future<MoneyStore> _loadStore(Database db) async {
  final store = MoneyStore(
    CategoryDao(db),
    AccountDao(db),
    MoneyTransactionDao(db),
  );
  addTearDown(store.dispose);
  await store.init();
  return store;
}

// Use the real DAOs so each reload exercises both row mappings.
class _LedgerDb extends Fake implements Database {
  final _rows = <String, Map<Object?, Map<String, Object?>>>{
    'accounts': {},
    'categories': {},
    'transactions': {},
  };

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => _rows[table]!.values.toList();

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [
    {'m': null},
  ];

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _rows[table]![values['id']] = Map.of(values);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _rows[table]![whereArgs!.single]!.addAll(values);
    return 1;
  }
}
