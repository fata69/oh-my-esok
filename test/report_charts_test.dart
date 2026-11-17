import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
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
import 'package:jadwal/ui/reports_page.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previewDir = String.fromEnvironment('ESOK_REPORT_PREVIEW_DIR');
const _boundary = ValueKey('report-preview-boundary');
const _semanticScope = ValueKey('report-semantic-scope');
const _trend = ValueKey('report-trend');
const _daily = ValueKey('report-daily');
const _scrub = ValueKey('report-scrub');
const _date = ValueKey('report-point-date');

Future<void> _mount(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  double width = 320,
  double height = 880,
  double scale = 1,
  bool masked = false,
  bool signed = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'hide_amounts': masked});
  final settings = SettingsStore();
  final money = MoneyStore(_Categories(), _Accounts(), _Transactions(signed));
  addTearDown(settings.dispose);
  addTearDown(money.dispose);
  await settings.init();
  await money.init();
  await money.setMonth(DateTime(2026, 11));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: money),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: EsokTheme.light(),
          darkTheme: EsokTheme.dark(),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Semantics(
              key: _semanticScope,
              container: true,
              explicitChildNodes: true,
              child: const ReportsPage(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inside(Key root, Key child) =>
    find.descendant(of: find.byKey(root), matching: find.byKey(child));

Finder get _reportScroll => find
    .descendant(
      of: find.byKey(const PageStorageKey('reports')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180, scrollable: _reportScroll);
  await tester.pumpAndSettle();
}

String? _readDate(WidgetTester tester, Key chart) =>
    tester.widget<Text>(_inside(chart, _date)).data;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    if (_previewDir.isEmpty) return;
    final font = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(
        rootBundle.load(
          'assets/fonts/plus-jakarta-sans/PlusJakartaSans-$weight.ttf',
        ),
      );
    }
    await font.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final fontFile = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
          ))
          .load();
    }
  });

  testWidgets('trend snaps by tap/drag and months expose exact amounts', (
    tester,
  ) async {
    await _mount(tester);
    final plot = _inside(_trend, _scrub);
    await _reveal(tester, plot);
    expect(_readDate(tester, _trend), 'Nov 2026');
    final rect = tester.getRect(plot);
    await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
    await tester.pumpAndSettle();
    expect(_readDate(tester, _trend), 'Jun 2026');
    expect(find.text('Rp 123.456'), findsOneWidget);
    await tester.dragFrom(
      Offset(rect.left + 5, rect.center.dy),
      Offset(rect.width * 0.8 - 5, 0),
    );
    await tester.pumpAndSettle();
    expect(_readDate(tester, _trend), 'Okt 2026');
    expect(find.text('Rp 432.109'), findsOneWidget);

    final button = _inside(_trend, const ValueKey('report-month-0'));
    await tester.ensureVisible(button);
    expect(tester.getSemantics(button).label, 'Juni 2026');
    expect(tester.getSemantics(button).value, contains('Rp 123.456'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(_readDate(tester, _trend), 'Jun 2026');
  });

  testWidgets(
    'daily chart preserves signs, snaps to exact amounts and exposes days',
    (tester) async {
      await _mount(tester, signed: true);
      final plot = _inside(_daily, _scrub);
      await _reveal(tester, plot);
      expect(_readDate(tester, _daily), '30 November 2026');
      final chart = tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(_daily),
          matching: find.byType(BarChart),
        ),
      );
      expect(chart.data.minY, lessThan(0));
      expect(chart.data.maxY, greaterThan(0));
      expect(chart.data.barGroups[1].barRods.last.toY, 654321);
      expect(
        chart.data.barGroups.every(
          (group) => group.barRods.every((rod) => rod.fromY == 0),
        ),
        isTrue,
      );
      expect(chart.data.extraLinesData.horizontalLines.single.y, 0);
      expect(chart.duration, Duration.zero);
      final rect = tester.getRect(plot);
      await tester.tapAt(
        Offset(rect.left + rect.width * 1.5 / 30, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(_readDate(tester, _daily), '2 November 2026');
      expect(find.text('−Rp 654.321'), findsWidgets);
      await _reveal(tester, find.text('Rincian per hari'));
      await tester.tap(find.text('Rincian per hari'));
      await tester.pumpAndSettle();
      expect(find.text('1 November'), findsWidgets);
    },
  );

  testWidgets('masked report has no plots, numeric labels or value semantics', (
    tester,
  ) async {
    await _mount(tester, masked: true, signed: true, scale: 1.55);
    for (final section in [
      'Selisih bulan',
      'Tren 6 bulan',
      'Arus kas harian',
      'Pengeluaran per kategori',
    ]) {
      await _reveal(tester, find.text(section));
      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Rp '), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      final semantics = tester.getSemantics(find.byKey(_semanticScope));
      expect(
        semantics.toStringDeep(),
        isNot(matches(r'Rp |123\.456|654\.321')),
      );
    }
    expect(find.text('Rincian per hari'), findsNothing);
    expect(find.text('Grafik dan nominal disembunyikan.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320 dp at large text preserves category controls and signed fallback',
    (tester) async {
      await _mount(tester, signed: true, scale: 1.55);
      await _reveal(tester, _inside(_trend, _scrub));
      await _reveal(tester, _inside(_daily, _scrub));
      await _reveal(tester, find.text('Pengeluaran per kategori'));
      await _reveal(tester, find.text('Tanpa kategori'));
      expect(
        find.text('Proporsi tidak ditampilkan karena total bertanda atau nol.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders actual Laporan charts in ${mode.name}', (
      tester,
    ) async {
      await _mount(tester, mode: mode, width: 390, height: 1000);
      for (final (key, section) in [(_trend, 'tren'), (_daily, 'harian')]) {
        await _reveal(tester, _inside(key, _scrub));
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        final chartFinder = find.descendant(
          of: find.byKey(key),
          matching: find.byType(BarChart),
        );
        final widget = tester.widget<BarChart>(chartFinder);
        final plotHeight = tester.getSize(chartFinder).height;
        final colors = Theme.of(tester.element(find.byKey(key))).colorScheme;
        final luminance = colors.surface.computeLuminance();
        for (final rod in widget.data.barGroups.expand(
          (group) => group.barRods,
        )) {
          if (rod.toY == 0) continue;
          final rounding = rod.borderRadius!;
          final radius = rounding.topLeft.y + rounding.bottomLeft.y;
          final drawnHeight =
              rod.toY.abs() /
              (widget.data.maxY - widget.data.minY) *
              plotHeight;
          expect(radius, lessThanOrEqualTo(drawnHeight + .01));
          final other = rod.color!.computeLuminance();
          final contrast = (luminance > other)
              ? (luminance + .05) / (other + .05)
              : (other + .05) / (luminance + .05);
          expect(
            contrast,
            greaterThanOrEqualTo(3),
            reason: '${mode.name} volume chart contrast',
          );
        }
        if (_previewDir.isEmpty) continue;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundary),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          Directory(_previewDir).createSync(recursive: true);
          File('$_previewDir/laporan-$section-${mode.name}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      await _reveal(tester, find.text('Pengeluaran per kategori'));
      expect(find.byKey(const ValueKey('report-allocation-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Accounts implements AccountDao {
  @override
  Future<List<Account>> all() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Categories implements CategoryDao {
  @override
  Future<List<MoneyCategory>> all() async => const [
    MoneyCategory(
      id: 'food',
      name: 'Makan dan kebutuhan rumah',
      kind: 'expense',
      sortOrder: 0,
      archived: true,
      createdAt: 0,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transactions implements MoneyTransactionDao {
  _Transactions(this.signed);
  final bool signed;

  @override
  Future<List<MoneyTransaction>> all() async => [
    for (final (date, kind, value, category) in [
      ('2026-06-08', 'income', 123456, null),
      ('2026-07-11', 'expense', 75000, null),
      ('2026-08-08', 'income', 820000, null),
      ('2026-08-18', 'expense', 440000, null),
      ('2026-09-17', 'income', 560000, null),
      ('2026-10-21', 'expense', 432109, null),
      ('2026-11-02', 'expense', signed ? -654321 : 654321, null),
      ('2026-11-07', 'income', 830000, null),
      ('2026-11-12', 'income', 190000, null),
      ('2026-11-17', 'expense', 900000, 'food'),
      ('2026-11-25', 'expense', 280000, 'food'),
      ('2026-11-30', 'income', 370000, null),
    ])
      MoneyTransaction(
        id: '$date-$kind',
        amount: value,
        kind: kind,
        accountId: 'test',
        date: date,
        createdAt: 0,
        categoryId: category,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
