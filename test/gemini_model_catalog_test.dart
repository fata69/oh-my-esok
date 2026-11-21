import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jadwal/ai/gemini_model_catalog.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'synthetic-key';

Map<String, Object> _model(
  String name,
  String displayName, {
  List<String> methods = const ['generateContent'],
}) => {
  'name': name,
  'displayName': displayName,
  'supportedGenerationMethods': methods,
};

http.Response _page(List<Object> models, {String? next}) => http.Response(
  jsonEncode({'models': models, 'nextPageToken': ?next}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads all pages with header auth and filters by API method', () async {
    var requests = 0;
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'generativelanguage.googleapis.com');
      expect(request.url.path, '/v1beta/models');
      expect(request.followRedirects, isFalse);
      expect(request.headers['x-goog-api-key'], _key);
      expect(request.url.toString(), isNot(contains(_key)));
      expect(request.body, isEmpty);
      expect(request.url.queryParameters['pageSize'], '100');
      switch (++requests) {
        case 1:
          expect(request.url.queryParameters['pageToken'], isNull);
          return _page([
            _model('models/gemini-demo', 'Gemini Demo'),
            _model(
              'models/embedding-only',
              'Embedding',
              methods: ['embedContent'],
            ),
            _model('https://example.com/models/not-an-id', 'Invalid path'),
          ], next: 'opaque/+?=');
        case 2:
          expect(request.url.queryParameters['pageToken'], 'opaque/+?=');
          return _page([
            _model('models/gemini-demo', 'Duplicate'),
            _model('models/gemma-4-31b-it', 'Gemma 4 31B IT'),
            _model('models/other-provider-new', 'Model échantillon'),
          ]);
        default:
          fail('Unexpected page request');
      }
    });
    addTearDown(client.close);

    final models = await GeminiModelCatalog.list(' $_key ', client: client);
    expect(requests, 2);
    expect(models.map((model) => model.id), [
      'gemini-demo',
      'gemma-4-31b-it',
      'other-provider-new',
    ]);
    expect(models.last.displayName, 'Model échantillon');
    expect(GeminiModelCatalog.resolve('Gemma 4 31B', models), same(models[1]));
  });

  test('resolves canonical IDs and unique normalized display names', () {
    const model = GeminiModel('gemma-4-31b-it', 'Gemma 4 31B (IT)');
    const twin = GeminiModel('future-model', 'Gemma-4-31B');
    expect(
      GeminiModelCatalog.resolve('  models/GEMMA-4-31B-IT  ', [model, twin]),
      same(model),
    );
    expect(GeminiModelCatalog.resolve(' gemma_4   31B ', [model]), same(model));
    expect(GeminiModelCatalog.resolve('Gemma 4 31B', [model, twin]), isNull);
    expect(GeminiModelCatalog.resolve('Gemma 4', [model]), isNull);
    for (final bad in [
      'https://example.com/models/gemma-4-31b-it',
      'models/../gemma-4-31b-it',
      'models/gemma-4-31b-it?key=x',
      'models/models/gemma-4-31b-it',
      'models/Gemma 4 31B',
    ]) {
      expect(GeminiModelCatalog.resolve(bad, [model]), isNull, reason: bad);
    }
  });

  test('bounds page count and stops repeated page tokens', () async {
    for (final cyclic in [true, false]) {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _page([], next: cyclic ? 'same' : 'page-$calls');
      });
      addTearDown(client.close);
      await expectLater(
        GeminiModelCatalog.list(_key, client: client),
        throwsA(isA<GeminiModelCatalogException>()),
      );
      expect(calls, cyclic ? 2 : 10);
    }
  });

  test(
    'empty list is valid; malformed success and failures are sanitized',
    () async {
      final client = MockClient(
        (_) async => _page([
          _model('models/embedding-only', 'Embed', methods: ['embedContent']),
        ]),
      );
      addTearDown(client.close);
      expect(await GeminiModelCatalog.list(_key, client: client), isEmpty);

      for (final (status, body) in [
        (302, _key),
        (400, _key),
        (403, _key),
        (429, _key),
        (500, _key),
        (200, '{"models":"$_key"}'),
      ]) {
        var calls = 0;
        final failing = MockClient((_) async {
          calls++;
          return http.Response(body, status);
        });
        addTearDown(failing.close);
        await expectLater(
          GeminiModelCatalog.list(_key, client: failing),
          throwsA(
            isA<GeminiModelCatalogException>().having(
              (failure) => failure.message,
              'sanitized message',
              isNot(contains(_key)),
            ),
          ),
        );
        expect(calls, 1);
      }

      final throwing = MockClient(
        (_) async => throw http.ClientException(_key),
      );
      addTearDown(throwing.close);
      await expectLater(
        GeminiModelCatalog.list(_key, client: throwing),
        throwsA(
          isA<GeminiModelCatalogException>().having(
            (failure) => failure.toString(),
            'sanitized message',
            isNot(contains(_key)),
          ),
        ),
      );
    },
  );

  test('missing API key does not start an HTTP request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _page([]);
    });
    addTearDown(client.close);
    await expectLater(
      GeminiModelCatalog.list(' ', client: client),
      throwsA(isA<GeminiModelCatalogException>()),
    );
    expect(calls, 0);
  });

  test(
    'preserves a saved Gemini 2.5 Flash and persists canonical IDs',
    () async {
      SharedPreferences.setMockInitialValues({'ai_model': 'gemini-2.5-flash'});
      final settings = SettingsStore();
      addTearDown(settings.dispose);
      await settings.init();
      expect(settings.aiModel, 'gemini-2.5-flash');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_model'), 'gemini-2.5-flash');

      await settings.setAiModel('  models/GEMMA-4-31B-IT  ');
      expect(settings.aiModel, 'gemma-4-31b-it');
      expect(prefs.getString('ai_model'), 'gemma-4-31b-it');
      await expectLater(
        settings.setAiModel('https://example.com/models/wrong'),
        throwsA(isA<GeminiModelCatalogException>()),
      );
      final reloaded = SettingsStore();
      addTearDown(reloaded.dispose);
      await reloaded.init();
      expect(reloaded.aiModel, 'gemma-4-31b-it');

      await settings.setAiModel(' ');
      expect(settings.aiModel, SettingsStore.defaultAiModel);
      expect(prefs.getString('ai_model'), SettingsStore.defaultAiModel);
    },
  );

  test('uses the fallback for absent or invalid saved IDs', () async {
    for (final stored in [null, '', 'models/../invalid']) {
      SharedPreferences.setMockInitialValues({'ai_model': ?stored});
      final settings = SettingsStore();
      addTearDown(settings.dispose);
      await settings.init();
      expect(settings.aiModel, SettingsStore.defaultAiModel);
    }
  });
}
