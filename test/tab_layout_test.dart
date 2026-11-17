import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/app.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:jadwal/state/task_store.dart';
import 'package:jadwal/ui/home_page.dart';
import 'package:jadwal/ui/money_page.dart';
import 'package:jadwal/ui/reports_page.dart';
import 'package:jadwal/ui/settings_page.dart';
import 'package:jadwal/ui/task_editor.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:jadwal/util/format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'support/day_review_fixture.dart';

void main() {
  const makePreviews = bool.fromEnvironment('ESOK_UI_PREVIEWS');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    final font = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(
        rootBundle.load(
          'assets/fonts/plus-jakarta-sans/PlusJakartaSans-$weight.ttf',
        ),
      );
    }
    await font.load();
    if (makePreviews) {
      final sdk = Platform.environment['FLUTTER_ROOT'];
      final icons = File(
        '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  });

  Future<SettingsStore> launch(
    WidgetTester tester, {
    int notes = 0,
    bool preview = false,
  }) async {
    // Only the native I/O boundaries use test data. The shell, pages, stores,
    // tab state and theme changes all use the production implementations.
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final (channel, response) in [
      ('home_widget', null),
      ('home_widget/updates', null),
      ('flutter_timezone', 'Asia/Jakarta'),
      ('dexterous.com/flutter/local_notifications', true),
    ]) {
      final bridge = MethodChannel(channel);
      messenger.setMockMethodCallHandler(bridge, (_) async => response);
      addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
    }
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Oh My Esok',
      packageName: 'com.ohmyesok.app',
      version: '0.1.0',
      buildNumber: '17',
      buildSignature: '',
    );
    final settings = SettingsStore();
    final tasks = TaskStore(
      MemoryTaskDao([
        for (var i = 0; i < notes; i++)
          Task(
            id: 'task-$i',
            title: preview
                ? ['Tinjau agenda', 'Kirim catatan rapat', 'Belanja rumah'][i]
                : 'Catatan ke-$i',
            scheduledDate: dateKey(today()),
            isDone: false,
            createdAt: i,
          ),
      ], []),
    );
    final db = _LedgerDatabase(preview: preview);
    final money = MoneyStore(
      CategoryDao(db),
      AccountDao(db),
      MoneyTransactionDao(db),
    );
    addTearDown(settings.dispose);
    addTearDown(tasks.dispose);
    addTearDown(money.dispose);
    await tasks.init();
    await money.init();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview-boundary'),
        child: EsokApp(store: tasks, moneyStore: money, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('Uang follows Gelap, Terang and Sistem while offscreen', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await launch(tester);

    Future<void> verifyLedger(Color canvas, Color ink, Color muted) async {
      await select(tester, 'Uang');
      final page = find.byType(MoneyPage);
      final title = find.descendant(
        of: page,
        matching: find.text('Oh My Esok'),
      );
      final label = find.text('TOTAL DANA');
      final row = find.text('Pengeluaran terakhir');
      expect(tester.widget<Text>(title).style?.color, ink);
      expect(tester.widget<Text>(label).style?.color, muted);
      expect(tester.widget<Text>(row).style?.color, ink);
      expect(Scaffold.of(tester.element(label)).widget.backgroundColor, canvas);
    }

    const dark = (Color(0xFF111111), Color(0xFFEEEEEE), Color(0xFFB4B4B4));
    const light = (Color(0xFFFCFCFC), Color(0xFF202020), Color(0xFF646464));
    await verifyLedger(dark.$1, dark.$2, dark.$3);
    for (final (mode, expected) in [
      ('Gelap', dark),
      ('Terang', light),
      ('Ikut sistem', dark),
    ]) {
      await select(tester, 'Setelan');
      await select(tester, mode);
      expect(tester.widget<Text>(find.text('Tema')).style?.color, expected.$2);
      await verifyLedger(expected.$1, expected.$2, expected.$3);
    }
    // Following the system must also react after the preference is selected.
    await select(tester, 'Hari');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    await verifyLedger(light.$1, light.$2, light.$3);
  });

  testWidgets('320 dp, large text: tabs, safe area and last actions work', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.systemGestureInsets = const FakeViewPadding(bottom: 56);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester, notes: 10);

    final nav = find.byKey(const ValueKey('floating-navigation'));
    final create = find.byKey(const ValueKey('bottom-create'));
    expect(tester.getRect(nav).bottom, closeTo(720 - 24 - 6, 0.01));
    for (final tab in ['Hari', 'Uang', 'Laporan', 'Setelan']) {
      final size = tester.getSize(find.bySemanticsLabel(tab));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    void verifyHeader(Type page) {
      final header = find.descendant(
        of: find.byType(page),
        matching: find.text('Oh My Esok'),
      );
      expect(tester.getTopLeft(header).dx, 24);
      expect(tester.getRect(header).top, greaterThanOrEqualTo(24));
      expect(tester.widget<Text>(header).style?.fontFamily, 'PlusJakartaSans');
    }

    void verifyDock() {
      final list = find.byType(ListView).first;
      expect(tester.getRect(list).bottom, lessThan(tester.getRect(create).top));
      expect(tester.getRect(create).bottom, lessThan(tester.getRect(nav).top));
      expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
    }

    verifyHeader(HomePage);
    verifyDock();
    expect(find.text('Tambah catatan').hitTestable(), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    final date = find.text(dateTitle(today()));
    final dateSize = tester.widget<Text>(date).style?.fontSize;
    final action = find.widgetWithText(InkWell, 'Catat pengeluaran');
    await tester.scrollUntilVisible(
      action,
      190,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.getRect(action).bottom, lessThan(tester.getRect(create).top));

    await select(tester, 'Uang');
    verifyHeader(MoneyPage);
    verifyDock();
    expect(find.text('Catat transaksi').hitTestable(), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    final now = today();
    expect(
      tester.widget<Text>(find.text(monthTitle(now))).style?.fontSize,
      dateSize,
    );

    final lastTransaction = find.text('Pengeluaran terakhir');
    await tester.scrollUntilVisible(
      lastTransaction,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final lastAmount = find.text('−987.654.321.012').last;
    expect(lastTransaction.hitTestable(), findsOneWidget);
    expect(lastAmount.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(lastAmount).bottom,
      lessThan(tester.getRect(create).top),
    );

    // Simulate the taller system navigation bar in three-button mode.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.systemGestureInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(tester.getRect(nav).bottom, closeTo(720 - 48 - 6, 0.01));

    await select(tester, 'Laporan');
    expect(find.byType(ReportsPage), findsOneWidget);
    expect(create, findsNothing);
    await select(tester, 'Setelan');
    expect(create, findsNothing);
    verifyHeader(SettingsPage);
    final license = find.text('Lisensi font');
    await tester.scrollUntilVisible(
      license,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(license.hitTestable(), findsOneWidget);
    expect(tester.getRect(license).bottom, lessThan(tester.getRect(nav).top));

    await select(tester, 'Hari');
    await tester.drag(find.byType(ListView).first, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    final expense = tester.widget<TxEditorPage>(find.byType(TxEditorPage));
    expect(expense.initialDate, today());
    expect(expense.initialKind, 'expense');
  });

  testWidgets('bottom actions respect the selected day and yield to editors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 420);
    tester.view.padding = const FakeViewPadding(top: 20, right: 24, bottom: 20);
    tester.view.viewPadding = tester.view.padding;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);

    final create = find.byKey(const ValueKey('bottom-create'));
    final nav = find.byKey(const ValueKey('floating-navigation'));
    expect(tester.getRect(create).left, greaterThan(tester.getRect(nav).right));
    await tester.tap(find.byTooltip('Hari berikutnya'));
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final editor = find.byType(TaskEditorSheet);
    expect(
      tester.widget<TaskEditorSheet>(editor).initialDate,
      today().add(const Duration(days: 1)),
    );
    expect(create.hitTestable(), findsNothing);
    final input = find
        .descendant(of: editor, matching: find.byType(EditableText))
        .first;
    tester.view.viewInsets = const FakeViewPadding(bottom: 175);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
    expect(create, findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    await select(tester, 'Uang');
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(TxEditorPage), findsOneWidget);
    expect(create.hitTestable(), findsNothing);
  });

  testWidgets('render the build 17 dock on production Hari and Uang', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 892);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.padding = tester.view.viewPadding;
    addTearDown(tester.view.reset);
    final settings = await launch(tester, notes: 3, preview: true);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await settings.setThemeMode(mode);
      await tester.pumpAndSettle();
      for (final tab in ['Hari', 'Uang']) {
        await select(tester, tab);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview-boundary')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final directory = Directory('build/v17-previews')
              ..createSync(recursive: true);
            File('${directory.path}/${tab.toLowerCase()}-${mode.name}.png')
                .writeAsBytesSync(bytes.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !makePreviews);
}

class _LedgerDatabase implements Database {
  _LedgerDatabase({required this.preview});

  final bool preview;

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
    return switch (table) {
      'accounts' => [
        const Account(
          id: 'cash',
          name: 'Tunai',
          type: 'cash',
          sortOrder: 0,
          archived: false,
          createdAt: 0,
        ).toMap(),
      ],
      'categories' => [],
      'transactions' => [
        if (whereArgs == null || whereArgs.contains(dateKey(today())))
          MoneyTransaction(
            id: 'last',
            note: preview ? 'Makan siang' : 'Pengeluaran terakhir',
            amount: preview ? 78000 : 987654321012,
            kind: 'expense',
            accountId: 'cash',
            date: dateKey(today()),
            createdAt: 0,
          ).toMap(),
        if (preview &&
            (whereArgs == null || whereArgs.contains(dateKey(today()))))
          MoneyTransaction(
            id: 'salary',
            note: 'Gaji',
            amount: 8200000,
            kind: 'income',
            accountId: 'cash',
            date: dateKey(today()),
            createdAt: 1,
          ).toMap(),
      ],
      _ => throw ArgumentError.value(table),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
