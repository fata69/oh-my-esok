import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/backup/backup_service.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:jadwal/ui/calendar_sheet.dart';
import 'package:jadwal/ui/money_page.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:jadwal/util/format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'MoneyPage search clears cross-month results and keeps ledger state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 892);
      addTearDown(tester.view.reset);

      final db = _SearchDatabase();
      final store = MoneyStore(
        CategoryDao(db),
        AccountDao(db),
        MoneyTransactionDao(db),
      );
      addTearDown(store.dispose);
      final selectedMonth = DateTime(2026, 1);
      await store.init();
      await store.setMonth(selectedMonth);

      void expectLedgerState() {
        expect(store.month, selectedMonth);
        expect(store.totalBalance, 75000);
        expect(store.balanceForAccount('cash'), 65000);
        expect(store.balanceForAccount('savings'), 10000);
      }

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: EsokTheme.light(),
            home: const Scaffold(body: MoneyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final currentRow = find.text('Belanja Januari');
      final olderRow = find.text('Pemindahan Desember');
      final searchEntry = find.text('Cari transaksi');
      expect(currentRow.hitTestable(), findsOneWidget);
      expect(olderRow, findsNothing);
      expectLedgerState();

      await tester.ensureVisible(searchEntry);
      await tester.pumpAndSettle();
      await tester.tap(searchEntry);
      await tester.pumpAndSettle();

      final moneyPage = find.byType(MoneyPage);
      final input = find.byType(EditableText);
      final clear = find.byTooltip('Hapus pencarian');
      expect(moneyPage, findsNothing);
      expect(find.text('Catatan, kategori, atau dompet'), findsOneWidget);
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);

      await tester.enterText(input, 'Tunai');
      await tester.pumpAndSettle();
      expect(currentRow.hitTestable(), findsOneWidget);
      expect(olderRow.hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(currentRow).dy,
        lessThan(tester.getTopLeft(olderRow).dy),
      );

      await tester.enterText(input, 'SIMPANAN');
      await tester.pumpAndSettle();
      expect(currentRow, findsNothing);
      expect(olderRow.hitTestable(), findsOneWidget);
      expect(find.textContaining('2025'), findsOneWidget);
      expectLedgerState();

      await tester.tap(clear);
      await tester.pumpAndSettle();
      final clearedInput = tester.widget<EditableText>(input);
      expect(clearedInput.controller.text, isEmpty);
      expect(clearedInput.focusNode.hasFocus, isTrue);
      expect(clear, findsNothing);
      expect(olderRow, findsNothing);
      expectLedgerState();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(moneyPage, findsOneWidget);
      expect(
        find.text(monthTitle(selectedMonth)).hitTestable(),
        findsOneWidget,
      );
      expect(currentRow.hitTestable(), findsOneWidget);
      expect(olderRow, findsNothing);
      expectLedgerState();
    },
  );

  const importedTransactions = {
    'negative expense with an archived wallet and category': MoneyTransaction(
      id: 'imported-expense',
      amount: -12000,
      kind: 'expense',
      categoryId: 'archived-category',
      accountId: 'archived-wallet',
      date: '2025-12-18',
      time: '18:00',
      createdAt: 4,
      note: 'Catatan impor lama',
      detail: '[{"name":"Kopi","qty":1,"price":12000}]',
    ),
    'expense without a category': MoneyTransaction(
      id: 'imported-uncategorized',
      amount: 8000,
      kind: 'expense',
      accountId: 'cash',
      date: '2025-12-19',
      time: '08:00',
      createdAt: 5,
      note: 'Catatan impor lama',
    ),
    'transfer into an archived wallet': MoneyTransaction(
      id: 'imported-transfer',
      amount: 6000,
      kind: 'transfer',
      accountId: 'cash',
      toAccountId: 'archived-wallet',
      date: '2025-12-21',
      time: '09:00',
      createdAt: 6,
      note: 'Catatan impor lama',
    ),
  };

  testWidgets('ledger filters include archived wallets and categories', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final db = _SearchDatabase(
      imported: [
        for (final transaction in importedTransactions.values)
          transaction.copyWith(note: transaction.id),
      ],
    );
    final store = MoneyStore(
      CategoryDao(db),
      AccountDao(db),
      MoneyTransactionDao(db),
    );
    addTearDown(store.dispose);
    await store.init();
    await store.setMonth(DateTime(2025, 12));
    final total = store.totalBalance;
    final archived = store.balanceForAccount('archived-wallet');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: EsokTheme.dark(),
          home: const Scaffold(body: MoneyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder.hitTestable());
      await tester.pumpAndSettle();
    }

    Future<void> choose(String picker, String value) async {
      await tap(find.byKey(ValueKey(picker)));
      await tap(find.text(value).hitTestable().last);
    }

    final filter = find.widgetWithText(TextButton, 'Filter');
    final apply = find.text('Terapkan');
    final transfer = find.text('imported-transfer');
    final expense = find.text('imported-expense');
    final uncategorized = find.text('imported-uncategorized');
    await tap(filter);
    await choose('Dompet', 'Dompet lama (arsip)');
    await tap(apply);
    expect(transfer, findsOneWidget);
    expect(expense, findsOneWidget);
    expect(uncategorized, findsNothing);

    await tap(filter);
    await choose('Kategori', 'Belanja lama (arsip)');
    await tap(apply);
    expect(expense, findsOneWidget);
    expect(transfer, findsNothing);
    expect(uncategorized, findsNothing);
    expect(find.textContaining('1 dari 4 transaksi'), findsOneWidget);

    await tap(filter);
    await tap(find.widgetWithText(ChoiceChip, 'Transfer'));
    expect(find.byKey(const ValueKey('Kategori')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(expense, findsOneWidget);
    expect(transfer, findsNothing);

    await tap(filter);
    await choose('Dompet', 'Semua dompet');
    await choose('Kategori', 'Tanpa kategori');
    await tap(apply);
    expect(uncategorized, findsOneWidget);
    expect(transfer, findsNothing);
    expect(expense, findsNothing);

    await tap(find.widgetWithText(TextButton, 'Reset filter'));
    expect(transfer, findsOneWidget);
    final list = find.descendant(
      of: find.byType(MoneyPage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(expense, 200, scrollable: list);
    expect(expense, findsOneWidget);
    expect(uncategorized, findsOneWidget);
    expect(store.totalBalance, total);
    expect(store.balanceForAccount('archived-wallet'), archived);
  });

  testWidgets('date filter uses the ledger month and keeps monthly totals', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final db = _SearchDatabase(
      imported: [
        importedTransactions.values.first.copyWith(note: 'Pengeluaran lama'),
      ],
    );
    final store = MoneyStore(
      CategoryDao(db),
      AccountDao(db),
      MoneyTransactionDao(db),
    );
    addTearDown(store.dispose);
    await store.init();
    await store.setMonth(DateTime(2025, 12));
    final total = store.totalBalance;
    final expense = store.monthExpense;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: EsokTheme.light(),
          home: const Scaffold(body: MoneyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder.hitTestable());
      await tester.pumpAndSettle();
    }

    final filter = find.widgetWithText(TextButton, 'Filter');
    final apply = find.text('Terapkan');
    final transfer = find.text('Pemindahan Desember');
    final oldExpense = find.text('Pengeluaran lama');

    Future<void> selectDay() async {
      await tap(filter);
      await tap(find.text('Sepanjang bulan'));
      final calendar = find.byType(CalendarSheet);
      final picker = tester.widget<CalendarSheet>(calendar);
      expect(picker.initialDate, DateTime(2025, 12));
      expect(picker.lockToInitialMonth, isTrue);
      await tap(find.bySemanticsLabel('Sabtu, 20 Desember 2025'));
      expect(find.text('20 Desember'), findsOneWidget);
      await tap(apply);
    }

    await selectDay();
    expect(transfer, findsOneWidget);
    expect(oldExpense, findsNothing);
    expect(find.textContaining('1 dari 2 transaksi'), findsOneWidget);
    expect(store.totalBalance, total);
    expect(store.monthExpense, expense);

    await tap(filter);
    await tap(find.byTooltip('Hapus filter tanggal'));
    await tap(apply);
    expect(oldExpense, findsOneWidget);
    expect(find.textContaining('1 dari 2 transaksi'), findsNothing);

    await selectDay();
    await store.setMonth(DateTime(2026, 1));
    await tester.pumpAndSettle();
    expect(find.text('Belanja Januari'), findsOneWidget);
    await store.setMonth(DateTime(2025, 12));
    await tester.pumpAndSettle();
    expect(oldExpense, findsOneWidget);
    expect(find.textContaining('1 dari 2 transaksi'), findsNothing);
  });

  for (final MapEntry(key: description, value: original)
      in importedTransactions.entries) {
    testWidgets('search edit changes only the note: $description', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 892);
      addTearDown(tester.view.reset);

      final backup = BackupService.toJsonMap(
        BackupData(
          tasks: const [],
          accounts: _SearchDatabase.accounts,
          categories: _SearchDatabase.categories,
          transactions: [original],
        ),
      );
      final parsed = await BackupService.parseJsonBytes(
        Uint8List.fromList(utf8.encode(jsonEncode(backup))),
      );
      final db = _SearchDatabase(imported: parsed.transactions);
      final store = MoneyStore(
        CategoryDao(db),
        AccountDao(db),
        MoneyTransactionDao(db),
      );
      final settings = SettingsStore();
      addTearDown(store.dispose);
      addTearDown(settings.dispose);
      SharedPreferences.setMockInitialValues({'sound_enabled': false});
      await settings.init();
      const query = 'Catatan impor';
      const newNote = 'Catatan impor diperbarui';
      final selectedMonth = DateTime(2026, 1);
      await store.init();
      await store.setMonth(selectedMonth);
      final totalBefore = store.totalBalance;
      final balancesBefore = {
        for (final account in store.accounts)
          account.id: store.balanceForAccount(account.id),
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            theme: EsokTheme.dark(),
            home: const Scaffold(body: MoneyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.text('Cari transaksi');
      final oldRow = find.text(original.note!);
      expect(oldRow, findsNothing);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      final input = find.byType(EditableText);
      await tester.enterText(input, query);
      await tester.pumpAndSettle();
      await tester.tap(oldRow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      final editor = find.byType(TxEditorPage);
      final note = find.descendant(of: editor, matching: input);
      await tester.ensureVisible(note);
      expect(tester.widget<EditableText>(note).controller.text, original.note);
      await tester.enterText(note, newNote);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Simpan');
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(editor, findsNothing);
      expect(tester.widget<EditableText>(input).controller.text, query);
      expect(find.text(newNote).hitTestable(), findsOneWidget);
      expect(oldRow, findsNothing);
      final saved = await store.allTransactions();
      expect(saved, hasLength(3));
      expect(
        saved.singleWhere((row) => row.id == original.id).toMap(),
        original.copyWith(note: newNote).toMap(),
      );
      expect(store.month, selectedMonth);
      expect(store.totalBalance, totalBefore);
      for (final MapEntry(key: id, value: balance) in balancesBefore.entries) {
        expect(store.balanceForAccount(id), balance, reason: 'Wallet $id');
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MoneyPage), findsOneWidget);
      expect(
        find.text(monthTitle(selectedMonth)).hitTestable(),
        findsOneWidget,
      );
      expect(find.text(newNote), findsNothing);
    });
  }
}

class _SearchDatabase extends Fake implements Database {
  _SearchDatabase({List<MoneyTransaction> imported = const []})
    : _transactions = [
        const MoneyTransaction(
          id: 'january-expense',
          amount: 25000,
          kind: 'expense',
          accountId: 'cash',
          date: '2026-01-06',
          createdAt: 1,
          note: 'Belanja Januari',
        ).toMap(),
        const MoneyTransaction(
          id: 'december-transfer',
          amount: 10000,
          kind: 'transfer',
          accountId: 'cash',
          toAccountId: 'savings',
          date: '2025-12-20',
          createdAt: 0,
          note: 'Pemindahan Desember',
        ).toMap(),
        for (final transaction in imported) transaction.toMap(),
      ];

  final List<Map<String, Object?>> _transactions;

  static const categories = [
    MoneyCategory(
      id: 'active-category',
      name: 'Belanja',
      kind: 'expense',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
    ),
    MoneyCategory(
      id: 'archived-category',
      name: 'Belanja lama',
      kind: 'expense',
      sortOrder: 1,
      archived: true,
      createdAt: 1,
    ),
  ];

  static const accounts = [
    Account(
      id: 'cash',
      name: 'Tunai',
      type: 'cash',
      sortOrder: 0,
      archived: false,
      createdAt: 0,
      openingBalance: 100000,
    ),
    Account(
      id: 'savings',
      name: 'Simpanan',
      type: 'bank',
      sortOrder: 1,
      archived: false,
      createdAt: 1,
    ),
    Account(
      id: 'archived-wallet',
      name: 'Dompet lama',
      type: 'bank',
      sortOrder: 2,
      archived: true,
      createdAt: 2,
      openingBalance: 50000,
    ),
  ];

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
  }) async => switch (table) {
    'categories' => [for (final category in categories) category.toMap()],
    'accounts' => [for (final account in accounts) account.toMap()],
    'transactions' when where == null => List.of(_transactions),
    _ => throw ArgumentError.value(table, 'table'),
  };

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table != 'transactions' || where != 'id = ?') {
      throw ArgumentError('Unexpected update on $table with $where');
    }
    final index = _transactions.indexWhere(
      (row) => row['id'] == whereArgs?.single,
    );
    if (index == -1) return 0;
    _transactions[index] = {..._transactions[index], ...values};
    return 1;
  }
}
