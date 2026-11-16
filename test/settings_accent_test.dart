import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/state/settings_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'accent persists across stores and leaves other preferences intact',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'hide_amounts': true,
        'lead_minutes': 30,
        'ai_model': 'synthetic-model',
      });
      final settings = SettingsStore();
      addTearDown(settings.dispose);
      await settings.init();
      expect(settings.accentId, 'blue');
      var notifications = 0;
      settings.addListener(() => notifications++);
      await settings.setAccentId('copper');
      expect(notifications, 1);
      expect(settings.accentId, 'copper');
      final reloaded = SettingsStore();
      addTearDown(reloaded.dispose);
      await reloaded.init();
      expect(reloaded.accentId, 'copper');
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.hideAmounts, isTrue);
      expect(reloaded.leadMinutes, 30);
      expect(reloaded.aiModel, 'synthetic-model');
      await settings.setAccentId('rose');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accent_id'), 'rose');
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('hide_amounts'), isTrue);
    },
  );

  for (final invalid in <Object>[
    'unknown',
    '',
    'BLUE',
    42,
    true,
    ['rose'],
  ]) {
    test('malformed persisted accent $invalid falls back to blue', () async {
      SharedPreferences.setMockInitialValues({'accent_id': invalid});
      final settings = SettingsStore();
      addTearDown(settings.dispose);
      await settings.init();
      expect(settings.accentId, 'blue');
      await settings.setAccentId('rose');
      expect(settings.accentId, 'rose');
    });
  }

  test('invalid setter input does not overwrite a valid choice', () async {
    SharedPreferences.setMockInitialValues({'accent_id': 'copper'});
    final settings = SettingsStore();
    addTearDown(settings.dispose);
    await settings.init();
    await expectLater(settings.setAccentId('invalid'), throwsArgumentError);
    expect(settings.accentId, 'copper');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accent_id'), 'copper');
  });
}
