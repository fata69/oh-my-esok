import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/payday_dao.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/ui/payday_page.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class _Ledger extends ChangeNotifier implements MoneyStore {
  _Ledger({this.balance = 900000, bool includeLater = false}) {
    final now = today();
    final next = DateTime(now.year, now.month, now.day + 2);
    paydayPlan = PaydayPlan(
      schedule: PaydaySchedule(
        accountId: wallet.id,
        date: dateKey(next),
        monthly: true,
      ),
      bills: [
        PlannedBill(
          id: 'bill',
          name: 'Internet rumah',
          amount: 200000,
          accountId: wallet.id,
          date: dateKey(now),
          monthly: true,
        ),
        if (includeLater)
          PlannedBill(
            id: 'later',
            name: 'Tagihan bulan depan',
            amount: 100000,
            accountId: wallet.id,
            date: dateKey(DateTime(now.year, now.month + 1, now.day)),
            monthly: false,
          ),
      ],
    );
  }

  static const wallet = Account(
    id: 'cash',
    name: 'Tunai',
    type: 'cash',
    sortOrder: 0,
    archived: false,
    createdAt: 0,
  );

  @override
  late PaydayPlan paydayPlan;
  final int balance;

  MoneyTransaction get expense => MoneyTransaction(
    id: 'existing',
    amount: 200000,
    kind: 'expense',
    accountId: wallet.id,
    date: dateKey(today()),
    createdAt: 0,
    note: 'Internet tercatat',
  );

  @override
  List<Account> get activeAccounts => [wallet];

  @override
  Account? accountById(String id) => id == wallet.id ? wallet : null;

  @override
  String accountName(String? id) => id == wallet.id ? wallet.name : '';

  @override
  int balanceForAccount(String id) => id == wallet.id ? balance : 0;

  @override
  List<MoneyTransaction> availableBillPayments(PlannedBill bill) =>
      paydayPlan.payments.isEmpty ? [expense] : [];

  @override
  Future<MoneyTransaction?> transactionById(String id) async =>
      id == expense.id ? expense : null;

  @override
  Future<void> linkBillPayment(
    PlannedBill bill,
    String dueDate,
    String id,
  ) async {
    paydayPlan = PaydayPlan(
      schedule: paydayPlan.schedule,
      bills: paydayPlan.bills,
      payments: [
        BillPayment(billId: bill.id, dueDate: dueDate, transactionId: id),
      ],
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(WidgetTester tester, _Ledger store, {double scale = 1}) =>
    tester.pumpWidget(
      ChangeNotifierProvider<MoneyStore>.value(
        value: store,
        child: MaterialApp(
          theme: EsokTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Consumer<MoneyStore>(
            builder: (context, store, _) =>
                Scaffold(body: PaydayOverview(store: store)),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Uang can link a recorded bill and refresh the forecast', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = _Ledger();
    addTearDown(store.dispose);
    await _mount(tester, store);

    Future<void> tapLabel(String label) async {
      await tester.tap(find.text(label).hitTestable());
      await tester.pumpAndSettle();
    }

    await tapLabel('Sampai Gajian');
    expect(find.text('Perkiraan sisa setelah tagihan'), findsOneWidget);
    expect(find.text('Rp 700.000'), findsWidgets);
    await tapLabel('Internet rumah');
    await tapLabel('Hubungkan transaksi');
    await tapLabel('Internet tercatat');
    await tapLabel('Hubungkan');
    expect(find.text('Pembayaran terhubung'), findsOneWidget);
    expect(find.text('Catat pembayaran'), findsNothing);
    expect(store.paydayPlan.payments.single.transactionId, store.expense.id);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Rp 900.000'), findsWidgets);
    expect(find.byType(TxEditorPage), findsNothing);
  });

  testWidgets(
    'payday uses one bottom add action and reveals other bills inline',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 680);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);
      final store = _Ledger(balance: 100000, includeLater: true);
      addTearDown(store.dispose);
      await _mount(tester, store, scale: 1.4);

      await tester.tap(find.text('Sampai Gajian'));
      await tester.pumpAndSettle();
      final add = find.text('Tambah tagihan').hitTestable();
      expect(add, findsOneWidget);
      expect(tester.getCenter(add).dy, greaterThan(580));
      expect(tester.getRect(add).bottom, lessThan(656));
      expect(find.text('Rp 100.000'), findsOneWidget);
      expect(find.text('Sisa menjelang gajian'), findsNothing);
      expect(find.text('Kelola semua tagihan'), findsNothing);
      expect(find.text('Tagihan bulan depan'), findsNothing);

      final others = find.text('Tagihan di luar perkiraan');
      await tester.scrollUntilVisible(others, 90);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .widgetWithText(ExpansionTile, 'Tagihan di luar perkiraan')
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      final bill = find.text('Tagihan bulan depan');
      await tester.scrollUntilVisible(bill, 90);
      await tester.pumpAndSettle();
      await tester.tap(bill.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Catat pembayaran'), findsOneWidget);
      expect(find.text('Tagihan di luar perkiraan'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Simpan tagihan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
