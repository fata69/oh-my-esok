import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

class EsokPalette {
  const EsokPalette._({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.control,
    required this.selected,
    required this.line,
    required this.outline,
    required this.ink,
    required this.muted,
    required this.action,
    required this.onAction,
    required this.accentContainer,
    required this.tint,
    required this.success,
    required this.destructive,
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
  final Color action;
  final Color onAction;
  final Color accentContainer;
  final Color tint;
  final Color success;
  final Color destructive;

  Color get soft => control;
  Color get accent => tint;
  Color get positive => tint;
  Color get negative => destructive;
  Color get done => tint;
  Color get lateSurface => control;
  Color get lateInk => destructive;
  Color get inkSoft => muted;
  Color get disabled => outline;
  Color get lineStrong => line;
  Color get barFill => muted;
  Color get chevron => outline;
  Color get handle => outline;
  Color get fabText => onAction;
  Color get onAccent => onAction;
  Color get track => control;
}

/// Apple HIG Light Grouped Surface Hierarchy (#F2F2F7 canvas, #FFFFFF cards).
const _lightPalette = EsokPalette._(
  canvas: Color(0xFFF2F2F7),
  surface: Color(0xFFFFFFFF),
  subtle: Color(0xFFFFFFFF),
  control: Color(0xFFE8E8ED),
  selected: Color(0xFFDCDCE3),
  line: Color(0xFFDFDFE5),
  outline: Color(0xFF8E8E93),
  ink: Color(0xFF111113),
  muted: Color(0xFF636366),
  action: Color(0xFF007AFF),
  onAction: Color(0xFFFFFFFF),
  accentContainer: Color(0xFFE5F0FF),
  tint: Color(0xFF007AFF),
  success: Color(0xFF28A745),
  destructive: Color(0xFFD92D20),
);

/// Apple HIG AMOLED Dark Grouped Surface Hierarchy (#000000 canvas, #1C1C1E cards).
const _darkPalette = EsokPalette._(
  canvas: Color(0xFF000000),
  surface: Color(0xFF1C1C1E),
  subtle: Color(0xFF1C1C1E),
  control: Color(0xFF2C2C2E),
  selected: Color(0xFF3A3A3C),
  line: Color(0xFF2F2F34),
  outline: Color(0xFF7C7C82),
  ink: Color(0xFFF5F5F7),
  muted: Color(0xFF98989F),
  action: Color(0xFF0A84FF),
  onAction: Color(0xFFFFFFFF),
  accentContainer: Color(0xFF10243E),
  tint: Color(0xFF0A84FF),
  success: Color(0xFF30D158),
  destructive: Color(0xFFFF453A),
);

class EsokColors {
  EsokColors._();

  static Color tint(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF0A84FF)
      : const Color(0xFF007AFF);

  static Color incomeInk(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF4DA3FF)
      : const Color(0xFF007AFF);

  static Color expenseInk(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFFF9F0A)
      : const Color(0xFFD95E0E);

  static Color successInk(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF30D158)
      : const Color(0xFF28A745);

  static Color destructiveInk(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFFF453A)
      : const Color(0xFFD92D20);

  static Color hairline(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0x1FFFFFFF)
      : const Color(0x213C3C43);

  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));
  static const cardRadius = BorderRadius.all(Radius.circular(20));

  /// Use this in widgets so offscreen tabs subscribe to the inherited theme.
  static EsokPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkPalette
      : _lightPalette;

  // Bridge for older screens that haven't been converted to contextual colors.
  static bool _dark = false;

  static bool get isDark => _dark;

  static void useDark(bool value) {
    _dark = value;
  }

  static EsokPalette get _p => _dark ? _darkPalette : _lightPalette;

  static const scrim = Color(0x52000000);

  static Color get canvas => _p.canvas;
  static Color get surface => _p.surface;
  static Color get soft => _p.soft;
  static Color get selected => _p.selected;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get line => _p.line;
  static Color get accent => _p.accent;

  static Color get positive => _p.positive;
  static Color get negative => _p.negative;
  static Color get done => _p.done;
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

  static const _fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _build(_lightPalette, Brightness.light);

  static ThemeData dark() => _build(_darkPalette, Brightness.dark);

  static ThemeData _build(EsokPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final sep = EsokColors.hairline(brightness);
    final base = ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.tint,
        onPrimary: p.onAction,
        primaryContainer: p.accentContainer,
        onPrimaryContainer: p.tint,
        secondary: p.ink,
        onSecondary: p.canvas,
        error: p.destructive,
        onError: Colors.white,
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
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
          color: p.ink,
        ),
      ),
      textTheme: base.textTheme
          .copyWith(
            headlineMedium: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.7,
              color: p.ink,
            ),
            headlineSmall: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.18,
              letterSpacing: -0.6,
              color: p.ink,
            ),
            titleLarge: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.18,
              letterSpacing: -0.45,
              color: p.ink,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.32,
              letterSpacing: -0.2,
              color: p.ink,
            ),
            titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              letterSpacing: -0.1,
              color: p.ink,
            ),
            bodyLarge: TextStyle(
              fontSize: 15.5,
              height: 1.4,
              letterSpacing: -0.1,
              color: p.ink,
            ),
            bodyMedium: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: p.muted,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: p.muted,
            ),
            labelSmall: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: p.muted,
            ),
          )
          .apply(fontFamily: _fontFamily),
      dividerTheme: DividerThemeData(color: sep, thickness: 0.6, space: 1),
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.ink.withValues(alpha: isDark ? 0.08 : 0.05),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.success;
          return p.control;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.tint,
          foregroundColor: p.onAction,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.tint,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surface,
        selectedColor: p.ink,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.muted,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.surface,
        ),
        side: BorderSide(color: sep),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : p.ink,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: isDark ? p.ink : Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: EsokColors.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: EsokColors.sheetRadius,
        ),
        dragHandleColor: p.outline.withValues(alpha: 0.6),
        dragHandleSize: const Size(36, 4.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          height: 1.45,
          color: p.muted,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.surface,
        headerForegroundColor: p.ink,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return p.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.tint;
          return Colors.transparent;
        }),
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayForegroundColor: WidgetStatePropertyAll(p.tint),
        todayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        todayBorder: BorderSide(color: p.tint, width: 1.5),
        rangePickerBackgroundColor: p.surface,
        dividerColor: sep,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        dialBackgroundColor: p.control,
        dialHandColor: p.tint,
        hourMinuteColor: p.control,
        dayPeriodColor: p.control,
        entryModeIconColor: p.muted,
      ),
    );
  }
}
