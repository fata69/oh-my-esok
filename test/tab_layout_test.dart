import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/app.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/account_dao.dart';
import 'package:jadwal/data/category.dart';
import 'package:jadwal/data/category_dao.dart';
import 'package:jadwal/data/day_note.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/money_transaction_dao.dart';
import 'package:jadwal/data/note_dao.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/state/money_store.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:jadwal/state/task_store.dart';
import 'package:jadwal/ui/calendar_sheet.dart';
import 'package:jadwal/ui/agenda_loading.dart';
import 'package:jadwal/ui/home_page.dart';
import 'package:jadwal/ui/money_page.dart';
import 'package:jadwal/ui/note_editor_page.dart';
import 'package:jadwal/ui/reports_page.dart';
import 'package:jadwal/ui/settings_page.dart';
import 'package:jadwal/ui/tab_layout.dart';
import 'package:jadwal/ui/task_editor.dart';
import 'package:jadwal/ui/tx_editor_page.dart';
import 'package:jadwal/util/format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
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
    int categoryCount = 0,
    bool noteStorage = false,
    bool preview = false,
    Future<EsokApp> Function(EsokApp)? initialize,
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
    final taskDao = MemoryTaskDao([
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
    ], []);
    final tasks = TaskStore(
      taskDao,
      noteDao: noteStorage ? _MemoryNoteDao(taskDao) : null,
    );
    final db = _LedgerDatabase(preview: preview, categoryCount: categoryCount);
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
    final app = EsokApp(store: tasks, moneyStore: money, settings: settings);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview-boundary'),
        child: initialize == null
            ? app
            : EsokStartup(
                settings: settings,
                initialize: () => initialize(app),
              ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('cold start matches Hari layout and can retry startup', (
    tester,
  ) async {
    final first = Completer<EsokApp>();
    var attempts = 0;
    await launch(
      tester,
      notes: 3,
      initialize: (app) async {
        return ++attempts == 1 ? first.future : app;
      },
    );
    expect(find.byType(AgendaLoading), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    final dock = find.byKey(const ValueKey('floating-navigation'));
    final create = find.byKey(const ValueKey('bottom-create'));
    final period = find.byType(EsokPeriodHeader);
    final agenda = find.text('Agenda');
    final loadingDock = tester.getRect(dock);
    final loadingCreate = tester.getRect(create);
    final loadingPeriod = tester.getTopLeft(period);
    final loadingAgenda = tester.getTopLeft(agenda);
    expect(dock.hitTestable(), findsNothing);
    expect(create.hitTestable(), findsNothing);

    first.completeError(StateError('Database busy'));
    await tester.pumpAndSettle();
    expect(find.text('Aplikasi belum bisa dibuka.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AgendaLoading), findsNothing);
    expect(tester.getRect(dock), loadingDock);
    expect(tester.getRect(create), loadingCreate);
    expect(tester.getTopLeft(period), loadingPeriod);
    // Font layout rounds line heights to whole pixels.
    expect(tester.getTopLeft(agenda).dy, closeTo(loadingAgenda.dy, 2));
    expect(find.text('UANG HARI INI'), findsNothing);
  });

  testWidgets('Catatan uses its own layout and can move to Agenda', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await launch(tester, noteStorage: true);
    expect(find.text('Belum ada agenda').hitTestable(), findsOneWidget);
    expect(find.text('UANG HARI INI'), findsNothing);
    await tester.tap(find.text('Catatan').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('0 catatan'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah catatan'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(NoteEditorPage),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'Ide perjalanan');
    await tester.enterText(fields.last, 'Bawa payung');
    await tester.pump();
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await tester.tap(find.text('Lanjut menulis'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(fields.last).controller?.text,
      'Bawa payung',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView).hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Tampilan daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView).hitTestable(), findsNothing);
    expect(find.text('Bawa payung').hitTestable(), findsOneWidget);
    expect(find.text('Urutkan').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Urutkan catatan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NoteSort.title.label).hitTestable());
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('note_sort'),
      'title',
    );
    await tester.tap(find.text('Ide perjalanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jadwalkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pakai jadwal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditorPage), findsNothing);
    expect(find.text('Ide perjalanan').hitTestable(), findsOneWidget);
    expect(find.text('Bawa payung').hitTestable(), findsOneWidget);
    expect(find.text('0 dari 1 selesai'), findsOneWidget);
    await tester.tap(find.text('Catatan').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('0 catatan'), findsOneWidget);
    expect(find.text('Ide perjalanan').hitTestable(), findsNothing);
    await tester.tap(find.text('Agenda').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ide perjalanan').hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pindahkan ke Catatan'));
    await tester.tap(find.text('Pindahkan ke Catatan').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindahkan').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('1 catatan'), findsOneWidget);
    expect(find.text('Ide perjalanan').hitTestable(), findsOneWidget);
  });

  testWidgets('Membuang perubahan catatan tidak mengubah isi tersimpan', (
    tester,
  ) async {
    await launch(tester, noteStorage: true);
    await tester.tap(find.text('Catatan').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draf sementara');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await tester.tap(find.text('Buang'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditorPage), findsNothing);
    expect(find.text('0 catatan'), findsOneWidget);
    expect(find.text('Draf sementara'), findsNothing);
  });

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
      final label = find.text('Saldo dompet aktif');
      final row = find.text('Pengeluaran terakhir');
      expect(tester.widget<Text>(title).style?.color, ink);
      expect(tester.widget<Text>(label).style?.color, muted);
      expect(tester.widget<Text>(row).style?.color, ink);
      expect(Scaffold.of(tester.element(label)).widget.backgroundColor, canvas);
    }

    const dark = (Color(0xFF000000), Color(0xFFF5F5F7), Color(0xFF98989F));
    const light = (Color(0xFFF2F2F7), Color(0xFF111113), Color(0xFF636366));
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
      final dock = tester.getRect(nav);
      final button = tester.getRect(create);
      // Content flows smoothly behind the floating Liquid Glass dock.
      expect(tester.getRect(list).bottom, greaterThan(dock.top));
      expect(button.left - dock.right, closeTo(8, .01));
      expect(button.center.dy, closeTo(dock.center.dy, 0.01));
      expect(
        button.left,
        greaterThan(tester.getRect(find.bySemanticsLabel('Setelan')).right),
      );
      expect(tester.getSize(create), const Size.square(52));
    }

    verifyHeader(HomePage);
    verifyDock();
    expect(find.byTooltip('Tambah agenda').hitTestable(), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    final date = find.text(dateTitle(today()));
    final dateSize = tester.widget<Text>(date).style?.fontSize;
    expect(find.text('Buku kas ›'), findsNothing);
    expect(find.text('Catat pengeluaran'), findsNothing);
    expect(find.text('Catat transaksi'), findsNothing);

    await select(tester, 'Uang');
    verifyHeader(MoneyPage);
    verifyDock();
    expect(find.byTooltip('Catat transaksi').hitTestable(), findsOneWidget);
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
    await tester.tap(find.byTooltip('Tambah agenda'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorSheet), findsOneWidget);
    expect(find.byType(TxEditorPage), findsNothing);
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
    expect(
      tester.getRect(create).left - tester.getRect(nav).right,
      closeTo(8, .01),
    );
    expect(
      tester.getCenter(create).dy,
      closeTo(tester.getCenter(nav).dy, 0.01),
    );
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

  testWidgets(
    'dock accessory animates without losing tab state or hit targets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);
      await launch(tester);
      final nav = find.byKey(const ValueKey('floating-navigation'));
      final slot = find.byKey(const ValueKey('create-accessory-slot'));
      final initial = tester.getSize(nav).width;
      expect(tester.getSize(nav).height, 56);
      expect(tester.getRect(nav).bottom, closeTo(844 - 24 - 6, .01));
      await tester.tap(find.bySemanticsLabel('Laporan').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      expect(tester.getSize(slot).width, inExclusiveRange(0, 60));
      expect(tester.getSize(nav).width, greaterThan(initial));
      expect(find.byKey(const ValueKey('bottom-create')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(slot).width, 0);
      await tester.tap(find.bySemanticsLabel('Uang').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      expect(tester.getSize(slot).width, inExclusiveRange(0, 60));
      final openWidth = tester.getSize(slot).width;
      await tester.tap(find.bySemanticsLabel('Setelan').hitTestable());
      await tester.pump();
      expect(tester.getSize(slot).width, closeTo(openWidth, .01));
      await tester.pump(const Duration(milliseconds: 50));
      final reverseWidth = tester.getSize(slot).width;
      expect(reverseWidth, lessThan(openWidth));
      await tester.tap(find.bySemanticsLabel('Uang').hitTestable());
      await tester.pump();
      expect(tester.getSize(slot).width, closeTo(reverseWidth, .01));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(slot).width, 60);
      expect(find.text('Pengeluaran terakhir').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('holding an inactive tab does not paint a second dock pill', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final settings = await launch(tester);
    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('floating-navigation'));
    final pill = find.byKey(const ValueKey('dock-selection'));
    final target = find.bySemanticsLabel('Uang').hitTestable();
    final initialCenter = tester.getCenter(pill);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview-boundary')),
    );
    final bounds = tester.getRect(dock);

    Future<List<int>?> pixels() => tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final rgba = (await image.toByteData())!;
        final bytes = rgba.buffer.asUint8List();
        return [
          for (var y = bounds.top.round(); y < bounds.bottom.round(); y++)
            ...Uint8List.sublistView(
              bytes,
              (y * image.width + bounds.left.round()) * 4,
              (y * image.width + bounds.right.round()) * 4,
            ),
        ];
      } finally {
        image.dispose();
      }
    });

    final idle = await pixels();
    expect(idle, isNotNull);
    final finger = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 550));
    expect(tester.getCenter(pill), initialCenter);
    expect(listEquals(await pixels(), idle), isTrue);

    await finger.up();
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(pill).dx,
      closeTo(tester.getCenter(target).dx, .01),
    );
  });

  testWidgets('dock selection keeps its momentum on a quick reverse tap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await launch(tester);
    final nav = find.byKey(const ValueKey('floating-navigation'));
    final selection = find.byKey(const ValueKey('dock-selection'));
    final hari = find.bySemanticsLabel('Hari').hitTestable();
    final uang = find.bySemanticsLabel('Uang').hitTestable();
    final dockBefore = tester.getRect(nav);
    final start = tester.getCenter(hari);
    final destination = tester.getCenter(uang);

    await tester.tap(uang);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final midway = tester.getCenter(selection);
    expect(midway.dx, inExclusiveRange(start.dx, destination.dx));
    expect(midway.dy, closeTo(start.dy, .01));

    await tester.tap(hari);
    await tester.pump();
    expect(tester.getCenter(selection).dx, closeTo(midway.dx, .01));
    await tester.pump(const Duration(milliseconds: 8));
    expect(tester.getCenter(selection).dx, greaterThan(midway.dx));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getCenter(selection).dx, closeTo(start.dx, .01));
    expect(tester.getRect(nav), dockBefore);
  });

  testWidgets('dock honours reduced motion and settles immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    final slot = find.byKey(const ValueKey('create-accessory-slot'));
    await tester.tap(find.bySemanticsLabel('Laporan').hitTestable());
    await tester.pump();
    expect(tester.getSize(slot).width, 0);
    await tester.tap(find.bySemanticsLabel('Uang').hitTestable());
    await tester.pump();
    expect(tester.getSize(slot).width, 60);
    expect(
      tester.getCenter(find.byKey(const ValueKey('dock-selection'))).dx,
      closeTo(
        tester.getCenter(find.bySemanticsLabel('Uang').hitTestable()).dx,
        .01,
      ),
    );
    expect(find.byTooltip('Catat transaksi').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'periods align and open the appropriate picker on all three tabs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await launch(tester);

      final day = find.byTooltip('Pilih tanggal').hitTestable();
      final center = tester.getCenter(day);
      expect(center.dx, 195);
      final left = tester.getCenter(find.byTooltip('Hari sebelumnya'));
      final right = tester.getCenter(find.byTooltip('Hari berikutnya'));
      expect(left.dx + right.dx, closeTo(center.dx * 2, .01));
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup').hitTestable());
      await tester.pumpAndSettle();

      await select(tester, 'Uang');
      final month = find.byTooltip('Pilih bulan').hitTestable();
      expect(tester.getCenter(month), center);
      await tester.tap(month);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pilih tahun').hitTestable());
      await tester.pumpAndSettle();
      final lastYear = today().year - 1;
      await tester.tap(find.text('$lastYear').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Januari $lastYear').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Januari $lastYear').hitTestable(), findsOneWidget);

      await select(tester, 'Laporan');
      expect(tester.getCenter(month), center);
      expect(find.text('Januari $lastYear').hitTestable(), findsOneWidget);
      await tester.tap(month);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulan ini').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(monthTitle(today())).hitTestable(), findsOneWidget);
    },
  );

  testWidgets('transaction filters leave the wallet summary intact', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await launch(tester, preview: true);
    await select(tester, 'Uang');
    final salary = find.text('Gaji');
    final meal = find.text('Makan siang');
    expect(salary, findsOneWidget);
    expect(meal, findsOneWidget);

    Future<void> filter(String type, {String? sort}) async {
      await tester.tap(find.widgetWithText(TextButton, 'Filter').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, type));
      if (sort != null) {
        await tester.tap(find.widgetWithText(ChoiceChip, sort));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terapkan').hitTestable());
      await tester.pumpAndSettle();
    }

    final total = find.text('8.122.000');
    final occurrences = total.evaluate().length;
    await filter('Pemasukan');
    expect(salary, findsOneWidget);
    expect(meal, findsNothing);
    // Only the date subtotal is hidden; the main and wallet totals stay.
    expect(total, findsNWidgets(occurrences - 1));
    await filter('Transfer');
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );
    await filter('Semua', sort: 'Terlama dulu');
    expect(tester.getTopLeft(salary).dy, lessThan(tester.getTopLeft(meal).dy));
    expect(total, findsNWidgets(occurrences));
  });

  testWidgets(
    'Catat shows more categories and creates or changes icons in place',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await launch(tester, categoryCount: 12);
      await select(tester, 'Uang');
      await tester.tap(find.byTooltip('Catat transaksi'));
      await tester.pumpAndSettle();

      final grid = find.byKey(const ValueKey('transaction-categories'));
      final firstTile = find.text('Kategori 1');
      expect(firstTile.hitTestable(), findsOneWidget);
      expect(tester.getSize(grid).height, inExclusiveRange(150, 180));
      await tester.tap(find.text('Baru').hitTestable());
      await tester.pumpAndSettle();

      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Nama kategori baru',
      );
      await tester.enterText(name, 'Jajan baru');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(find.text('7').hitTestable(), findsNothing);
      await tester.tap(find.text('Pilih ikon').hitTestable());
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makanan').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text, 'Jajan baru');
      await tester.tap(find.text('Tambah').hitTestable());
      await tester.pumpAndSettle();

      final store = tester
          .element(find.byType(TxEditorPage))
          .read<MoneyStore>();
      MoneyCategory created() => store.expenseCategories.singleWhere(
        (category) => category.name == 'Jajan baru',
      );
      expect(created().iconId, 'makan');
      await tester.tap(find.text('Ubah ikon').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minuman').hitTestable());
      await tester.pumpAndSettle();
      expect(created().iconId, 'minuman');
    },
  );

  testWidgets(
    'Catat keeps the amount keypad mounted through Android IME insets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      addTearDown(tester.view.reset);
      await launch(tester, categoryCount: 12);
      await select(tester, 'Uang');
      await tester.tap(find.byTooltip('Catat transaksi'));
      await tester.pumpAndSettle();

      final keypad = find.byKey(const ValueKey('transaction-keypad'));
      final mountedKeypad = tester.element(keypad);
      final grid = find.byKey(const ValueKey('transaction-categories'));
      final categoryHeight = tester.getSize(grid).height;
      final note = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Catatan',
      );
      await tester.enterText(note, 'Beli makan');
      for (final bottom in [300.0, 120.0, 8.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: bottom);
        tester.view.padding = const FakeViewPadding(top: 24);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.element(keypad), same(mountedKeypad));
        expect(tester.getSize(grid).height, categoryHeight);
        expect(find.text('7').hitTestable(), findsNothing);
        expect(find.text('Simpan').hitTestable(), findsNothing);
      }
      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.text('7').hitTestable(), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 8);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('7').hitTestable(), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.resetViewInsets();
      tester.view.padding = tester.view.viewPadding;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.element(keypad), same(mountedKeypad));
      expect(tester.widget<TextField>(note).controller!.text, 'Beli makan');
      await tester.tap(find.text('7').hitTestable());
      await tester.pump();
      expect(find.text('Rp 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture the actual dock emergence motion', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 892);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.padding = tester.view.viewPadding;
    addTearDown(tester.view.reset);
    final settings = await launch(tester, notes: 3, preview: true);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await settings.setThemeMode(mode);
      await select(tester, 'Laporan');
      for (final (tab, name) in [('Uang', 'show'), ('Laporan', 'hide')]) {
        await tester.tap(find.bySemanticsLabel(tab).hitTestable());
        await tester.pump();
        for (var frame = 0; frame < 15; frame++) {
          if (frame > 0) await tester.pump(const Duration(milliseconds: 33));
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('preview-boundary')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final directory = Directory('build/design-captures')
              ..createSync(recursive: true);
            File('${directory.path}/motion-$name-${mode.name}-$frame.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
        await tester.pumpAndSettle();
      }
    }
  }, skip: !makePreviews);

  testWidgets('render the glass dock on production Hari, Uang and Laporan', (
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
      for (final tab in ['Hari', 'Uang', 'Laporan']) {
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

class _MemoryNoteDao implements NoteDao {
  _MemoryNoteDao(this.tasks);

  final MemoryTaskDao tasks;
  final Map<String, DayNote> notes = {};

  @override
  Future<List<DayNote>> all() async => notes.values.toList();

  @override
  Future<void> save(DayNote note, {required bool creating}) async {
    notes[note.id] = note;
  }

  @override
  Future<Task?> schedule(DayNote note, DateTime date, String? time) async {
    if (notes.remove(note.id) == null) return null;
    return tasks.rows[note.id] = Task(
      id: note.id,
      title: note.displayTitle,
      notes: note.body,
      scheduledDate: dateKey(date),
      scheduledTime: time,
      isDone: false,
      createdAt: note.createdAt,
    );
  }

  @override
  Future<void> delete(String id) async {
    notes.remove(id);
  }

  @override
  Future<DayNote?> unschedule(Task draft) async {
    if (tasks.rows.remove(draft.id) == null) return null;
    return notes[draft.id] = DayNote(
      id: draft.id,
      title: draft.title,
      body: draft.notes ?? '',
      createdAt: draft.createdAt,
      updatedAt: draft.createdAt,
    );
  }
}

class _LedgerDatabase implements Database {
  _LedgerDatabase({required this.preview, required int categoryCount})
    : _categories = [
        for (var i = 0; i < categoryCount; i++)
          MoneyCategory(
            id: 'category-$i',
            name: 'Kategori ${i + 1}',
            kind: 'expense',
            sortOrder: i,
            archived: false,
            createdAt: i,
          ).toMap(),
      ];

  final bool preview;
  final List<Map<String, Object?>> _categories;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (!sql.startsWith('SELECT MAX(sort_order)')) {
      throw ArgumentError.value(sql);
    }
    return [
      {'m': _categories.length - 1},
    ];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table != 'categories') throw ArgumentError.value(table);
    _categories.add(values);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table != 'categories') throw ArgumentError.value(table);
    final index = _categories.indexWhere(
      (row) => row['id'] == whereArgs?.single,
    );
    if (index == -1) return 0;
    _categories[index] = {..._categories[index], ...values};
    return 1;
  }

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
      'categories' => _categories,
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
