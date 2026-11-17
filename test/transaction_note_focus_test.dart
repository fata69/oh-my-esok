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
  for (final (size, scale) in [
    (const Size(412, 892), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(760, 360), 2.0),
  ]) {
    testWidgets('all transaction keys fit above the footer at $size ×$scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = tester.view.padding;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

      void checkKeys() {
        final footer = find.widgetWithText(TextButton, 'Pindai struk');
        expect(footer.hitTestable(), findsOneWidget);
        for (final key in [
          for (var digit = 0; digit <= 9; digit++) find.text('$digit'),
          find.text('000'),
          find.byIcon(Icons.backspace_outlined),
        ]) {
          expect(key.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(key).bottom,
            lessThan(tester.getTopLeft(footer).dy),
          );
        }
        expect(tester.takeException(), isNull);
      }

      checkKeys();
      await tester.ensureVisible(find.text('Baru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Baru').hitTestable());
      await tester.pumpAndSettle();
      checkKeys();
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 8'), findsOneWidget);
      await tester.ensureVisible(find.text('Pindah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pindah').hitTestable());
      await tester.pumpAndSettle();
      checkKeys();
    });
  }

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
