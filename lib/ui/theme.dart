import 'package:material_ui/material_ui.dart';

class _Palette {
  const _Palette({
    required this.canvas,
    required this.surface,
    required this.soft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.positive,
    required this.negative,
    required this.lateSurface,
    required this.lateInk,
    required this.inkSoft,
    required this.disabled,
    required this.lineStrong,
    required this.barFill,
    required this.chevron,
    required this.handle,
    required this.fabText,
    required this.onAccent,
    required this.track,
  });

  final Color canvas;
  final Color surface;
  final Color soft;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color positive;
  final Color negative;
  final Color lateSurface;
  final Color lateInk;
  final Color inkSoft;
  final Color disabled;
  final Color lineStrong;
  final Color barFill;
  final Color chevron;
  final Color handle;
  final Color fabText;
  final Color onAccent;
  final Color track;
}

const _lightPalette = _Palette(
  canvas: Color(0xFFFAF9F7),
  surface: Color(0xFFFFFFFF),
  soft: Color(0xFFF2F0EA),
  ink: Color(0xFF1A1917),
  muted: Color(0xFF6B6862),
  line: Color(0xFFE5E2DC),
  accent: Color(0xFF8F4A16),
  positive: Color(0xFF2F7D4F),
  negative: Color(0xFFB03A2E),
  lateSurface: Color(0xFFF3E7DE),
  lateInk: Color(0xFF5A3A20),
  inkSoft: Color(0xFF3E3B33),
  disabled: Color(0xFFC4BFB3),
  lineStrong: Color(0xFFD9D4C9),
  barFill: Color(0xFF8E887C),
  chevron: Color(0xFFB9B4A7),
  handle: Color(0xFFD5D0C4),
  fabText: Color(0xFFFFFFFF),
  onAccent: Color(0xFFFFFFFF),
  track: Color(0xFFEFECE5),
);

const _darkPalette = _Palette(
  canvas: Color(0xFF14130F),
  surface: Color(0xFF1C1B17),
  soft: Color(0xFF1F1E19),
  ink: Color(0xFFF2F0EA),
  muted: Color(0xFF9A968C),
  line: Color(0xFF2A2823),
  accent: Color(0xFFE08A4B),
  positive: Color(0xFF5FAE7C),
  negative: Color(0xFFE07A63),
  lateSurface: Color(0xFF2A1D14),
  lateInk: Color(0xFFE0A57F),
  inkSoft: Color(0xFFD6D1C6),
  disabled: Color(0xFF5D594F),
  lineStrong: Color(0xFF3A372F),
  barFill: Color(0xFF6E6A5F),
  chevron: Color(0xFF6E6A5F),
  handle: Color(0xFF3A372F),
  fabText: Color(0xFF14130F),
  onAccent: Color(0xFF14130F),
  track: Color(0xFF2A2823),
);

class EsokColors {
  EsokColors._();

  static bool _dark = false;

  static bool get isDark => _dark;

  static void useDark(bool value) {
    _dark = value;
  }

  static _Palette get _p => _dark ? _darkPalette : _lightPalette;

  static Color get canvas => _p.canvas;
  static Color get surface => _p.surface;
  static Color get soft => _p.soft;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get line => _p.line;
  static Color get accent => _p.accent;
  static Color get positive => _p.positive;
  static Color get negative => _p.negative;
  static Color get done => positive;
  static Color get lateSurface => _p.lateSurface;
  static Color get lateInk => _p.lateInk;
  static Color get inkSoft => _p.inkSoft;
  static Color get disabled => _p.disabled;
  static Color get lineStrong => _p.lineStrong;
  static Color get barFill => _p.barFill;
  static Color get chevron => _p.chevron;
  static Color get handle => _p.handle;
  static Color get fabText => _p.fabText;
  static Color get onAccent => _p.onAccent;
  static Color get track => _p.track;
}

class EsokTheme {
  EsokTheme._();

  static ThemeData light() => _build(_lightPalette, Brightness.light);

  static ThemeData dark() => _build(_darkPalette, Brightness.dark);

  static ThemeData _build(_Palette p, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.canvas,
      fontFamily: 'PlusJakartaSans',
    );
    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: p.positive,
        onSecondary: isDark ? p.canvas : p.surface,
        error: p.negative,
        onError: isDark ? p.canvas : p.surface,
        surface: p.canvas,
        onSurface: p.ink,
        outline: p.line,
        outlineVariant: p.line,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.02,
          color: p.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -0.02,
          color: p.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 1.35,
          color: p.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: p.ink),
        bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
        labelSmall: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.09,
          color: p.muted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(color: p.canvas, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: p.muted,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.canvas,
        headerForegroundColor: p.ink,
        dayForegroundColor: WidgetStatePropertyAll(p.ink),
        dayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        dayShape: WidgetStateProperty.resolveWith<OutlinedBorder?>((states) {
          if (states.contains(WidgetState.selected)) {
            return CircleBorder(
              side: BorderSide(color: p.accent, width: 1.5),
            );
          }
          return const CircleBorder();
        }),
        todayForegroundColor: WidgetStatePropertyAll(p.ink),
        todayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        todayBorder: BorderSide(color: p.ink, width: 1.5),
        rangePickerBackgroundColor: p.canvas,
        dividerColor: p.line,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.canvas,
        dialBackgroundColor: p.soft,
        dialHandColor: p.ink,
        hourMinuteColor: p.soft,
        dayPeriodColor: p.soft,
        entryModeIconColor: p.muted,
      ),
    );
  }
}
