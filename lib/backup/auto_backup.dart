import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_recovery.dart';
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
  static final recovery = BackupRecovery();

  static Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_timeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<bool> runIfChanged({bool force = false}) async {
    if (recovery.blocksBackup) {
      lastError = 'Cadangan ditunda selama pemulihan.';
      return false;
    }
    lastError = null;
    try {
      final data = await BackupService.collect();
      final json = const JsonEncoder.withIndent('  ')
          .convert(BackupService.toJsonMap(data));
      final checksum = _checksum(json);

      final prefs = await SharedPreferences.getInstance();
      if (!force && prefs.getString(_checksumKey) == checksum) return false;

      // Collection/preferences await native calls. Recheck before any write.
      if (recovery.blocksBackup) return false;
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

  static Future<({BackupData? data, bool unreadable})> readForRecovery() async {
    const args = {'name': fileName};
    try {
      final raw = await _channel.invokeMethod<String>('readBackup', args);
      if (raw == null) {
        // The native reader may return null for an existing unreadable file.
        final modified = await _channel.invokeMethod<int>(
          'backupModifiedAt',
          args,
        );
        return (data: null, unreadable: modified != null);
      }
      final data = await BackupService.parseJsonBytes(
        Uint8List.fromList(utf8.encode(raw)),
      );
      return (data: data.isEmpty ? null : data, unreadable: false);
    } catch (_) {
      return (data: null, unreadable: true);
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
