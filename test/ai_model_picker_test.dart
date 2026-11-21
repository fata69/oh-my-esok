import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/ai/gemini_model_catalog.dart';
import 'package:jadwal/ui/ai_model_picker.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

const _saved = GeminiModel('gemini-2.5-flash', 'Gemini 2.5 Flash');
const _models = [
  _saved,
  GeminiModel('gemini-alpha', 'Gemini Alpha'),
  GeminiModel('gemini-alpha-preview', 'Gemini Alpha'),
  GeminiModel('gemini-focus', 'Gemini Focus IT'),
];

Finder get _save => find.widgetWithText(FilledButton, 'Simpan');

Future<void> _open(
  WidgetTester tester, {
  required Future<List<GeminiModel>> Function()? loadModels,
  required ValueChanged<String> onSave,
  Future<void> Function()? onEditKey,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EsokTheme.light(),
      darkTheme: EsokTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final id = await showAiModelPicker(
                context,
                currentModel: _saved.id,
                loadModels: loadModels,
                onEditKey: onEditKey,
              );
              if (id != null) onSave(id);
            },
            child: const Text('Buka model'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka model'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('missing key opens the existing key entry without a save', (
    tester,
  ) async {
    var chosen = _saved.id;
    var editRequests = 0;
    await _open(
      tester,
      loadModels: null,
      onSave: (id) => chosen = id,
      onEditKey: () async => editRequests++,
    );

    expect(find.textContaining('Isi API key Gemini'), findsOneWidget);
    expect(_save, findsNothing);
    await tester.tap(find.text('Atur API key'));
    await tester.pumpAndSettle();
    expect(editRequests, 1);
    expect(chosen, _saved.id);
  });

  testWidgets('error and retry do not commit a new model after cancel', (
    tester,
  ) async {
    final request = Completer<List<GeminiModel>>();
    var chosen = _saved.id;
    var loads = 0;
    await _open(
      tester,
      loadModels: () => ++loads == 1 ? request.future : Future.value(_models),
      onSave: (id) => chosen = id,
    );
    expect(find.textContaining('Memuat daftar model'), findsOneWidget);
    request.completeError(
      const GeminiModelCatalogException('API key Gemini ditolak.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('API key Gemini ditolak.'), findsOneWidget);
    expect(_save, findsNothing);
    expect(chosen, _saved.id);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.tap(find.text('gemini-alpha-preview'));
    await tester.pumpAndSettle();
    expect(chosen, _saved.id);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(chosen, _saved.id);
  });

  testWidgets('typed names resolve only to a confirmed catalog model', (
    tester,
  ) async {
    String? chosen;
    await _open(
      tester,
      loadModels: () async => _models,
      onSave: (id) => chosen = id,
    );
    final search = find.byType(TextField);
    await tester.enterText(search, 'Gemini Alpha');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Gemini Alpha'), findsNWidgets(2));
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);

    await tester.enterText(search, 'models/gemini-unknown');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada model yang cocok.'), findsOneWidget);
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);

    await tester.enterText(search, 'Gemini-Focus');
    await tester.pumpAndSettle();
    expect(find.text('Gemini Focus IT'), findsOneWidget);
    expect(find.text('Tidak ada model yang cocok.'), findsNothing);
    await tester.tap(find.text('Gemini Focus IT'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini Focus IT'), findsOneWidget);
    expect(chosen, isNull);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(chosen, 'gemini-focus');
  });

  testWidgets('exact ID and save work with large text and a keyboard inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = tester.view.padding;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    String? chosen;
    await _open(
      tester,
      loadModels: () async => _models,
      onSave: (id) => chosen = id,
      themeMode: ThemeMode.dark,
    );

    final search = find.byType(TextField);
    await tester.enterText(search, 'models/GEMINI-ALPHA-PREVIEW');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('gemini-alpha-preview'), findsOneWidget);
    expect(_save.hitTestable(), findsOneWidget);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(chosen, 'gemini-alpha-preview');
  });
}
