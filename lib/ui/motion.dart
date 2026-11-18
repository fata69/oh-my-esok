import 'package:material_ui/material_ui.dart';

abstract final class EsokMotion {
  static const enter = Duration(milliseconds: 240);
  static const exit = Duration(milliseconds: 190);
  static const feedback = Duration(milliseconds: 120);
  static const settle = Curves.easeOutCubic;

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
          reverseCurve: Curves.easeInCubic,
        );
}

/// Give Android routes the same timing as tabs while retaining gesture-driven
/// back and its native preview of the previous screen.
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
