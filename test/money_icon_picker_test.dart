import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/ui/money_icon_catalog.dart';
import 'package:jadwal/ui/money_icon_picker.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('unknown category and wallet keys resolve to generic vector icons', () {
    expect(
      categoryIconSpec('../makan', categoryId: 'cat-exp-makan').glyph,
      Icons.sell_outlined,
    );
    expect(categoryIconSpec(null, categoryId: 'cat-exp-makan').id, 'makan');
    expect(categoryIconSpec('jual').glyph, Icons.storefront_outlined);
    expect(walletIconSpec('bank', null).id, 'bank');
    expect(
      walletIconSpec('bank', 'unknown').glyph,
      Icons.account_balance_wallet_outlined,
    );
  });

  testWidgets('wallet picker selects, cancels, and resets at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    String? value;
    final updates = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MoneyIconField(
              iconSet: MoneyIconSet.wallet,
              value: value,
              automatic: walletIconSpec('bank', null),
              onChanged: (next) => setState(() {
                updates.add(next);
                value = next;
              }),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ikon · Otomatis'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Otomatis'), findsOneWidget);
    await tester.ensureVisible(find.text('Tabungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tabungan'));
    await tester.pumpAndSettle();
    expect(find.text('Ikon · Tabungan'), findsOneWidget);

    await tester.tap(find.text('Ikon · Tabungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(updates, ['savings']);

    await tester.tap(find.text('Ikon · Tabungan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otomatis'));
    await tester.pumpAndSettle();
    expect(updates, ['savings', null]);
    expect(find.text('Ikon · Otomatis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
