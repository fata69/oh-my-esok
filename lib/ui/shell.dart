import 'dart:async';
import 'dart:io';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
            child: _AboveDock(
              child: HomePage(
                key: _home,
                onOpenMoney: () => _selectTab(1),
                onNotesChanged: (notes) => _showNotes.value = notes,
              ),
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
      body: _AboveDock(
        child: EsokTabLayout(
          headerAction: loading
              ? ExcludeSemantics(
                  child: IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.more_horiz, size: 20),
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
              child: widget.child,
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
    with TickerProviderStateMixin {
  static const _forceSolid = bool.fromEnvironment('ESOK_SOLID_NAV');
  static const _radius = BorderRadius.all(Radius.circular(40));
  static const _tabs = [
    (
      'Hari',
      '<rect x="4" y="5" width="16" height="16" rx="2"/>'
          '<path d="M8 3v4m8-4v4M4 10h16M8 14h3m-3 3h6"/>',
    ),
    (
      'Uang',
      '<path d="M19 8V4H6a2 2 0 0 0 0 4h14v13H6a2 2 0 0 1-2-2V6'
          'm13 6h4v5h-4a2.5 2.5 0 0 1 0-5Zm.2 2.5h.1"/>',
    ),
    (
      'Laporan',
      '<rect x="3" y="13" width="4" height="8" rx="1"/>'
          '<rect x="10" y="5" width="4" height="16" rx="1"/>'
          '<rect x="17" y="9" width="4" height="12" rx="1"/>',
    ),
    (
      'Setelan',
      '<path d="m9.5 3-.6 2.2-2 .9-2-.6L3 9l1.6 1.6v2.8L3 15l1.9 3.5'
          ' 2-.6 2 .9.6 2.2h5l.6-2.2 2-.9 2 .6 1.9-3.5-1.6-1.6v-2.8'
          'L21 9l-1.9-3.5-2 .6-2-.9-.6-2.2Z"/><circle cx="12" cy="12" r="3"/>',
    ),
  ];

  static const _addSize = 52.0;
  static const _gap = 8.0;
  static const _revealDistance = 26.0;
  static const _enter = SpringDescription(mass: 1, stiffness: 800, damping: 44);
  static const _exit = SpringDescription(mass: 1, stiffness: 800, damping: 57);
  // Match the Morphe pill's stiffness and 0.8 damping ratio at unit mass.
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
    _indicator.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final primary = widget.action;
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
                    builder: (context, pill) => FractionalTranslation(
                      // Move the painted pill in tab units without laying out
                      // the icons and labels again on each frame.
                      translation: Offset(
                        _indicator.value.clamp(0.0, _tabs.length - 1.0),
                        0,
                      ),
                      child: pill,
                    ),
                    child: DecoratedBox(
                      key: const ValueKey('dock-selection'),
                      decoration: BoxDecoration(
                        color: highContrast
                            ? colors.onSurface
                            : colors.surfaceContainerHighest,
                        border: highContrast
                            ? null
                            : Border.all(color: colors.outlineVariant),
                        borderRadius: _radius,
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

    final button = EsokGlass(
      radius: _radius,
      emphasized: true,
      forceSolid: _solid,
      child: SizedBox.square(
        key: primary == null ? null : const ValueKey('bottom-create'),
        dimension: _addSize,
        child: Material(
          type: MaterialType.transparency,
          child: IconButton(
            tooltip: primary?.$1 ?? 'Tambah',
            onPressed: primary?.$2,
            icon: const Icon(Icons.add_rounded, size: 30),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: const CircleBorder(),
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
              child: capsule,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  final String label;
  final String icon;
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
    final keyboardFocusColor = selected
        ? foreground.withValues(alpha: 0.08)
        : colors.surfaceContainerHigh;
    const radius = BorderRadius.all(Radius.circular(32));
    final stroke = selected ? 2.1 : 1.8;
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
                  SvgPicture.string(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
                    'fill="none" stroke="currentColor" stroke-width="$stroke" '
                    'stroke-linecap="round" stroke-linejoin="round">$icon</svg>',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                  ),
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
