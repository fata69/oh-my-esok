import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_controller.dart';

/// A quiet availability check. Download and install remain on UpdatePage.
class UpdateAvailability extends ChangeNotifier {
  UpdateAvailability({
    UpdateController Function()? controllerFactory,
    DateTime Function()? now,
  }) : _controllerFactory = controllerFactory ?? UpdateController.new,
       _now = now ?? DateTime.now;

  static final instance = UpdateAvailability();
  static const _previewKey = 'ota_allow_preview';
  static const _attemptKey = 'ota_last_auto_check_ms';
  static const _hintKey = 'ota_available_update';
  static const interval = Duration(hours: 6);

  final UpdateController Function() _controllerFactory;
  final DateTime Function() _now;
  Future<void>? _loading;
  late SharedPreferences _prefs;
  int? _installedCode;
  bool _allowPreview = false;
  bool _available = false;
  bool _checking = false;
  int _channelRevision = 0;

  bool get allowPreview => _allowPreview;
  bool get available => _available;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _allowPreview = _prefs.getBool(_previewKey) ?? false;
    final info = await PackageInfo.fromPlatform();
    _installedCode = int.tryParse(info.buildNumber);
    final hint = _prefs.getStringList(_hintKey);
    _available =
        hint != null &&
        hint.length == 3 &&
        _installedCode != null &&
        hint[0] == '$_installedCode' &&
        (int.tryParse(hint[1]) ?? 0) > _installedCode! &&
        (hint[2] == 'stable' || (hint[2] == 'preview' && _allowPreview));
    notifyListeners();
  }

  Future<void> setAllowPreview(bool value) async {
    await load();
    if (_allowPreview == value) return;
    if (!await _prefs.setBool(_previewKey, value)) {
      throw StateError('Preferensi prarilis tidak dapat disimpan.');
    }
    _allowPreview = value;
    _channelRevision++;
    if (!value && _prefs.getStringList(_hintKey)?.lastOrNull == 'preview') {
      _available = false;
      await _prefs.remove(_hintKey);
    }
    notifyListeners();
  }

  Future<void> checkAutomatically() async {
    if (_checking) return;
    _checking = true;
    try {
      await load();
      if (_installedCode == null || _installedCode! <= 0) return;
      final now = _now().millisecondsSinceEpoch;
      final previous = _prefs.getInt(_attemptKey);
      if (previous != null && now - previous < interval.inMilliseconds) return;
      // Record the attempt before requesting anything, including failures.
      if (!await _prefs.setInt(_attemptKey, now)) return;
      final revision = _channelRevision;
      final controller = _controllerFactory()..allowPreview = _allowPreview;
      try {
        await controller.check();
        if (_channelRevision == revision) await recordResult(controller);
      } finally {
        controller.dispose();
      }
    } catch (_) {
      // The automatic check has no error or loading UI.
    } finally {
      _checking = false;
    }
  }

  Future<void> recordResult(UpdateController controller) async {
    await load();
    if (controller.allowPreview != _allowPreview) return;
    final release = controller.release;
    if (controller.phase == UpdatePhase.available &&
        release != null &&
        controller.installedCode > 0 &&
        controller.installedCode == _installedCode &&
        release.newerThan(controller.installedCode) &&
        (!release.preview || _allowPreview)) {
      _channelRevision++;
      final hint = [
        '${controller.installedCode}',
        '${release.versionCode}',
        release.preview ? 'preview' : 'stable',
      ];
      final saved = _prefs.setStringList(_hintKey, hint);
      _setAvailable(true);
      await saved;
    } else if (controller.phase == UpdatePhase.upToDate ||
        controller.phase == UpdatePhase.noRelease) {
      _channelRevision++;
      final removed = _prefs.remove(_hintKey);
      _setAvailable(false);
      await removed;
    }
  }

  void _setAvailable(bool value) {
    if (_available == value) return;
    _available = value;
    notifyListeners();
  }
}
