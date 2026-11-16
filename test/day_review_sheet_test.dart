import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/ui/day_review_sheet.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/day_review_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await (FontLoader('PlusJakartaSans')
          ..addFont(
            rootBundle.load(
              'assets/fonts/plus-jakarta-sans/PlusJakartaSans-Regular.ttf',
            ),
          )
          ..addFont(
            rootBundle.load(
              'assets/fonts/plus-jakarta-sans/PlusJakartaSans-SemiBold.ttf',
            ),
          ))
        .load();
  });

  Future<void> openReview(
    WidgetTester tester,
    DayReviewFixture fixture, {
    ThemeData? theme,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? EsokTheme.light(),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDayReviewSheet(
                context,
                date: today(),
                service: fixture.service,
              ),
              child: const Text('Buka tinjauan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka tinjauan'));
    await tester.pumpAndSettle();
  }

  DayReviewFixture fixtureForToday() =>
      DayReviewFixture(tasks: [DayReviewFixture.task(date: today())]);

  Future<void> chooseInitialDate(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Jadwalkan ulang').first);
    await tester.tap(find.text('Jadwalkan ulang').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan catatan?'), findsOneWidget);
  }

  testWidgets('finish leaves every note and cash flow unchanged', (
    tester,
  ) async {
    final fixture = fixtureForToday();
    addTearDown(fixture.store.dispose);
    final before = fixture.dao.rows['note']!.toMap();
    await openReview(tester, fixture);

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Tutup hari'), findsNothing);
    expect(fixture.dao.rows['note']!.toMap(), before);
    expect(fixture.dao.moveCalls, 0);
    expect(fixture.events, isNot(contains('reminder')));
    expect(fixture.events, isNot(contains('widget')));
  });

  testWidgets('cancel date picker or confirmation never writes', (
    tester,
  ) async {
    final fixture = fixtureForToday();
    addTearDown(fixture.store.dispose);
    await openReview(tester, fixture);

    await tester.tap(find.text('Jadwalkan ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(fixture.dao.moveCalls, 0);

    await chooseInitialDate(tester);
    expect(fixture.dao.moveCalls, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(fixture.dao.moveCalls, 0);
    expect(fixture.dao.rows['note']!.scheduledDate, dateKey(today()));
  });

  testWidgets('confirmation moves one note and retains the reviewed day', (
    tester,
  ) async {
    final fixture = fixtureForToday();
    addTearDown(fixture.store.dispose);
    final source = today();
    await fixture.store.selectDate(source);
    await openReview(tester, fixture);
    await chooseInitialDate(tester);
    expect(fixture.dao.moveCalls, 0);

    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    final target = DateTime(source.year, source.month, source.day + 1);
    expect(fixture.dao.moveCalls, 1);
    expect(fixture.dao.rows['note']!.scheduledDate, dateKey(target));
    expect(fixture.store.selectedDate, source);
    expect(find.text('Belum selesai (0)'), findsOneWidget);
    expect(find.text('Jadwalkan ulang'), findsNothing);
    expect(fixture.scheduled.single.id, 'note');
    expect(tester.takeException(), isNull);
  });

  testWidgets('load error offers retry and a database failure keeps the note', (
    tester,
  ) async {
    final fixture = fixtureForToday()..dao.failRead = true;
    addTearDown(fixture.store.dispose);
    await openReview(tester, fixture);
    expect(find.text('Ringkasan belum bisa dimuat.'), findsOneWidget);

    fixture.dao.failRead = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum selesai (1)'), findsOneWidget);
    fixture.dao.failMove = true;
    await chooseInitialDate(tester);
    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    expect(find.text('Belum dipindahkan. Coba lagi.'), findsOneWidget);
    expect(fixture.dao.rows['note']!.scheduledDate, dateKey(today()));
    expect(fixture.scheduled, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post-commit retry never moves the note a second time', (
    tester,
  ) async {
    final fixture = fixtureForToday()..failReminder = true;
    addTearDown(fixture.store.dispose);
    await openReview(tester, fixture);
    await chooseInitialDate(tester);
    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pengingat belum diperbarui.'), findsOneWidget);
    expect(fixture.dao.moveCalls, 1);
    fixture.failReminder = false;
    await tester.tap(find.text('Coba sinkronkan lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Pembaruan selesai.'), findsOneWidget);
    expect(fixture.dao.moveCalls, 1);
    expect(fixture.scheduled, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and all-done states distinguish the day status', (
    tester,
  ) async {
    for (final done in [false, true]) {
      final fixture = DayReviewFixture(
        tasks: done ? [DayReviewFixture.task(date: today(), done: true)] : [],
      );
      await openReview(tester, fixture);
      expect(
        find.text(
          done
              ? 'Semua catatan sudah selesai.'
              : 'Belum ada catatan di tanggal ini.',
        ),
        findsOneWidget,
      );
      expect(find.text('Jadwalkan ulang'), findsNothing);
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      fixture.store.dispose();
    }
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('320dp, scale $scale, dark $dark stays scrollable', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = DayReviewFixture(
          tasks: [
            DayReviewFixture.task(
              date: today(),
              title:
                  'Catatan panjang untuk meninjau jadwal tanpa memotong judul',
            ),
          ],
          transactions: [
            DayReviewFixture.transaction(
              'income',
              999999999999,
              date: dateKey(today()),
            ),
            DayReviewFixture.transaction(
              'expense',
              999999999999,
              date: dateKey(today()),
            ),
          ],
        );
        addTearDown(fixture.store.dispose);
        await openReview(
          tester,
          fixture,
          theme: dark ? EsokTheme.dark() : EsokTheme.light(),
          textScale: scale,
        );
        await tester.ensureVisible(find.text('Jadwalkan ulang'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Selesai')).height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
}
