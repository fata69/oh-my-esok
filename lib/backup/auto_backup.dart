import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

/// Cadangan otomatis ke `Download/Oh My Esok/oh-my-esok-backup.json`.
///
/// Ditulis lewat MediaStore, jadi berkasnya bertahan walau aplikasi
/// di-uninstall dan bisa dibaca lagi setelah instal ulang.
class AutoBackup {
  AutoBackup._();

  static const _channel = MethodChannel('esok/settings');
  static const fileName = 'oh-my-esok-backup.json';
  static const _checksumKey = 'backup_checksum';
  static const _timeKey = 'backup_at';

  static String? lastError;

  static Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_timeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<bool> runIfChanged({bool force = false}) async {
    lastError = null;
    try {
      final data = await BackupService.collect();
      final json = const JsonEncoder.withIndent(
        '  ',
      ).convert(BackupService.toJsonMap(data));
      final checksum = _checksum(json);

      final prefs = await SharedPreferences.getInstance();
      if (!force && prefs.getString(_checksumKey) == checksum) return false;

      final ok =
          await _channel.invokeMethod<bool>('writeBackup', {
            'name': fileName,
            'content': json,
          }) ??
          false;
      if (!ok) {
        lastError = 'Gagal menulis ke Download/Oh My Esok.';
        return false;
      }

      final modified = await _channel.invokeMethod<int>('backupModifiedAt', {
        'name': fileName,
      });
      if (modified == null) {
        lastError = 'Berkas cadangan tidak ditemukan setelah ditulis.';
        return false;
      }

      await prefs.setString(_checksumKey, checksum);
      await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } on PlatformException catch (error) {
      lastError = error.message ?? 'Gagal menulis cadangan.';
      debugPrint('AutoBackup gagal: ${error.code} ${error.message}');
      return false;
    } catch (error, stack) {
      lastError = 'Gagal membuat cadangan: $error';
      debugPrint('AutoBackup gagal: $error\n$stack');
      return false;
    }
  }

  /// Membaca cadangan terakhir. `null` bila belum pernah ada.
  static Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('readBackup', {
        'name': fileName,
      });
    } catch (error) {
      debugPrint('AutoBackup.read gagal: $error');
      return null;
    }
  }

  static Future<BackupData?> readParsed() async {
    final raw = await read();
    if (raw == null || raw.isEmpty) return null;
    try {
      return await BackupService.parseJsonBytes(
        Uint8List.fromList(utf8.encode(raw)),
      );
    } catch (error) {
      debugPrint('AutoBackup.readParsed gagal: $error');
      return null;
    }
  }

  static String _checksum(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
