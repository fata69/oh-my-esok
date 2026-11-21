import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GeminiModel {
  const GeminiModel(this.id, this.displayName);

  final String id;
  final String displayName;
}

class GeminiModelCatalogException implements Exception {
  const GeminiModelCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Models advertised for generateContent. This does not establish support for
/// image inputs or structured outputs on a particular model.
abstract final class GeminiModelCatalog {
  static const _host = 'generativelanguage.googleapis.com';
  static const _path = '/v1beta/models';
  static const _maxPages = 10;
  static const _timeLimit = Duration(seconds: 20);
  static final _id = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

  /// Accept a bare API ID or its `models/` resource name, never a URL.
  static String? canonicalId(String value) {
    final trimmed = value.trim().toLowerCase();
    final id = trimmed.startsWith('models/') ? trimmed.substring(7) : trimmed;
    return _id.hasMatch(id) ? id : null;
  }

  static Future<List<GeminiModel>> list(
    String apiKey, {
    http.Client? client,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const GeminiModelCatalogException('API key Gemini belum diisi.');
    }

    final transport = client ?? http.Client();
    final elapsed = Stopwatch()..start();
    final models = <String, GeminiModel>{};
    final seenTokens = <String>{};
    String? pageToken;

    try {
      for (var page = 0; page < _maxPages; page++) {
        final remaining = _timeLimit - elapsed.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('');
        final uri = Uri.https(_host, _path, {
          'pageSize': '100',
          'pageToken': ?pageToken,
        });
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['x-goog-api-key'] = key;
        final response = await transport
            .send(request)
            .then(http.Response.fromStream)
            .timeout(remaining);
        if (response.statusCode != 200) {
          throw GeminiModelCatalogException(switch (response.statusCode) {
            400 || 401 || 403 => 'API key Gemini ditolak. Periksa di Setelan.',
            429 => 'Batas permintaan Gemini tercapai. Coba lagi nanti.',
            _ => 'Daftar model Gemini belum bisa dimuat. Coba lagi.',
          });
        }

        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is! Map<String, dynamic>) throw const FormatException();
        final entries = body['models'];
        if (entries != null && entries is! List) throw const FormatException();
        for (final entry in (entries as List? ?? const [])) {
          if (entry is! Map<String, dynamic>) continue;
          final methods = entry['supportedGenerationMethods'];
          if (methods is! List || !methods.contains('generateContent')) {
            continue;
          }
          final name = entry['name'];
          final id = name is String ? canonicalId(name) : null;
          if (id == null) continue;
          final display = entry['displayName'];
          final label = display is String ? display.trim() : '';
          models.putIfAbsent(
            id,
            () => GeminiModel(id, label.isEmpty ? id : label),
          );
        }

        final next = body['nextPageToken'];
        if (next == null || next == '') {
          return List<GeminiModel>.unmodifiable(models.values);
        }
        if (next is! String || next.trim().isEmpty) {
          throw const FormatException();
        }
        if (!seenTokens.add(next)) break;
        pageToken = next;
      }
      throw const GeminiModelCatalogException(
        'Daftar model Gemini tidak lengkap. Coba muat ulang.',
      );
    } on GeminiModelCatalogException {
      rethrow;
    } on TimeoutException {
      throw const GeminiModelCatalogException(
        'Memuat daftar model melewati batas waktu. Coba lagi.',
      );
    } on FormatException {
      throw const GeminiModelCatalogException(
        'Daftar model Gemini tidak terbaca.',
      );
    } on SocketException {
      throw const GeminiModelCatalogException('Tidak ada koneksi internet.');
    } catch (_) {
      // Neither upstream response bodies nor exception details are safe to show.
      throw const GeminiModelCatalogException(
        'Gagal menghubungi server Gemini.',
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  static GeminiModel? resolve(String query, List<GeminiModel> models) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final id = canonicalId(trimmed);
    if (id != null) {
      for (final model in models) {
        if (canonicalId(model.id) == id) return model;
      }
    }
    // An explicit resource name must match an ID, never a display label.
    if (RegExp(r'[/\\?#%]').hasMatch(trimmed)) return null;
    final label = _normalizeDisplayName(trimmed);
    if (label.isEmpty) return null;
    GeminiModel? match;
    for (final model in models) {
      if (_normalizeDisplayName(model.displayName) != label) continue;
      if (match != null) return null;
      match = model;
    }
    return match;
  }

  static String _normalizeDisplayName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), ' ')
      .trim()
      // API display names may include an instruction-tuned (IT) suffix.
      .replaceFirst(RegExp(r' (?:it|\(it\))$'), '');
}
