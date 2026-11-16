import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  testWidgets('transaction note keeps focus as the keyboard reduces height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final db = _UnusedDatabase();
    final store = MoneyStore(
      CategoryDao(db),
      AccountDao(db),
      MoneyTransactionDao(db),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: EsokTheme.light(),
          home: const TxEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final note = find.byType(EditableText);
    await tester.ensureVisible(note);
    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(note).focusNode.hasFocus, isTrue);

    // The real keyboard changes the editor from the tall to the compact layout.
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(note).focusNode.hasFocus, isTrue);
    tester.testTextInput.enterText('Catatan transaksi QA');
    await tester.pump();
    expect(find.text('Catatan transaksi QA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnusedDatabase implements Database {
  // Rendering the editor must not query or write the database.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
