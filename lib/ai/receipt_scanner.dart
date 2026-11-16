import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/category.dart';

class ScanItem {
  const ScanItem({
    required this.asli,
    required this.qty,
    required this.harga,
    required this.yakin,
    this.jelas,
  });

  final String asli;
  final String? jelas;
  final int qty;
  final int harga;
  final double yakin;
}

class ScanTransaction {
  const ScanTransaction({
    required this.nominal,
    required this.arah,
    required this.yakin,
    required this.barang,
    this.tanggal,
    this.pihak,
    this.kategori,
    this.sumberDana,
    this.catatan,
  });

  final int nominal;
  final String arah;
  final DateTime? tanggal;
  final String? pihak;
  final String? kategori;
  final String? sumberDana;
  final String? catatan;
  final double yakin;
  final List<ScanItem> barang;
}

class ScanResult {
  const ScanResult({required this.jenis, required this.transaksi});

  final String jenis;
  final List<ScanTransaction> transaksi;
}

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptScanner {
  ReceiptScanner._();

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<ScanResult> scan({
    required File image,
    required String apiKey,
    required String model,
    required List<MoneyCategory> expenseCategories,
    required List<MoneyCategory> incomeCategories,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const ReceiptScanException(
        'API key belum diisi. Buka Setelan → Pindai struk.',
      );
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _mimeOf(bytes);
    final expenseNames = expenseCategories
        .map((category) => category.name)
        .join(', ');
    final incomeNames = incomeCategories
        .map((category) => category.name)
        .join(', ');

    final prompt =
        '''
Kamu membaca foto struk belanja atau screenshot mutasi bank Indonesia.
Balas HANYA JSON valid, tanpa penjelasan, dengan bentuk:
{"jenis":"struk | bank | tidak_dikenal","transaksi":[{"nominal":39600,"arah":"keluar | masuk","tanggal":"2026-10-16","pihak":"Alfamart A. Yani","kategori":"Belanja","sumber_dana":"Rekening sendiri","catatan":"QRIS","yakin":0.92,"barang":[{"asli":"SOKLIN HJB780ML","jelas":"Soklin deterjen 780 ml","qty":1,"harga":13000,"yakin":0.9}]}]}

Aturan:
- nominal = field total yang benar. Di struk: "Total Belanja" / "Total Bayar" / "Sub Total". Di mutasi: nominal baris, BUKAN saldo.
- Format IDR 25,000.00 menjadi 25000. Buang titik/koma pemisah ribuan.
- JANGAN memakai RRN, Merchant PAN, Customer PAN, No. Referensi, atau nomor kartu sebagai nominal.
- Diskon tidak dihitung ulang. Pakai total cetak apa adanya walau aritmetika struk tidak konsisten.
- tanggal: DD-MM-YYYY atau 09 Nov 2026 menjadi YYYY-MM-DD. Gagal -> null.
- arah: struk selalu keluar. Mutasi dibaca dari KREDIT/DEBIT/MASUK/KELUAR atau tanda +/−.
- kategori: untuk arah masuk pilih dari daftar pemasukan [$incomeNames]; untuk arah keluar pilih dari daftar pengeluaran [$expenseNames]. Jangan mencampur daftar. Tidak ada yang cocok -> "Lain-lain" dari daftar yang sama.
- sumber_dana: untuk jenis bank wajib literal "Rekening sendiri"; untuk struk null. Jangan membaca nama/nomor rekening.
- barang: hanya untuk jenis struk. jelas diisi HANYA bila merek/ukuran terbaca jelas; kalau ragu isi null, jangan mengarang.
- catatan: jenis transaksi singkat (QRIS, transfer, tarik tunai). JANGAN menulis nominal di sini.
- yakin: angka 0 sampai 1. Transaksi di bawah 0.4 akan dibuang.
- Bila tidak terbaca: {"jenis":"tidak_dikenal","transaksi":[]}.
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
      },
    });

    final uri = Uri.parse('$_endpoint/$model:generateContent?key=$apiKey');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const ReceiptScanException('Tidak ada koneksi internet.');
    } catch (error) {
      debugPrint('Receipt scan request gagal: $error');
      throw const ReceiptScanException('Gagal menghubungi server AI.');
    }

    if (response.statusCode == 400 || response.statusCode == 403) {
      throw const ReceiptScanException('API key ditolak. Periksa di Setelan.');
    }
    if (response.statusCode == 404) {
      throw const ReceiptScanException(
        'Model tidak tersedia. Ganti di Setelan → Pindai struk.',
      );
    }
    if (response.statusCode == 429) {
      throw const ReceiptScanException('Kuota AI habis. Coba lagi nanti.');
    }
    if (response.statusCode == 503) {
      throw const ReceiptScanException(
        'Model sedang sibuk. Coba lagi sebentar.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint(
        'Receipt scan gagal ${response.statusCode}: '
        '${response.body.length > 400 ? response.body.substring(0, 400) : response.body}',
      );
      throw ReceiptScanException('Server AI menolak (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    final finishReason = _finishReason(decoded);
    if (finishReason == 'MAX_TOKENS') {
      throw const ReceiptScanException(
        'Balasan AI terpotong. Coba lagi.',
      );
    }

    final text = _extractText(decoded);
    if (text == null) {
      debugPrint(
        'Receipt scan tanpa teks: '
        '${response.body.length > 400 ? response.body.substring(0, 400) : response.body}',
      );
      throw const ReceiptScanException('Balasan AI tidak terbaca.');
    }

    final parsed = _parseJson(text);
    final jenis = (parsed['jenis'] as String?)?.trim() ?? 'tidak_dikenal';
    final rawTransactions = parsed['transaksi'];
    if (rawTransactions is! List) {
      return ScanResult(jenis: jenis, transaksi: const []);
    }

    final transactions = <ScanTransaction>[];
    for (final raw in rawTransactions) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final nominal = _toInt(map['nominal']);
      final confidence = _toDouble(map['yakin']);
      if (nominal <= 0 || confidence < 0.4) continue;

      final items = <ScanItem>[];
      final rawItems = map['barang'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          final item = rawItem.cast<String, dynamic>();
          final original = (item['asli'] as String?)?.trim() ?? '';
          if (original.isEmpty) continue;
          final clear = (item['jelas'] as String?)?.trim();
          items.add(
            ScanItem(
              asli: original,
              jelas: clear == null || clear.isEmpty ? null : clear,
              qty: _toInt(item['qty'], fallback: 1).clamp(1, 999),
              harga: _toInt(item['harga']),
              yakin: _toDouble(item['yakin']),
            ),
          );
        }
      }

      transactions.add(
        ScanTransaction(
          nominal: nominal,
          arah: map['arah'] == 'masuk' ? 'masuk' : 'keluar',
          tanggal: _parseDate(map['tanggal']),
          pihak: _clean(map['pihak']),
          kategori: _clean(map['kategori']),
          sumberDana: _clean(map['sumber_dana']),
          catatan: _clean(map['catatan']),
          yakin: confidence,
          barang: items,
        ),
      );
    }

    return ScanResult(jenis: jenis, transaksi: transactions);
  }

  static String? _finishReason(Object? decoded) {
    if (decoded is! Map) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    return first['finishReason'] as String?;
  }

  static String _mimeOf(List<int> bytes) {
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String? _extractText(Object? decoded) {
    if (decoded is! Map) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _parseJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      throw const ReceiptScanException('AI tidak mengembalikan data struk.');
    }
    throw const ReceiptScanException('AI tidak mengembalikan data struk.');
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return _safeDate(iso.year, iso.month, iso.day);

    final numeric = RegExp(
      r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$',
    ).firstMatch(text);
    if (numeric != null) {
      return _safeDate(
        int.parse(numeric.group(3)!),
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }

    final named = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$',
    ).firstMatch(text);
    if (named != null) {
      final month = _monthNumber(named.group(2)!);
      if (month != null) {
        return _safeDate(
          int.parse(named.group(3)!),
          month,
          int.parse(named.group(1)!),
        );
      }
    }
    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    if (value.month != month || value.day != day) return null;
    return value;
  }

  static int? _monthNumber(String value) {
    const months = {
      'jan': 1,
      'januari': 1,
      'january': 1,
      'feb': 2,
      'februari': 2,
      'february': 2,
      'mar': 3,
      'maret': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'juni': 6,
      'june': 6,
      'jul': 7,
      'juli': 7,
      'july': 7,
      'agu': 8,
      'agustus': 8,
      'august': 8,
      'aug': 8,
      'sep': 9,
      'september': 9,
      'okt': 10,
      'oktober': 10,
      'october': 10,
      'oct': 10,
      'nov': 11,
      'november': 11,
      'des': 12,
      'desember': 12,
      'december': 12,
      'dec': 12,
    };
    return months[value.toLowerCase()];
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _toInt(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? fallback;
    }
    return fallback;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
