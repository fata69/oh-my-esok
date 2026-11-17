import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        MediaQuery.reduceMotionOf(context) ||
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
                if (widget.active || !_visible) return;
                // A zero-duration change can finish while the child builds.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !widget.active && _visible) {
                    setState(() => _visible = false);
                  }
                });
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

class _FloatingTabBar extends StatefulWidget {
  const _FloatingTabBar({
    required this.index,
    required this.onChanged,
    this.action,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final (String, VoidCallback)? action;

  @override
  State<_FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<_FloatingTabBar>
    with SingleTickerProviderStateMixin {
  static const _forceSolid = bool.fromEnvironment('ESOK_SOLID_NAV');
  static const _radius = BorderRadius.all(Radius.circular(40));
  static final _blur = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  static const _tabs = [
    ('Hari', Icons.event_note_outlined, Color(0xFF1558D4), Color(0xFF548CFF)),
    (
      'Uang',
      Icons.account_balance_wallet_outlined,
      Color(0xFF08754A),
      Color(0xFF39D58D),
    ),
    ('Laporan', Icons.bar_chart_outlined, Color(0xFFA34B0A), Color(0xFFF6A343)),
    ('Setelan', Icons.settings_outlined, Color(0xFF663CBC), Color(0xFFA988FF)),
  ];

  static const _addSize = 52.0;
  static const _gap = 8.0;
  static const _revealDistance = 26.0;
  static const _enter = SpringDescription(mass: 1, stiffness: 800, damping: 44);
  static const _exit = SpringDescription(mass: 1, stiffness: 800, damping: 57);
  late final _reveal = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );

  bool _solid = false;
  double get _target => widget.action == null ? 0 : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final solid =
        _forceSolid ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        MediaQuery.reduceMotionOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    if (solid && !_solid) _reveal.value = _target;
    _solid = solid;
  }

  @override
  void didUpdateWidget(covariant _FloatingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.action == null) == (widget.action == null)) return;
    if (_solid) {
      _reveal.value = _target;
      return;
    }
    // One spring drives the space and the circle. Retarget from live position
    // and velocity so interrupting a tab switch keeps the glass in motion.
    _reveal.animateWith(
      SpringSimulation(
        _target == 1 ? _enter : _exit,
        _reveal.value,
        _target,
        _reveal.velocity,
        tolerance: const Tolerance(distance: .005, velocity: .08),
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid = _solid;
    final tint = colors.surfaceContainerLow;
    // A bright list item behind the dark bar needs a stronger scrim.
    final tintOpacity = colors.brightness == Brightness.dark ? 0.96 : 0.92;
    final primary = widget.action;
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
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(
                  2 * widget.index / (_tabs.length - 1) - 1,
                  0,
                ),
                duration: solid
                    ? Duration.zero
                    : const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabs.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: highContrast
                          ? colors.onSurface
                          : colors.brightness == Brightness.dark
                          ? const Color(0xFF292929)
                          : const Color(0xFFE9E9EC),
                      borderRadius: _radius,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      label: _tabs[i].$1,
                      icon: _tabs[i].$2,
                      iconColor: colors.brightness == Brightness.dark
                          ? _tabs[i].$4
                          : _tabs[i].$3,
                      selected: widget.index == i,
                      highContrast: highContrast,
                      onTap: () => widget.onChanged(i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final button = ClipOval(
      child: BackdropFilter(
        filter: solid ? ui.ImageFilter.blur() : _blur,
        child: Container(
          key: primary == null ? null : const ValueKey('bottom-create'),
          width: _addSize,
          height: _addSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? tint : tint.withValues(alpha: tintOpacity),
            border: Border.all(color: edge),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: IconButton(
              tooltip: primary?.$1 ?? 'Tambah',
              onPressed: primary?.$2,
              icon: const Icon(Icons.add_rounded, size: 25),
              style: IconButton.styleFrom(
                foregroundColor: ink,
                shape: const CircleBorder(),
              ),
            ),
          ),
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
            child: AnimatedBuilder(
              animation: _reveal,
              child: ClipRRect(
                key: const ValueKey('floating-navigation'),
                borderRadius: _radius,
                child: solid
                    ? capsule
                    : BackdropFilter(filter: _blur, child: capsule),
              ),
              builder: (context, nav) {
                final progress = _reveal.value.clamp(0.0, 1.0);
                final offset = (_revealDistance * (_reveal.value - 1)).clamp(
                  -_revealDistance,
                  2.0,
                );
                final hidden = primary == null || progress <= .001;
                // The bar covers the intact circle until its right edge
                // emerges. Keep its 52 dp size and the dock's centerline.
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    Positioned(
                      right: 0,
                      child: ExcludeSemantics(
                        excluding: hidden,
                        child: IgnorePointer(
                          ignoring: hidden,
                          child: Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(offset, 0),
                              child: button,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: nav!),
                        SizedBox(
                          key: const ValueKey('create-accessory-slot'),
                          width: (_addSize + _gap) * progress,
                          height: _addSize,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Color _dockInk(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFFF0F0F0)
    : const Color(0xFF1558D4);

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  static const _reportGlyph = '''<svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"
      stroke-linecap="round" stroke-linejoin="round">
      <rect x="3" y="13" width="4" height="8" rx="1"/>
      <rect x="10" y="5" width="4" height="16" rx="1"/>
      <rect x="17" y="9" width="4" height="12" rx="1"/>
    </svg>''';

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
    final glyphInk = highContrast ? foreground : iconColor;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
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
                  if (icon == Icons.bar_chart_outlined)
                    SvgPicture.string(
                      _reportGlyph,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(glyphInk, BlendMode.srcIn),
                    )
                  else
                    Icon(icon, size: 20, color: glyphInk),
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
