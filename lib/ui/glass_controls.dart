import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';
import 'theme.dart';

/// Crystal iOS 26 Liquid Glass material for floating navigation and controls.
///
/// Uses genuine low-opacity translucency, real-time backdrop blur, directional
/// specular rim lighting, and soft ambient elevation — with an automatic opaque
/// fallback for high-contrast and reduced-motion accessibility modes.
class EsokGlass extends StatelessWidget {
  const EsokGlass({
    super.key,
    required this.radius,
    required this.child,
    this.emphasized = false,
    this.forceSolid = false,
    this.shadow = true,
  });

  static final _blur = ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22);

  final BorderRadius radius;
  final Widget child;
  final bool emphasized;
  final bool forceSolid;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid = forceSolid || highContrast || EsokMotion.reduced(context);

    final solidFill = emphasized
        ? (dark ? colors.control : colors.ink)
        : colors.surface;

    final glassFill = emphasized
        ? (dark
              ? const Color(0xFF1F2024).withValues(alpha: 0.62)
              : const Color(0xFF18191D).withValues(alpha: 0.80))
        : (dark
              ? const Color(0xFF1C1C20).withValues(alpha: 0.46)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.48));

    final innerContent = CustomPaint(
      foregroundPainter: _LiquidGlassRimPainter(
        radius: radius,
        dark: dark,
        highContrast: highContrast,
        emphasized: emphasized,
        highContrastColor: colors.outline,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: solid ? solidFill : glassFill,
          gradient: solid
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.42, 1.0],
                  colors: dark
                      ? [
                          Colors.white.withValues(
                            alpha: emphasized ? 0.14 : 0.10,
                          ),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.04),
                        ]
                      : [
                          Colors.white.withValues(
                            alpha: emphasized ? 0.16 : 0.42,
                          ),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(
                            alpha: emphasized ? 0.06 : 0.24,
                          ),
                        ],
                ),
        ),
        child: child,
      ),
    );

    final clipped = ClipRRect(
      borderRadius: radius,
      child: solid
          ? innerContent
          : BackdropFilter(filter: _blur, child: innerContent),
    );

    if (!shadow) return clipped;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.52),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 1.5),
                ),
              ],
      ),
      child: clipped,
    );
  }
}

/// Paints a directional 1px optical specular rim around a Liquid Glass capsule.
class _LiquidGlassRimPainter extends CustomPainter {
  const _LiquidGlassRimPainter({
    required this.radius,
    required this.dark,
    required this.highContrast,
    required this.emphasized,
    required this.highContrastColor,
  });

  final BorderRadius radius;
  final bool dark;
  final bool highContrast;
  final bool emphasized;
  final Color highContrastColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highContrast ? 1.2 : 0.95;

    if (highContrast) {
      paint.color = highContrastColor;
    } else if (dark || emphasized) {
      paint.shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          Colors.white.withValues(alpha: dark ? 0.38 : 0.32),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: dark ? 0.20 : 0.16),
        ],
        const [0.0, 0.34, 0.64, 1.0],
      );
    } else {
      paint.shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.38),
          const Color(0xFF0F172A).withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.72),
        ],
        const [0.0, 0.32, 0.60, 1.0],
      );
    }
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.dark != dark ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.emphasized != emphasized ||
      oldDelegate.highContrastColor != highContrastColor;
}

/// Apple iOS-style Segmented Control with retargetable spring thumb animation.
class EsokSegmentedControl<T> extends StatefulWidget {
  const EsokSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<EsokSegmentedControl<T>> createState() =>
      _EsokSegmentedControlState<T>();
}

class _EsokSegmentedControlState<T> extends State<EsokSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  int get _selectedIndex {
    final idx = widget.segments.indexWhere((s) => s.$1 == widget.value);
    return idx < 0 ? 0 : idx;
  }

  late final AnimationController _thumb = AnimationController.unbounded(
    vsync: this,
    value: _selectedIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant EsokSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _selectedIndex.toDouble();
    if ((_thumb.value - target).abs() < 0.001) return;
    if (EsokMotion.reduced(context)) {
      _thumb.value = target;
      return;
    }
    _thumb.animateWith(
      SpringSimulation(
        EsokMotion.springFluid,
        _thumb.value,
        target,
        _thumb.velocity,
        tolerance: const Tolerance(distance: 0.004, velocity: 0.05),
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _thumb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.segments.length;
    final compact = MediaQuery.sizeOf(context).height < 480;
    const outerRadius = BorderRadius.all(Radius.circular(13));
    const innerRadius = BorderRadius.all(Radius.circular(10));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF767680).withValues(alpha: 0.24)
            : const Color(0xFF767680).withValues(alpha: 0.12),
        borderRadius: outerRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: AnimatedBuilder(
                    animation: _thumb,
                    builder: (context, child) => FractionalTranslation(
                      translation: Offset(
                        _thumb.value.clamp(0.0, (count - 1).toDouble()),
                        0,
                      ),
                      child: child,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dark ? colors.selected : colors.surface,
                        borderRadius: innerRadius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: dark ? 0.30 : 0.08,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 1.5),
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
                for (final (value, label) in widget.segments)
                  Expanded(
                    child: Semantics(
                      container: true,
                      button: true,
                      selected: value == widget.value,
                      inMutuallyExclusiveGroup: true,
                      label: label,
                      onTap: () => widget.onChanged(value),
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => widget.onChanged(value),
                        borderRadius: innerRadius,
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: compact ? 30 : 36,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: compact ? 2 : 6,
                            ),
                            child: Center(
                              heightFactor: 1,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: -0.1,
                                  fontWeight: value == widget.value
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: value == widget.value
                                      ? colors.ink
                                      : colors.muted,
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
          ],
        ),
      ),
    );
  }
}

class EsokMenuAction<T> {
  const EsokMenuAction(this.value, this.label, this.icon, {this.selected});

  final T value;
  final String label;
  final IconData icon;
  final bool? selected;
}

class EsokGlassMenu<T> extends StatelessWidget {
  const EsokGlassMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
    this.dividerBefore,
    this.trigger,
  });

  final String tooltip;
  final List<EsokMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final int? dividerBefore;
  final Widget? trigger;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final defaultTrigger = EsokGlass(
      radius: const BorderRadius.all(Radius.circular(20)),
      shadow: false,
      child: SizedBox.square(
        dimension: 38,
        child: Center(
          child: Icon(
            CupertinoIcons.ellipsis,
            size: 19,
            color: colors.ink,
          ),
        ),
      ),
    );

    return ApplePressable(
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        menuPadding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 228, maxWidth: 288),
        popUpAnimationStyle: EsokMotion.presentation(context),
        onSelected: onSelected,
        itemBuilder: (_) => [
          _GlassMenuItems(actions: actions, dividerBefore: dividerBefore),
        ],
        child: trigger ??
            SizedBox.square(
              dimension: 48,
              child: Center(child: defaultTrigger),
            ),
      ),
    );
  }
}

// One route entry provides a single clipped material around grouped menu items.
class _GlassMenuItems<T> extends PopupMenuEntry<T> {
  const _GlassMenuItems({required this.actions, required this.dividerBefore});

  final List<EsokMenuAction<T>> actions;
  final int? dividerBefore;

  @override
  double get height => actions.length * 48.0 + 12;

  @override
  bool represents(T? value) => actions.any((action) => action.value == value);

  @override
  State<_GlassMenuItems<T>> createState() => _GlassMenuItemsState<T>();
}

class _GlassMenuItemsState<T> extends State<_GlassMenuItems<T>> {
  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return EsokGlass(
      radius: const BorderRadius.all(Radius.circular(22)),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, action) in widget.actions.indexed) ...[
                if (index == widget.dividerBefore)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(),
                  ),
                PopupMenuItem<T>(
                  value: action.value,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      selected: action.selected,
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              action.icon,
                              size: 19,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(action.label)),
                          if (action.selected == true)
                            ExcludeSemantics(
                              child: Icon(
                                CupertinoIcons.checkmark,
                                size: 17,
                                color: colors.tint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
