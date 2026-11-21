import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageRoute;
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

abstract final class EsokMotion {
  static const enter = Duration(milliseconds: 300);
  static const exit = Duration(milliseconds: 220);
  static const feedback = Duration(milliseconds: 140);
  static const settle = Cubic(0.32, 0.72, 0.0, 1.0);
  static const exitCurve = Cubic(0.32, 0.0, 0.67, 0.0);

  /// Critically-damped Apple interactive spring for glides and reveals.
  static const springFluid = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 32,
  );

  /// Snappy tactile spring for press-scale and micro-interactions.
  static const springSnappy = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 34,
  );

  /// Gentle spring for larger sheet detents and layout shifts.
  static const springGentle = SpringDescription(
    mass: 1,
    stiffness: 280,
    damping: 29,
  );

  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media != null &&
        (media.disableAnimations ||
            media.reduceMotion ||
            media.accessibleNavigation);
  }

  static AnimationStyle presentation(BuildContext context) => reduced(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: enter,
          reverseDuration: exit,
          curve: settle,
          reverseCurve: exitCurve,
        );

  /// Apple parallax push route with interactive edge-swipe back gesture.
  static PageRoute<T> route<T>(WidgetBuilder builder) =>
      CupertinoPageRoute<T>(builder: builder);
}

/// Tactile Apple-style spring press feedback for glass controls and cards.
class ApplePressable extends StatefulWidget {
  const ApplePressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<ApplePressable> createState() => _ApplePressableState();
}

class _ApplePressableState extends State<ApplePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  void _animateTo(double target) {
    if (!mounted) return;
    if (EsokMotion.reduced(context)) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        EsokMotion.springSnappy,
        _controller.value,
        target,
        _controller.velocity,
        tolerance: const Tolerance(distance: 0.002, velocity: 0.02),
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _animateTo(widget.scale),
      onPointerUp: (_) => _animateTo(1.0),
      onPointerCancel: (_) => _animateTo(1.0),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scale: _controller.value.clamp(0.90, 1.04),
          child: child,
        ),
      ),
    );
  }
}

/// Smooth Apple-timed route transitions while preserving Android predictive back.
class EsokPageTransitions extends PredictiveBackPageTransitionsBuilder {
  const EsokPageTransitions();

  @override
  Duration get transitionDuration => EsokMotion.enter;

  @override
  Duration get reverseTransitionDuration => EsokMotion.exit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (EsokMotion.reduced(context)) return child;
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
