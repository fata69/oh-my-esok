import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'motion.dart';
import 'theme.dart';

/// A frosted surface for floating navigation and contextual controls.
class EsokGlass extends StatelessWidget {
  const EsokGlass({
    super.key,
    required this.radius,
    required this.child,
    this.emphasized = false,
    this.forceSolid = false,
  });

  static final _blur = ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12);

  final BorderRadius radius;
  final Widget child;
  final bool emphasized;
  final bool forceSolid;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid = forceSolid || highContrast || EsokMotion.reduced(context);
    final fill = emphasized
        ? dark
              ? colors.selected
              : colors.ink
        : colors.surface;
    final rim = highContrast
        ? colors.outline
        : emphasized
        ? dark
              ? colors.outline
              : fill
        : colors.line;
    final surface = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: rim),
        borderRadius: radius,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: solid ? fill : null,
          gradient: solid
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .28],
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: dark ? .07 : .24),
                      fill,
                    ).withValues(alpha: .94),
                    fill.withValues(alpha: emphasized || !dark ? .94 : .9),
                  ],
                ),
        ),
        child: child,
      ),
    );
    return ClipRRect(
      borderRadius: radius,
      child: solid ? surface : BackdropFilter(filter: _blur, child: surface),
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
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      icon: trigger == null
          ? Icon(Icons.more_horiz_rounded, size: 22, color: colors.ink)
          : null,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: colors.control,
        visualDensity: VisualDensity.standard,
      ),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 288),
      popUpAnimationStyle: EsokMotion.presentation(context),
      onSelected: onSelected,
      itemBuilder: (_) => [
        _GlassMenuItems(actions: actions, dividerBefore: dividerBefore),
      ],
      child: trigger,
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
                            const ExcludeSemantics(
                              child: Icon(Icons.check_rounded, size: 18),
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
