import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:jadwal/ui/settings_page.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<SettingsStore> launch(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Oh My Esok',
      packageName: 'com.ohmyesok.app',
      version: '0.1.0',
      buildNumber: '25',
      buildSignature: '',
    );
    final settings = SettingsStore();
    addTearDown(settings.dispose);
    await settings.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsStore>.value(
        value: settings,
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? EsokTheme.dark()
              : EsokTheme.light(),
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('sound switch exposes its state, full row and keyboard action', (
    tester,
  ) async {
    final settings = await launch(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpAndSettle();
    final soundLabel = find.text('Efek suara');
    await tester.scrollUntilVisible(soundLabel, 210);
    final sound = find.ancestor(
      of: soundLabel,
      matching: find.byType(SwitchListTile),
    );
    final semantics = find.bySemanticsLabel(RegExp(r'^Efek suara'));
    final row = tester.getRect(sound);
    expect(row.height, greaterThanOrEqualTo(48));
    expect(row.width, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(semantics)
          .getSemanticsData()
          .flagsCollection
          .isToggled,
      ui.Tristate.isTrue,
    );

    await tester.tap(soundLabel.hitTestable());
    await tester.pumpAndSettle();
    expect(settings.soundEnabled, isFalse);
    expect(
      tester
          .getSemantics(semantics)
          .getSemanticsData()
          .flagsCollection
          .isToggled,
      ui.Tristate.isFalse,
    );

    final focus = find
        .descendant(
          of: sound,
          matching: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.canRequestFocus,
          ),
        )
        .first;
    (tester.widget<Focus>(focus).focusNode ??
            Focus.of(
              tester.element(
                find.descendant(of: focus, matching: find.text('Efek suara')),
              ),
            ))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(settings.soundEnabled, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('sound_enabled'),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets(
    'reminder has a separate choice and scrolls at 200% on a short screen',
    (tester) async {
      await launch(
        tester,
        brightness: Brightness.dark,
        size: const Size(760, 360),
        scale: 2,
      );
      final target = find.text('Jarak pengingat');
      await tester.scrollUntilVisible(target, 190);
      final row = find.ancestor(of: target, matching: find.byType(ListTile));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.getSize(row).width, lessThanOrEqualTo(600));
      await tester.tap(target.hitTestable());
      await tester.pumpAndSettle();
      final last = find.text('1 hari sebelum tenggat');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      expect(find.byType(RadioListTile<int>), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      final close = find.byTooltip('Tutup');
      await tester.ensureVisible(close);
      await tester.tap(close.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('1 jam sebelum tenggat'), findsOneWidget);

      await tester.tap(target.hitTestable());
      await tester.pumpAndSettle();
      await tester.ensureVisible(last);
      await tester.tap(last.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('1 hari sebelum tenggat'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt('lead_minutes'),
        1440,
      );
    },
  );

  testWidgets('saving Gemini key works with a keyboard on a narrow phone', (
    tester,
  ) async {
    final settings = await launch(
      tester,
      size: const Size(360, 740),
      scale: 1.5,
    );
    final row = find.text('API key Gemini');
    await tester.scrollUntilVisible(row, 360);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row.hitTestable());
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    final keyField = find.byType(TextField);
    expect(tester.widget<TextField>(keyField).obscureText, isTrue);
    await tester.enterText(keyField, 'synthetic-test-key');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan').hitTestable());
    await tester.pumpAndSettle();
    expect(settings.aiKey, 'synthetic-test-key');
    expect(tester.takeException(), isNull);
  });
}
