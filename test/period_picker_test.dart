import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/state/task_store.dart';
import 'package:jadwal/ui/calendar_sheet.dart';
import 'package:jadwal/ui/tab_layout.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/day_review_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('filter calendar stays in its month without an agenda store', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    DateTime? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showEsokPickerSheet<DateTime>(
                  context,
                  builder: (_) => CalendarSheet(
                    initialDate: DateTime(1901, 3, 1),
                    title: 'Pilih tanggal transaksi',
                    lockToInitialMonth: true,
                    showAgenda: false,
                  ),
                );
              },
              child: const Text('Pilih filter'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pilih filter'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal transaksi'), findsOneWidget);
    expect(find.text('Kembali ke hari ini'), findsNothing);
    expect(find.bySemanticsLabel('Senin, 25 Februari 1901'), findsNothing);
    final previous = find.ancestor(
      of: find.byTooltip('Bulan sebelumnya'),
      matching: find.byType(IconButton),
    );
    final next = find.ancestor(
      of: find.byTooltip('Bulan berikutnya'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(
      find.bySemanticsLabel('Sabtu, 2 Maret 1901').hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(selection, DateTime(1901, 3, 2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'six-week calendar scrolls at large text and keeps close visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(760, 360);
      tester.view.padding = const FakeViewPadding(top: 20, bottom: 16);
      tester.view.viewPadding = const FakeViewPadding(top: 20, bottom: 16);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final store = TaskStore(MemoryTaskDao([], []));
      addTearDown(store.dispose);
      DateTime? selection;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: EsokTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selection = await showEsokPickerSheet<DateTime>(
                      context,
                      builder: (_) =>
                          CalendarSheet(initialDate: DateTime(2026, 3, 27)),
                    );
                  },
                  child: const Text('Buka kalender'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka kalender'));
      await tester.pumpAndSettle();
      final close = find.byTooltip('Tutup').hitTestable();
      expect(close, findsOneWidget);
      expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
      expect(find.text('Maret 2026'), findsOneWidget);
      final panel = find
          .descendant(
            of: find.byType(EsokPickerSheet),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(panel).width, lessThanOrEqualTo(480));
      final calendarDate = find.bySemanticsLabel('Selasa, 31 Maret 2026');
      final day = find
          .ancestor(of: find.text('31'), matching: find.byType(InkWell))
          .last;
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      expect(calendarDate.hitTestable(), findsOneWidget);
      expect(close, findsOneWidget);
      expect(find.text('Kembali ke hari ini').hitTestable(), findsOneWidget);
      await tester.tap(calendarDate.hitTestable());
      await tester.pumpAndSettle();
      expect(selection, DateTime(2026, 3, 31));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
