import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'home_page.dart';
import 'money_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class EsokShell extends StatefulWidget {
  const EsokShell({super.key});

  @override
  State<EsokShell> createState() => _EsokShellState();
}

class _EsokShellState extends State<EsokShell> {
  int _index = 0;

  void _selectTab(int index) {
    if (_index != index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    EsokColors.useDark(isDark);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: true,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: EsokColors.canvas,
        // Keep the list painting behind the capsule. Scaffold reports the
        // measured bar height in the bottom padding of the body's MediaQuery.
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(onOpenMoney: () => _selectTab(1)),
            const MoneyPage(),
            const SettingsPage(),
          ],
        ),
        bottomNavigationBar: keyboardVisible
            ? null
            : Visibility(
                visible: routeIsCurrent,
                // A modal route owns the controls while it is open. Keep
                // the measured spacer so the underlying list doesn't jump.
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _FloatingTabBar(index: _index, onChanged: _selectTab),
              ),
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.index, required this.onChanged});

  static const _forceSolid = bool.fromEnvironment('ESOK_SOLID_NAV');
  static const _radius = BorderRadius.all(Radius.circular(40));
  static final _blur = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  static const _tabs = [
    ('Hari', Icons.event_note_outlined),
    ('Uang', Icons.account_balance_wallet_outlined),
    ('Setelan', Icons.settings_outlined),
  ];

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid =
        _forceSolid ||
        highContrast ||
        MediaQuery.accessibleNavigationOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    final tint = colors.surfaceContainerLow;
    // A bright list item behind the dark bar needs a stronger scrim.
    final tintOpacity = colors.brightness == Brightness.dark ? 0.96 : 0.92;
    final capsule = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? tint : tint.withValues(alpha: tintOpacity),
        borderRadius: _radius,
        border: Border.all(
          color: highContrast ? colors.outline : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavItem(
                  label: _tabs[i].$1,
                  icon: _tabs[i].$2,
                  selected: index == i,
                  highContrast: highContrast,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(
        bottom: MediaQuery.systemGestureInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(
              borderRadius: _radius,
              child: solid
                  ? capsule
                  : BackdropFilter(filter: _blur, child: capsule),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inverted = selected && highContrast;
    final foreground = inverted
        ? colors.surface
        : selected || highContrast
        ? colors.onSurface
        : colors.onSurfaceVariant;
    final interactionColor = selected
        ? foreground.withValues(alpha: 0.08)
        : colors.surfaceContainerHigh;
    const radius = BorderRadius.all(Radius.circular(32));
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: inverted
            ? colors.onSurface
            : selected
            ? colors.primaryContainer
            : Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        animationDuration: Duration.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          focusColor: interactionColor,
          hoverColor: interactionColor,
          highlightColor: interactionColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      letterSpacing: 0,
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
