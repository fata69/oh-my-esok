import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/sound_library.dart';

class SettingsStore extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _leadEnabledKey = 'lead_enabled';
  static const _leadMinutesKey = 'lead_minutes';
  static const _hideAmountsKey = 'hide_amounts';
  static const _soundEnabledKey = 'sound_enabled';
  static const _soundUpKey = 'sound_up_id';
  static const _soundDownKey = 'sound_down_id';
  static const _soundReminderKey = 'sound_reminder_id';
  static const _soundCheckKey = 'sound_check_id';
  static const _soundUncheckKey = 'sound_uncheck_id';
  static const _soundCompleteKey = 'sound_complete_id';
  static const _soundDoneLegacyKey = 'sound_done_id';
  static const _soundImportsKey = 'sound_imports';
  static const _aiApiKey = 'ai_api_key';
  static const _aiModelKey = 'ai_model';

  /// Alias model yang tidak ikut mati saat Google mempensiunkan versi tertentu.
  static const defaultAiModel = 'gemini-3.5-flash';

  ThemeMode _themeMode = ThemeMode.system;
  bool _leadEnabled = true;
  int _leadMinutes = 60;
  bool _hideAmounts = false;
  bool _soundEnabled = true;
  String _soundUpId = SoundLibrary.builtIn[0].id;
  String _soundDownId = SoundLibrary.builtIn[3].id;
  String _soundReminderId = SoundLibrary.builtIn[0].id;
  String _soundCheckId = SoundLibrary.builtIn[1].id;
  String _soundUncheckId = SoundLibrary.builtIn[2].id;
  String _soundCompleteId = SoundLibrary.builtIn[0].id;
  List<SoundOption> _importedSounds = const [];
  String _aiKey = '';
  String _aiModel = defaultAiModel;

  ThemeMode get themeMode => _themeMode;
  bool get leadEnabled => _leadEnabled;
  int get leadMinutes => _leadMinutes;
  bool get hideAmounts => _hideAmounts;
  bool get soundEnabled => _soundEnabled;

  List<SoundOption> get allSounds => [
    ...SoundLibrary.builtIn,
    ..._importedSounds,
  ];

  SoundOption get soundUp => SoundLibrary.resolve(
    _soundUpId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[0],
  );

  SoundOption get soundDown => SoundLibrary.resolve(
    _soundDownId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[3],
  );

  SoundOption get soundReminder => SoundLibrary.resolve(
    _soundReminderId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[0],
  );

  SoundOption get soundCheck => SoundLibrary.resolve(
    _soundCheckId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[1],
  );

  SoundOption get soundUncheck => SoundLibrary.resolve(
    _soundUncheckId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[2],
  );

  SoundOption get soundComplete => SoundLibrary.resolve(
    _soundCompleteId,
    _importedSounds,
    fallback: SoundLibrary.builtIn[0],
  );

  String get aiKey => _aiKey;
  String get aiModel => _aiModel;
  bool get aiReady => _aiKey.trim().isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeKey)) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    _leadEnabled = prefs.getBool(_leadEnabledKey) ?? true;
    _leadMinutes = prefs.getInt(_leadMinutesKey) ?? 60;
    _hideAmounts = prefs.getBool(_hideAmountsKey) ?? false;
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _soundUpId = prefs.getString(_soundUpKey) ?? _soundUpId;
    _soundDownId = prefs.getString(_soundDownKey) ?? _soundDownId;
    _soundReminderId = prefs.getString(_soundReminderKey) ?? _soundReminderId;
    _soundCheckId =
        prefs.getString(_soundCheckKey) ??
        prefs.getString(_soundDoneLegacyKey) ??
        _soundCheckId;
    _soundUncheckId =
        prefs.getString(_soundUncheckKey) ?? _soundUncheckId;
    _soundCompleteId =
        prefs.getString(_soundCompleteKey) ?? _soundCompleteId;
    _importedSounds = _decodeImports(prefs.getString(_soundImportsKey));
    _aiKey = prefs.getString(_aiApiKey) ?? '';
    final storedModel = prefs.getString(_aiModelKey);
    _aiModel = (storedModel == null || storedModel == 'gemini-2.5-flash')
        ? defaultAiModel
        : storedModel;
    notifyListeners();
  }

  Future<void> setAiKey(String value) async {
    if (_aiKey == value) return;
    _aiKey = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiApiKey, value);
  }

  Future<void> setAiModel(String value) async {
    final model = value.trim().isEmpty ? defaultAiModel : value.trim();
    if (_aiModel == model) return;
    _aiModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiModelKey, model);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setLeadEnabled(bool enabled) async {
    if (_leadEnabled == enabled) return;
    _leadEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_leadEnabledKey, enabled);
  }

  Future<void> setLeadMinutes(int minutes) async {
    if (_leadMinutes == minutes) return;
    _leadMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leadMinutesKey, minutes);
  }

  Future<void> setHideAmounts(bool value) async {
    if (_hideAmounts == value) return;
    _hideAmounts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAmountsKey, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setSoundUp(String id) async {
    if (_soundUpId == id) return;
    _soundUpId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundUpKey, id);
  }

  Future<void> setSoundDown(String id) async {
    if (_soundDownId == id) return;
    _soundDownId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundDownKey, id);
  }

  Future<void> setSoundReminder(String id) async {
    if (_soundReminderId == id) return;
    _soundReminderId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundReminderKey, id);
  }

  Future<void> setSoundCheck(String id) async {
    if (_soundCheckId == id) return;
    _soundCheckId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundCheckKey, id);
  }

  Future<void> setSoundUncheck(String id) async {
    if (_soundUncheckId == id) return;
    _soundUncheckId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundUncheckKey, id);
  }

  Future<void> setSoundComplete(String id) async {
    if (_soundCompleteId == id) return;
    _soundCompleteId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundCompleteKey, id);
  }

  Future<void> addImportedSound(SoundOption option) async {
    if (_importedSounds.any((item) => item.id == option.id)) return;
    _importedSounds = [..._importedSounds, option];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _soundImportsKey,
      jsonEncode(_importedSounds.map((item) => item.toJson()).toList()),
    );
  }

  List<SoundOption> _decodeImports(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(SoundOption.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
