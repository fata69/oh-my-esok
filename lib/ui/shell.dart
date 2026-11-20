import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../update/update_availability.dart';
import 'agenda_loading.dart';
import 'glass_controls.dart';
import 'home_page.dart';
import 'money_page.dart';
import 'motion.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'tab_layout.dart';
import 'theme.dart';

class EsokShell extends StatefulWidget {
  const EsokShell({super.key});

  @override
  State<EsokShell> createState() => _EsokShellState();
}

class _EsokShellState extends State<EsokShell> with WidgetsBindingObserver {
  final _home = GlobalKey<HomePageState>();
  final _showNotes = ValueNotifier(false);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(UpdateAvailability.instance.checkAutomatically());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(UpdateAvailability.instance.checkAutomatically());
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) WidgetsBinding.instance.removeObserver(this);
    _showNotes.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_index != index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    EsokColors.useDark(Theme.of(context).brightness == Brightness.dark);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    return _ShellFrame(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _TabPane(
            active: _index == 0,
            child: HomePage(
              key: _home,
              onOpenMoney: () => _selectTab(1),
              onNotesChanged: (notes) => _showNotes.value = notes,
            ),
          ),
          _TabPane(active: _index == 1, child: const MoneyPage()),
          _TabPane(active: _index == 2, child: const ReportsPage()),
          _TabPane(active: _index == 3, child: const SettingsPage()),
        ],
      ),
      dock: keyboardVisible
          ? null
          : Visibility(
              visible: routeIsCurrent,
              // Preserve the measured space while a modal owns the controls.
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: ValueListenableBuilder<bool>(
                valueListenable: _showNotes,
                builder: (context, notes, _) => _FloatingTabBar(
                  index: _index,
                  onChanged: _selectTab,
                  action: switch (_index) {
                    0 => (
                      notes ? 'Tambah catatan' : 'Tambah agenda',
                      () => _home.currentState?.createEntry(),
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

class EsokLoadingShell extends StatelessWidget {
  const EsokLoadingShell({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final loading = onRetry == null;
    return _ShellFrame(
      body: EsokTabLayout(
        headerAction: loading
            ? ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: EsokGlass(
                      radius: const BorderRadius.all(Radius.circular(20)),
                      shadow: false,
                      child: SizedBox.square(
                        dimension: 38,
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          size: 19,
                          color: EsokColors.of(context).muted,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        period: loading
            ? const ExcludeSemantics(
                child: Column(
                  children: [EsokPeriodHeader.loading(), DaySectionSwitch()],
                ),
              )
            : null,
        child: loading
            ? const AgendaLoading(label: 'Membuka Oh My Esok')
            : ListView(
                padding: const EdgeInsets.all(EsokTabLayout.gutter),
                children: [
                  const Text('Aplikasi belum bisa dibuka.'),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onRetry,
                      child: const Text('Coba lagi'),
                    ),
                  ),
                ],
              ),
      ),
      dock: loading
          ? IgnorePointer(
              child: ExcludeFocus(
                child: ExcludeSemantics(
                  child: _FloatingTabBar(
                    index: 0,
                    onChanged: (_) {},
                    action: ('Tambah agenda', () {}),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ShellFrame extends StatelessWidget {
  const _ShellFrame({required this.body, required this.dock});

  final Widget body;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: EsokColors.of(context).canvas,
        // Let content flow cleanly underneath the floating Liquid Glass dock.
        extendBody: true,
        body: body,
        bottomNavigationBar: dock,
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
    final reduced = EsokMotion.reduced(context);
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
                  : widget.active
                  ? EsokMotion.enter
                  : EsokMotion.exit,
              curve: EsokMotion.settle,
              onEnd: () {
                if (widget.active || !_visible) return;
                // A zero-duration change can finish while the child builds.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !widget.active && _visible) {
                    setState(() => _visible = false);
                  }
                });
              },
              child: AnimatedScale(
                scale: reduced || widget.active ? 1.0 : 0.988,
                duration: reduced ? Duration.zero : EsokMotion.enter,
                curve: EsokMotion.settle,
                child: widget.child,
              ),
            ),
          ),
        ),
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
    with TickerProviderStateMixin {
  static const _forceSolid = bool.fromEnvironment('ESOK_SOLID_NAV');
  static const _radius = BorderRadius.all(Radius.circular(40));
  static const _tabs = [
    ('Hari', CupertinoIcons.calendar, CupertinoIcons.calendar_today),
    ('Uang', CupertinoIcons.creditcard, CupertinoIcons.creditcard_fill),
    ('Laporan', CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill),
    ('Setelan', CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill),
  ];

  static const _addSize = 52.0;
  static const _gap = 8.0;
  static const _revealDistance = 26.0;
  static const _enter = SpringDescription(mass: 1, stiffness: 760, damping: 42);
  static const _exit = SpringDescription(mass: 1, stiffness: 760, damping: 54);
  // Retargetable Apple spring for the floating liquid selection lens.
  static const _glide = SpringDescription(mass: 1, stiffness: 400, damping: 32);
  late final _reveal = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );
  late final _indicator = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  bool _solid = false;
  double get _target => widget.action == null ? 0 : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final solid =
        _forceSolid ||
        MediaQuery.highContrastOf(context) ||
        EsokMotion.reduced(context);
    if (solid && !_solid) {
      _reveal.value = _target;
      _indicator.value = widget.index.toDouble();
    }
    _solid = solid;
  }

  @override
  void didUpdateWidget(covariant _FloatingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      final destination = widget.index.toDouble();
      if (_solid) {
        _indicator.value = destination;
      } else {
        // Carry the velocity forward when a tap interrupts the glide.
        _indicator.animateWith(
          SpringSimulation(
            _glide,
            _indicator.value,
            destination,
            _indicator.velocity,
            tolerance: const Tolerance(distance: .006, velocity: .2),
            snapToEnd: true,
          ),
        );
      }
    }
    if ((oldWidget.action == null) == (widget.action == null)) return;
    if (_solid) {
      _reveal.value = _target;
      return;
    }
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
    _indicator.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final colors = EsokColors.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final primary = widget.action;

    // Organic translucent glass selection lens (no stiff sticker border).
    final lensColor = highContrast
        ? colors.ink
        : dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.065);

    final capsule = EsokGlass(
      key: const ValueKey('floating-navigation'),
      radius: _radius,
      forceSolid: _solid,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabs.length,
                  heightFactor: 1,
                  child: AnimatedBuilder(
                    animation: _indicator,
                    builder: (context, pill) {
                      final velocityStretch = _solid
                          ? 0.0
                          : (_indicator.velocity.abs() * 0.011).clamp(
                              0.0,
                              0.14,
                            );
                      return FractionalTranslation(
                        translation: Offset(
                          _indicator.value.clamp(0.0, _tabs.length - 1.0),
                          0,
                        ),
                        child: Transform.scale(
                          scaleX: 1.0 + velocityStretch,
                          scaleY: 1.0 - velocityStretch * 0.25,
                          child: pill,
                        ),
                      );
                    },
                    child: DecoratedBox(
                      key: const ValueKey('dock-selection'),
                      decoration: BoxDecoration(
                        color: lensColor,
                        borderRadius: _radius,
                        boxShadow: highContrast || dark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  blurRadius: 0.5,
                                  offset: const Offset(0, -0.5),
                                ),
                              ],
                      ),
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
                      activeIcon: _tabs[i].$3,
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

    final button = ApplePressable(
      scale: 0.93,
      child: EsokGlass(
        radius: _radius,
        forceSolid: _solid,
        child: SizedBox.square(
          key: primary == null ? null : const ValueKey('bottom-create'),
          dimension: _addSize,
          child: Material(
            type: MaterialType.transparency,
            child: IconButton(
              tooltip: primary?.$1 ?? 'Tambah',
              onPressed: primary?.$2,
              icon: const Icon(CupertinoIcons.add, size: 25),
              style: IconButton.styleFrom(
                foregroundColor: colors.ink,
                disabledForegroundColor: colors.muted,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 368),
            child: AnimatedBuilder(
              animation: _reveal,
              child: capsule,
              builder: (context, nav) {
                final progress = _reveal.value.clamp(0.0, 1.0);
                final offset = (_revealDistance * (_reveal.value - 1)).clamp(
                  -_revealDistance,
                  2.0,
                );
                final hidden = primary == null || progress <= .001;
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final inverted = selected && highContrast;
    final foreground = inverted
        ? colors.canvas
        : selected
        ? colors.tint
        : highContrast
        ? colors.ink
        : colors.muted;
    final keyboardFocusColor = selected
        ? foreground.withValues(alpha: 0.10)
        : colors.control;
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
        type: MaterialType.transparency,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        animationDuration: Duration.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          focusColor: keyboardFocusColor,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? activeIcon : icon, size: 21, color: foreground),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        letterSpacing: -0.1,
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
