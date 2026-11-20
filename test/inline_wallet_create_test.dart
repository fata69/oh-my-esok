import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'Catat transaksi can create a new wallet inline and auto-select it',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final channel in ['home_widget', 'home_widget/updates']) {
        final bridge = MethodChannel(channel);
        messenger.setMockMethodCallHandler(bridge, (_) async => null);
        addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
      }
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final db = _MemoryLedgerDb();
      final money = MoneyStore(
        CategoryDao(db),
        AccountDao(db),
        MoneyTransactionDao(db),
      );
      final settings = SettingsStore();
      addTearDown(money.dispose);
      addTearDown(settings.dispose);
      await money.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: money),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            theme: EsokTheme.light(),
            home: TxEditorPage(initialDate: DateTime(2026, 11, 20)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter an amount first to ensure the draft survives inline wallet creation.
      await tester.tap(find.text('5').first);
      await tester.tap(find.text('0').first);
      await tester.tap(find.text('000').first);
      await tester.pumpAndSettle();
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Open wallet picker sheet.
      await tester.tap(find.text('Tunai').first);
      await tester.pumpAndSettle();
      expect(find.text('Buat dompet baru'), findsOneWidget);

      // Tap inline create wallet.
      await tester.tap(find.byKey(const ValueKey('inline-create-wallet')));
      await tester.pumpAndSettle();

      final nameField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText?.contains('Nama dompet') ?? false),
      );
      final openingField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText?.contains('Saldo awal') ?? false),
      );
      await tester.enterText(nameField, 'SeaBank');
      await tester.enterText(openingField, '1500000');
      await tester.pump();

      await tester.tap(find.text('Simpan & pilih dompet'));
      await tester.pumpAndSettle();

      // Wallet is persisted with opening balance, auto-selected, and amount draft stays intact.
      expect(money.activeAccounts.any((a) => a.name == 'SeaBank'), isTrue);
      final created = money.activeAccounts.firstWhere(
        (a) => a.name == 'SeaBank',
      );
      expect(created.openingBalance, 1500000);
      expect(find.text('SeaBank'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);
    },
  );
}

class _MemoryLedgerDb implements Database {
  final List<Account> accounts = [
    const Account(
      id: 'acc-cash',
      name: 'Tunai',
      type: 'cash',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
    ),
  ];
  final List<MoneyCategory> categories = [
    const MoneyCategory(
      id: 'cat-exp-makan',
      name: 'Makan',
      kind: 'expense',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
    ),
  ];
  final List<MoneyTransaction> transactions = [];

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
  }) async {
    if (table == 'accounts') {
      return [for (final a in accounts) a.toMap()];
    }
    if (table == 'categories') {
      return [for (final c in categories) c.toMap()];
    }
    if (table == 'transactions') {
      return [for (final t in transactions) t.toMap()];
    }
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql.contains('MAX(sort_order)')) {
      final maxOrder = accounts.isEmpty
          ? -1
          : accounts.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b);
      return [
        {'max_order': maxOrder},
      ];
    }
    return const [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'accounts') {
      accounts.add(Account.fromMap(values));
    } else if (table == 'categories') {
      categories.add(MoneyCategory.fromMap(values));
    } else if (table == 'transactions') {
      transactions.add(MoneyTransaction.fromMap(values));
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
