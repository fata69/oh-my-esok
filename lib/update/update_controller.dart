import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'release_manifest.dart';

enum UpdatePhase { idle, checking, available, upToDate, noRelease,
  downloading, verifying, ready, permissionRequired, awaitingAndroid, failed }

class UpdateController extends ChangeNotifier {
  UpdateController() : _clientFactory = (() => HttpClient());
  @visibleForTesting
  UpdateController.withClient(this._clientFactory);
  final HttpClient Function() _clientFactory;
  static const _bridge = MethodChannel('ohmyesok/update');
  UpdatePhase phase = UpdatePhase.idle;
  String installedVersion = '…';
  int installedCode = 0;
  String? message;
  String notes = '';
  ReleaseManifest? release;
  double progress = 0;
  bool allowPreview = false;
  HttpClient? _client;
  File? _apk;
  bool _cancelled = false;
  bool _disposed = false;
  bool get busy => {UpdatePhase.checking, UpdatePhase.downloading,
    UpdatePhase.verifying, UpdatePhase.awaitingAndroid}.contains(phase);

  void _publish(UpdatePhase next, [String? detail]) {
    if (_disposed) return;
    phase = next;
    message = detail;
    notifyListeners();
  }

  Future<void> loadInstalled() async {
    final info = await PackageInfo.fromPlatform();
    installedVersion = '${info.version} (${info.buildNumber})';
    installedCode = int.tryParse(info.buildNumber) ?? 0;
    if (!_disposed) notifyListeners();
  }

  Future<void> check() async {
    if (busy) return;
    release = null;
    notes = '';
    _publish(UpdatePhase.checking);
    try {
      await loadInstalled();
      if (_disposed) return;
      _client = _clientFactory()..connectionTimeout = const Duration(seconds: 15);
      final endpoint = Uri.https('api.github.com',
        '/repos/fata69/oh-my-esok/releases${allowPreview ? '' : '/latest'}',
        allowPreview ? {'per_page': '20'} : null);
      final response = await _request(endpoint, api: true);
      if (response.statusCode == 404) {
        await response.drain<void>().timeout(const Duration(seconds: 20));
        _publish(UpdatePhase.noRelease);
        return;
      }
      _requireOk(response);
      final decoded = jsonDecode(utf8.decode(await _bytes(response, 1024 * 1024)));
      final candidates = allowPreview ? decoded : [decoded];
      if (candidates is! List) throw const FormatException('Daftar rilis tidak valid.');
      ReleaseManifest? best;
      String bestNotes = '';
      for (final candidate in candidates) {
        if (candidate is! Map<String, dynamic> || candidate['draft'] != false ||
            candidate['prerelease'] is! bool || candidate['tag_name'] is! String) continue;
        final prerelease = candidate['prerelease'] as bool;
        if (prerelease && !allowPreview) continue;
        final tag = candidate['tag_name'] as String;
        final assets = candidate['assets'];
        if (assets is! List) continue;
        Map<String, dynamic>? metadata;
        Map<String, dynamic>? binary;
        for (final asset in assets.whereType<Map<String, dynamic>>()) {
          if (asset['name'] == 'ota-android.json') metadata = asset;
          if (asset['name'] == ReleaseManifest.apkName) binary = asset;
        }
        if (metadata == null || binary == null) continue;
        final metadataUri = ReleaseManifest.assetUri(tag, 'ota-android.json');
        final binaryUri = ReleaseManifest.assetUri(tag, ReleaseManifest.apkName);
        if (metadata['browser_download_url'] != metadataUri.toString() ||
            binary['browser_download_url'] != binaryUri.toString() ||
            !ReleaseManifest.trustedAssetUri(metadataUri)) {
          throw const FormatException('Alamat aset rilis tidak sesuai.');
        }
        final dataResponse = await _request(metadataUri);
        _requireOk(dataResponse);
        final manifest = ReleaseManifest.parse(jsonDecode(utf8.decode(
          await _bytes(dataResponse, 64 * 1024))), releaseTag: tag,
          prerelease: prerelease, allowPreview: allowPreview);
        if (binary['size'] != manifest.sizeBytes ||
            (binary['digest'] != null && binary['digest'] != 'sha256:${manifest.sha256}')) {
          throw const FormatException('Ukuran atau checksum rilis tidak sesuai.');
        }
        if (best == null || manifest.versionCode > best.versionCode) {
          best = manifest;
          final body = candidate['body'];
          bestNotes = body is String ? body : '';
        }
        if (!allowPreview) break;
      }
      if (best == null) {
        _publish(UpdatePhase.noRelease);
      } else if (!best.newerThan(installedCode)) {
        _publish(UpdatePhase.upToDate);
      } else {
        release = best;
        notes = bestNotes;
        _publish(UpdatePhase.available);
      }
    } catch (error) {
      _publish(UpdatePhase.failed, _error(error));
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  Future<void> download() async {
    final target = release;
    if (target == null || busy) return;
    _cancelled = false;
    progress = 0;
    _publish(UpdatePhase.downloading);
    File? partial;
    try {
      final directory = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (_disposed) return;
      await directory.create(recursive: true);
      partial = File('${directory.path}/update.part');
      _apk = File('${directory.path}/update.apk');
      if (await _apk!.exists()) await _apk!.delete();
      _client = _clientFactory()..connectionTimeout = const Duration(seconds: 15);
      final response = await _request(ReleaseManifest.assetUri(target.tag, ReleaseManifest.apkName));
      _requireOk(response);
      if (response.contentLength != -1 && response.contentLength != target.sizeBytes) {
        throw const FormatException('Ukuran unduhan tidak sesuai rilis.');
      }
      final output = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          if (_cancelled || _disposed) throw const _Cancelled();
          received += chunk.length;
          if (received > target.sizeBytes) throw const FormatException('Unduhan terlalu besar.');
          output.add(chunk);
          progress = received / target.sizeBytes;
          if (!_disposed) notifyListeners();
        }
      } finally {
        await output.close();
      }
      if (_cancelled) throw const _Cancelled();
      _publish(UpdatePhase.verifying);
      await verifyDownloadedApk(partial, target);
      _apk = await partial.rename(_apk!.path);
      await _bridge.invokeMethod<void>('checkApk', _arguments(target));
      _publish(UpdatePhase.ready);
    } catch (error) {
      if (partial != null && await partial.exists()) await partial.delete();
      if (_apk != null && await _apk!.exists()) await _apk!.delete();
      _publish(error is _Cancelled || _cancelled ? UpdatePhase.available : UpdatePhase.failed,
        _cancelled ? 'Unduhan dibatalkan.' : _error(error));
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  Map<String, Object> _arguments(ReleaseManifest target) => {
    'path': _apk!.path, 'versionCode': target.versionCode, 'sha256': target.sha256,
    'sizeBytes': target.sizeBytes,
  };

  void cancelDownload() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> install() async {
    if (release == null || _apk == null || busy) return;
    try {
      final permitted = await _bridge.invokeMethod<bool>('canInstall') ?? false;
      if (!permitted) {
        _publish(UpdatePhase.permissionRequired);
        return;
      }
      _publish(UpdatePhase.awaitingAndroid);
      await _bridge.invokeMethod<void>('install', _arguments(release!));
    } catch (error) {
      _publish(UpdatePhase.failed, _error(error));
    }
  }

  Future<void> openSources() async {
    try { await _bridge.invokeMethod<void>('openSources'); }
    catch (error) { _publish(UpdatePhase.failed, _error(error)); }
  }

  Future<void> onResume() async {
    if (phase == UpdatePhase.permissionRequired || phase == UpdatePhase.awaitingAndroid) {
      try {
        await loadInstalled();
        if (_disposed) return;
        if (release != null && installedCode >= release!.versionCode) {
          _publish(UpdatePhase.upToDate, 'Pembaruan berhasil dipasang.');
        } else {
          final status = await _bridge.invokeMethod<String>('installStatus');
          _publish(UpdatePhase.ready, status == 'failed'
            ? 'Pemasangan dibatalkan atau ditolak Android. Kamu bisa mencoba lagi.'
            : status == 'awaiting_user' ? 'Ketuk Pasang untuk melanjutkan konfirmasi Android.' : null);
        }
      } catch (error) {
        _publish(UpdatePhase.failed, _error(error));
      }
    }
  }

  Future<HttpClientResponse> _request(Uri initial, {bool api = false}) async {
    var uri = initial;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final allowed = api ? uri == initial && uri.host == 'api.github.com'
        : ReleaseManifest.trustedRedirectUri(uri);
      if (!allowed) throw const FormatException('Tujuan unduhan tidak diizinkan.');
      final request = await _client!.getUrl(uri).timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'OhMyEsok-Android');
      if (api) request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>().timeout(const Duration(seconds: 20));
        if (location == null) throw const FormatException('Alamat unduhan kosong.');
        uri = uri.resolve(location);
        continue;
      }
      return response;
    }
    throw const FormatException('Terlalu banyak pengalihan unduhan.');
  }

  void _requireOk(HttpClientResponse response) {
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const FormatException('Batas permintaan GitHub tercapai. Coba lagi nanti.');
    }
    if (response.statusCode != 200) throw const FormatException('Server pembaruan belum bisa dihubungi.');
  }

  Future<List<int>> _bytes(HttpClientResponse response, int maximum) async {
    final data = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      data.addAll(chunk);
      if (data.length > maximum) throw const FormatException('Metadata terlalu besar.');
    }
    return data;
  }

  String _error(Object error) => switch (error) {
    FormatException() => error.message,
    SocketException() => 'Tidak ada koneksi. Coba lagi saat terhubung.',
    TimeoutException() => 'Koneksi terlalu lama. Coba lagi.',
    PlatformException() => error.message ?? 'Android menolak APK pembaruan.',
    _ => 'Pembaruan gagal. Periksa koneksi dan ruang penyimpanan, lalu coba lagi.',
  };

  @override
  void dispose() {
    _disposed = true;
    _client?.close(force: true);
    super.dispose();
  }
}

class _Cancelled implements Exception { const _Cancelled(); }

/// Integrity is checked before the native APK identity/signature checks.
Future<void> verifyDownloadedApk(File file, ReleaseManifest manifest) async {
  if (await file.length() != manifest.sizeBytes ||
      (await sha256.bind(file.openRead()).first).toString() != manifest.sha256) {
    throw const FormatException('Unduhan tidak utuh. Unduh ulang pembaruan.');
  }
}
