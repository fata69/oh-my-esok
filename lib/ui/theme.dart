import 'package:material_ui/material_ui.dart';

class _Palette {
  const _Palette({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.control,
    required this.selected,
    required this.line,
    required this.outline,
    required this.ink,
    required this.muted,
  });

  final Color canvas;
  final Color surface;
  final Color subtle;
  final Color control;
  final Color selected;
  final Color line;
  final Color outline;
  final Color ink;
  final Color muted;
}

const _lightPalette = _Palette(
  canvas: Color(0xFFFCFCFC),
  surface: Color(0xFFFFFFFF),
  subtle: Color(0xFFF9F9F9),
  control: Color(0xFFF0F0F0),
  selected: Color(0xFFE0E0E0),
  line: Color(0xFFD9D9D9),
  outline: Color(0xFF8D8D8D),
  ink: Color(0xFF202020),
  muted: Color(0xFF646464),
);

const _darkPalette = _Palette(
  canvas: Color(0xFF111111),
  surface: Color(0xFF191919),
  subtle: Color(0xFF191919),
  control: Color(0xFF222222),
  selected: Color(0xFF313131),
  line: Color(0xFF3A3A3A),
  outline: Color(0xFF6E6E6E),
  ink: Color(0xFFEEEEEE),
  muted: Color(0xFFB4B4B4),
);

class EsokColors {
  EsokColors._();

  static bool _dark = false;

  static bool get isDark => _dark;

  static void useDark(bool value) {
    _dark = value;
  }

  static _Palette get _p => _dark ? _darkPalette : _lightPalette;

  static const scrim = Color(0x52000000);

  static Color get canvas => _p.canvas;
  static Color get surface => _p.surface;
  static Color get soft => _p.control;
  static Color get selected => _p.selected;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get line => _p.line;
  static Color get accent => _p.ink;

  // Keep the semantic roles for existing screens. Their labels, signs and
  // checkmarks convey the meaning independently of hue.
  static Color get positive => _p.ink;
  static Color get negative => _p.ink;
  static Color get done => _p.ink;
  static Color get lateSurface => _p.control;
  static Color get lateInk => _p.ink;
  static Color get inkSoft => _p.muted;
  static Color get disabled => _p.outline;
  static Color get lineStrong => _p.line;
  static Color get barFill => _p.muted;
  static Color get chevron => _p.outline;
  static Color get handle => _p.outline;
  static Color get fabText => _p.canvas;
  static Color get onAccent => _p.canvas;
  static Color get track => _p.control;
}

class EsokTheme {
  EsokTheme._();

  static const _fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _build(_lightPalette, Brightness.light);

  static ThemeData dark() => _build(_darkPalette, Brightness.dark);

  static ThemeData _build(_Palette p, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.ink,
        onPrimary: p.canvas,
        primaryContainer: p.selected,
        onPrimaryContainer: p.ink,
        secondary: p.ink,
        onSecondary: p.canvas,
        error: p.ink,
        onError: p.canvas,
        surface: p.canvas,
        onSurface: p.ink,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.surface,
        surfaceContainerLow: p.subtle,
        surfaceContainer: p.control,
        surfaceContainerHigh: p.control,
        surfaceContainerHighest: p.selected,
        outline: p.outline,
        outlineVariant: p.line,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: p.canvas,
      fontFamily: _fontFamily,
    );
    return base.copyWith(
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
      ).apply(fontFamily: _fontFamily),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkRipple.splashFactory,
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
              side: BorderSide(color: p.ink, width: 1.5),
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
        dialBackgroundColor: p.control,
        dialHandColor: p.ink,
        hourMinuteColor: p.control,
        dayPeriodColor: p.control,
        entryModeIconColor: p.muted,
      ),
    );
  }
}
