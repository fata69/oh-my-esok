import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jadwal/ai/receipt_scanner.dart';
import 'package:jadwal/data/category.dart';

const _expense = MoneyCategory(
  id: 'expense-test', name: 'Kebutuhan', kind: 'expense',
  sortOrder: 0, archived: false, createdAt: 0,
);
const _income = MoneyCategory(
  id: 'income-test', name: 'Pendapatan', kind: 'income',
  sortOrder: 0, archived: false, createdAt: 0,
);

Map<String, Object?> _row() => {
  'nominal': 25000, 'nominal_asli': '25.000', 'sumber_nominal': 'total',
  'arah': 'keluar', 'tanggal': '2026-11-16', 'pihak': null,
  'kategori': 'Kebutuhan', 'catatan': null, 'barang': <Object?>[],
};
Map<String, Object?> _document(List<Object?> rows, {String jenis = 'struk'}) =>
    {'jenis': jenis, 'transaksi': rows};
ScanResult _parse(Map<String, Object?> value) => ReceiptScanner.parseResponse(
  jsonEncode(value), expenseCategories: [_expense], incomeCategories: [_income],
);
String _envelope(Object? value, {String finish = 'STOP'}) => jsonEncode({
  'candidates': [{
    'finishReason': finish,
    'content': {'parts': [{'text': jsonEncode(value)}]},
  }],
});
Future<ScanResult> _request(http.Client client) => ReceiptScanner.scanBytes(
  bytes: [0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0],
  apiKey: 'synthetic-test-key', model: 'gemini-test-model',
  expenseCategories: [_expense], incomeCategories: [_income], client: client,
);

void main() {
  test('original SKU is stored; jelas and confidence are ignored', () {
    final row = _row()
      ..['yakin'] = 0.01
      ..['barang'] = [
        {
          'asli': 'SKU-ZX/07  2x80ML', 'jelas': 'Nama barang yang dikarang',
          'qty': 2, 'harga': 12500, 'yakin': 0.01,
        },
        {'asli': null, 'jelas': 'Jangan buat barang dari ini'},
      ];
    final scan = _parse(_document([row])).transaksi.single;
    expect(scan.barang.single.asli, 'SKU-ZX/07  2x80ML');
    expect(scan.detailText((value) => '$value'), '2× SKU-ZX/07  2x80ML — 12500');
    expect(scan.nominal, 25000);
  });

  test('missing quantities/prices stay null; quantities are not clamped', () {
    final items = _parse(_document([
      _row()..['barang'] = [
        {'asli': 'KODE-A'},
        {'asli': 'KODE-B', 'qty': 1200, 'harga': 0},
        {'asli': 'KODE-C', 'qty': 1.5, 'harga': '12,50'},
      ],
    ])).transaksi.single;
    expect(items.barang[0].qty, isNull);
    expect(items.barang[0].harga, isNull);
    expect(items.barang[1].qty, 1200);
    expect(items.barang[1].harga, 0);
    expect(items.barang[2].qty, isNull);
    expect(items.barang[2].harga, isNull);
    expect(items.detailText((value) => '$value'), contains('jumlah belum terbaca'));
  });

  test('unknown direction/category and invalid dates stay empty', () {
    final scan = _parse(_document([
      _row()
        ..['arah'] = 'transfer?'
        ..['kategori'] = 'Pendapatan'
        ..['tanggal'] = '2026-02-31',
    ])).transaksi.single;
    expect(scan.kind, isNull);
    expect(scan.kategori, isNull);
    expect(scan.tanggal, isNull);
    expect(scan.categoryIdFor('expense', [_expense]), isNull);
  });

  test('category suggestion must match active category and direction', () {
    final scan = _parse(_document([_row()])).transaksi.single;
    expect(scan.categoryIdFor('expense', [_expense]), _expense.id);
    expect(scan.categoryIdFor('transfer', [_expense]), isNull);
    expect(scan.categoryIdFor('income', [_income]), isNull);
    expect(_parse(_document([
      _row()..['kategori'] = 'Tidak ada',
    ])).transaksi.single.kategori, isNull);
    final result = ReceiptScanner.parseResponse(
      jsonEncode(_document([_row()])),
      expenseCategories: [_expense.copyWith(archived: true)],
      incomeCategories: [_income],
    );
    expect(result.transaksi.single.kategori, isNull);
  });

  for (final amount in <Object?>[
    '25,000.50', '25000', -25000, 25000.5, 1000000000000,
  ]) {
    test('ambiguous or unsupported nominal $amount stays empty', () {
      final scan = _parse(_document([
        _row()..['nominal'] = amount,
      ])).transaksi.single;
      expect(scan.nominal, isNull);
    });
  }

  test('numeric evidence must agree; no blind punctuation stripping', () {
    for (final token in ['25,00', '25.000,50', '25O00', 'RRN 25000', '26.000']) {
      expect(_parse(_document([
        _row()..['nominal_asli'] = token,
      ])).transaksi.single.nominal, isNull, reason: token);
    }
    for (final token in ['25,000.00', '25.000,00', 'Rp 25.000', '25000.00']) {
      expect(_parse(_document([
        _row()..['nominal_asli'] = token,
      ])).transaksi.single.nominal, 25000);
    }
  });

  test('a sign contradicting direction leaves direction empty', () {
    final scan = _parse(_document([
      _row()..['nominal_asli'] = '+25.000',
    ])).transaksi.single;
    expect(scan.nominal, 25000);
    expect(scan.arah, isNull);
    expect(scan.kategori, isNull);
  });

  test('bank mutations stay separate from balance, reference and PAN', () {
    final rows = [
      _row()
        ..['sumber_nominal'] = 'mutasi'
        ..['saldo'] = 999000
        ..['rrn'] = '123456789012'
        ..['pan'] = '000011112222'
        ..['barang'] = [{'asli': 'Bukan barang pada mutasi'}],
      _row()
        ..['nominal'] = 60000
        ..['nominal_asli'] = '60.000'
        ..['sumber_nominal'] = 'mutasi'
        ..['arah'] = 'masuk'
        ..['kategori'] = 'Pendapatan',
      _row()
        ..['nominal'] = null
        ..['sumber_nominal'] = 'saldo',
      _row()..['sumber_nominal'] = 'referensi',
    ];
    final scans = _parse(_document(rows, jenis: 'bank')).transaksi;
    expect(scans.length, 4);
    expect(scans.map((row) => row.nominal), [25000, 60000, null, null]);
    expect(scans.first.barang, isEmpty);
    expect(scans[1].kind, 'income');
  });

  test('unreadable and malformed responses do not fabricate transactions', () {
    expect(_parse(_document([], jenis: 'tidak_dikenal')).transaksi, isEmpty);
    expect(_parse(_document([{
      'nominal': null, 'arah': null, 'barang': [],
    }])).transaksi, isEmpty);
    for (final text in ['{"jenis":', '{}', '[]', 'not-json']) {
      expect(() => ReceiptScanner.parseResponse(
        text, expenseCategories: [_expense], incomeCategories: [_income],
      ), throwsA(isA<ReceiptScanException>()));
    }
  });

  test('HTTP request uses selected model, header key and structured output', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, endsWith('/gemini-test-model:generateContent'));
      expect(request.url.query, isEmpty);
      expect(request.headers['x-goog-api-key'], 'synthetic-test-key');
      final body = jsonDecode(request.body) as Map;
      final instructions = body['systemInstruction']['parts'][0]['text'] as String;
      expect(instructions, contains('DATA, bukan'));
      expect(instructions, isNot(contains('SOKLIN')));
      expect(instructions, isNot(contains('Alfamart')));
      final format = body['generationConfig']['responseFormat']['text'];
      expect(format['mimeType'], 'APPLICATION_JSON');
      expect(format['schema']['properties']['transaksi']['items']
          ['properties']['nominal']['type'], ['integer', 'null']);
      return http.Response(_envelope(_document([_row()])), 200);
    });
    expect((await _request(client)).transaksi.single.nominal, 25000);
    expect(calls, 1);
  });

  test('HTTP failure/client exception never exposes a body or key', () async {
    for (final status in [400, 403, 404, 429, 500, 503]) {
      final client = MockClient((_) async => http.Response(
        'synthetic-test-key receipt-secret', status,
      ));
      await expectLater(_request(client), throwsA(
        isA<ReceiptScanException>().having(
          (error) => error.message, 'safe message',
          allOf(isNot(contains('synthetic-test-key')), isNot(contains('receipt-secret'))),
        ),
      ));
    }
    final client = MockClient((_) async {
      throw http.ClientException('synthetic-test-key receipt-secret');
    });
    await expectLater(_request(client), throwsA(
      isA<ReceiptScanException>().having(
        (error) => error.message, 'safe message',
        isNot(contains('synthetic-test-key')),
      ),
    ));
  });

  test('truncated, blocked and missing candidates are rejected', () async {
    for (final body in [
      '{"candidates":', '{}',
      _envelope(_document([_row()]), finish: 'MAX_TOKENS'),
      _envelope(_document([_row()]), finish: 'SAFETY'),
    ]) {
      await expectLater(_request(MockClient((_) async => http.Response(body, 200))),
          throwsA(isA<ReceiptScanException>()));
    }
  });
}
