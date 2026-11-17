import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'home_page.dart';
import 'money_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class EsokShell extends StatefulWidget {
  const EsokShell({super.key});

  @override
  State<EsokShell> createState() => _EsokShellState();
}

class _EsokShellState extends State<EsokShell> {
  final _home = GlobalKey<HomePageState>();
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
        backgroundColor: EsokColors.of(context).canvas,
        // The extended body exposes the measured height of the chrome and
        // the system inset. Bound the tabs with a persistent creation action.
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _TabPane(
              active: _index == 0,
              child: _AboveDock(
                child: HomePage(key: _home, onOpenMoney: () => _selectTab(1)),
              ),
            ),
            _TabPane(
              active: _index == 1,
              child: const _AboveDock(child: MoneyPage()),
            ),
            _TabPane(
              active: _index == 2,
              child: const _AboveDock(child: ReportsPage()),
            ),
            _TabPane(active: _index == 3, child: const SettingsPage()),
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
                child: _FloatingTabBar(
                  index: _index,
                  onChanged: _selectTab,
                  action: switch (_index) {
                    0 => (
                      'Tambah catatan',
                      () => _home.currentState?.createNote(),
                    ),
                    1 => (
                      'Catat transaksi',
                      () => MoneyPage.createTransaction(context),
                    ),
                    _ => null,
                  },
                ),
              ),
      ),
    );
  }
}

class _TabPane extends StatefulWidget {
  const _TabPane({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<_TabPane> {
  late bool _visible = widget.active;

  @override
  void didUpdateWidget(_TabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _visible = true;
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Offstage(
      offstage: !widget.active && (reduced || !_visible),
      child: TickerMode(
        enabled: widget.active || _visible,
        child: ExcludeSemantics(
          excluding: !widget.active,
          child: IgnorePointer(
            ignoring: !widget.active,
            child: AnimatedOpacity(
              opacity: widget.active ? 1 : 0,
              duration: reduced
                  ? Duration.zero
                  : Duration(milliseconds: widget.active ? 240 : 160),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (mounted && !widget.active && _visible)
                  setState(() => _visible = false);
              },
              child: AnimatedSlide(
                offset: widget.active ? Offset.zero : const Offset(.018, 0),
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboveDock extends StatelessWidget {
  const _AboveDock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.index,
    required this.onChanged,
    this.action,
  });

  static const _forceSolid = bool.fromEnvironment('ESOK_SOLID_NAV');
  static const _radius = BorderRadius.all(Radius.circular(40));
  static final _blur = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  static const _tabs = [
    ('Hari', Icons.event_note_outlined),
    ('Uang', Icons.account_balance_wallet_outlined),
    ('Laporan', Icons.bar_chart_outlined),
    ('Setelan', Icons.settings_outlined),
  ];

  final int index;
  final ValueChanged<int> onChanged;
  final (String, VoidCallback)? action;

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
    final primary = action;
    final edge = highContrast ? colors.outline : colors.outlineVariant;
    final ink = highContrast ? colors.onSurface : _dockInk(colors.brightness);
    final capsule = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? tint : tint.withValues(alpha: tintOpacity),
        borderRadius: _radius,
        border: Border.all(color: edge),
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
      // The OS navigation bar inset already protects both system modes.
      // The larger gesture-detection zone would lift this tap-only control.
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ClipRRect(
                    key: const ValueKey('floating-navigation'),
                    borderRadius: _radius,
                    child: solid
                        ? capsule
                        : BackdropFilter(filter: _blur, child: capsule),
                  ),
                ),
                AnimatedContainer(
                  key: const ValueKey('create-accessory-slot'),
                  width: primary == null ? 0 : 60,
                  height: 52,
                  duration: solid
                      ? Duration.zero
                      : const Duration(milliseconds: 340),
                  curve: Curves.easeInOutCubic,
                  child: ClipRect(
                    clipBehavior: Clip.hardEdge,
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      minWidth: 52,
                      maxWidth: 52,
                      child: IgnorePointer(
                        ignoring: primary == null,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: primary == null ? 0 : 1),
                          duration: solid
                              ? Duration.zero
                              : const Duration(milliseconds: 420),
                          curve: primary == null
                              ? Curves.easeInCubic
                              : Curves.easeOutBack,
                          builder: (context, progress, child) => Opacity(
                            opacity: progress.clamp(0, 1),
                            child: Transform.translate(
                              offset: Offset(-12 * (1 - progress), 0),
                              child: Transform.scale(
                                scale: .86 + .14 * progress,
                                child: child,
                              ),
                            ),
                          ),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: solid ? ui.ImageFilter.blur() : _blur,
                              child: Container(
                                key: primary == null
                                    ? null
                                    : const ValueKey('bottom-create'),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: solid
                                      ? tint
                                      : tint.withValues(alpha: tintOpacity),
                                  border: Border.all(color: edge),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: IconButton(
                                    tooltip: primary?.$1 ?? 'Tambah',
                                    onPressed: primary?.$2,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 25,
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: ink,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _dockInk(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF9DBDFF)
    : const Color(0xFF1558D4);

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
    final dark = colors.brightness == Brightness.dark;
    final selectedInk = _dockInk(colors.brightness);
    final selectedTint = dark
        ? const Color(0xFF242D40)
        : const Color(0xFFEAF0FA);
    final inverted = selected && highContrast;
    final foreground = inverted
        ? colors.surface
        : selected
        ? selectedInk
        : highContrast
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
            ? selectedTint
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        letterSpacing: 0,
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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
