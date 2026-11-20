import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import 'glass_controls.dart';
import 'motion.dart';
import 'theme.dart';

/// Apple Inset Grouped Card surface for one related group of content.
class EsokContentGroup extends StatelessWidget {
  const EsokContentGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EsokColors.of(context).surface,
      borderRadius: EsokColors.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Separate list children share one Apple Inset Grouped Card silhouette lazily.
class EsokGroupedRow extends StatelessWidget {
  const EsokGroupedRow({
    super.key,
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(20);
    return Material(
      color: EsokColors.of(context).surface,
      borderRadius: BorderRadius.vertical(
        top: first ? radius : Radius.zero,
        bottom: last ? radius : Radius.zero,
      ),
      clipBehavior: first || last ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }
}

class EsokTabLayout extends StatelessWidget {
  const EsokTabLayout({
    super.key,
    this.headerAction,
    this.period,
    required this.child,
  });

  static const gutter = 24.0;

  // The shell's extended body reports the full, measured navigation height here.
  // Let the list scroll behind it, with enough space to reveal the final row.
  static double scrollBottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 20;

  final Widget? headerAction;
  final Widget? period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              compact ? 0 : 6,
              headerAction == null ? gutter : 12,
              0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 40 : 48),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Oh My Esok',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: compact ? 19 : 22,
                          height: 1.18,
                          letterSpacing: -0.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  ?headerAction,
                ],
              ),
            ),
          ),
          ?period,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class EsokPeriodHeader extends StatelessWidget {
  const EsokPeriodHeader({
    super.key,
    required this.title,
    required this.previousLabel,
    required this.nextLabel,
    this.onPrevious,
    required this.onNext,
    this.detail,
    required this.selectLabel,
    required this.onSelect,
  }) : _loading = false;

  const EsokPeriodHeader.loading({super.key})
    : title = '',
      previousLabel = '',
      nextLabel = '',
      onPrevious = null,
      onNext = null,
      detail = null,
      selectLabel = '',
      onSelect = null,
      _loading = true;

  final String title;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String? detail;
  final String selectLabel;
  final VoidCallback? onSelect;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final detailStyle = theme.textTheme.bodyMedium!;
    final textScaler = MediaQuery.textScalerOf(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      height: 1.16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 6, 16, compact ? 0 : 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 296),
              child: EsokGlass(
                radius: const BorderRadius.all(Radius.circular(28)),
                shadow: false,
                child: Row(
                  children: [
                    _PeriodArrow(
                      label: previousLabel,
                      left: true,
                      onTap: onPrevious,
                    ),
                    Expanded(
                      child: _loading
                          ? SizedBox(
                              height: (textScaler.scale(17) * 1.16 + 8).clamp(
                                48.0,
                                double.infinity,
                              ),
                              child: const Center(
                                child: EsokSkeletonBlock(
                                  width: 118,
                                  height: 13,
                                  radius: 6,
                                ),
                              ),
                            )
                          : onSelect == null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: titleStyle,
                              ),
                            )
                          : Tooltip(
                              message: selectLabel,
                              child: TextButton(
                                onPressed: onSelect,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  visualDensity: VisualDensity.standard,
                                  foregroundColor: colors.ink,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: titleStyle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      CupertinoIcons.chevron_down,
                                      size: 13,
                                      color: colors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    _PeriodArrow(label: nextLabel, left: false, onTap: onNext),
                  ],
                ),
              ),
            ),
          ),
          if (!compact && _loading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                height:
                    textScaler.scale(detailStyle.fontSize!) *
                    detailStyle.height!,
                child: const Center(
                  child: EsokSkeletonBlock(width: 82, height: 8),
                ),
              ),
            )
          else if (!compact && detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                detail!,
                textAlign: TextAlign.center,
                style: detailStyle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Presents a date picker with the app's shared Apple sheet treatment.
Future<T?> showEsokPickerSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  sheetAnimationStyle: EsokMotion.presentation(context),
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  barrierColor: EsokColors.scrim,
  builder: builder,
);

/// A rounded Apple sheet panel for date/month pickers with a grabber and dismiss pill.
class EsokPickerSheet extends StatelessWidget {
  const EsokPickerSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final rim = MediaQuery.highContrastOf(context)
        ? colors.outline
        : EsokColors.hairline(Theme.of(context).brightness);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: EsokColors.sheetRadius,
            side: BorderSide(color: rim, width: 0.75),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                SizedBox(
                  width: 36,
                  height: 4.5,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.handle.withValues(alpha: 0.55),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 6, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      ApplePressable(
                        child: IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(48),
                            visualDensity: VisualDensity.standard,
                            foregroundColor: colors.ink,
                            backgroundColor: colors.control,
                          ),
                          icon: const Icon(CupertinoIcons.xmark, size: 17),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: child,
                  ),
                ),
                if (footer case final action?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    child: action,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EsokSkeletonBlock extends StatelessWidget {
  const EsokSkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 4,
    this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? EsokColors.of(context).control,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SizedBox(width: width, height: height),
  );
}

class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({
    required this.label,
    required this.left,
    required this.onTap,
  });

  final String label;
  final bool left;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return ApplePressable(
      child: IconButton(
        tooltip: label.isEmpty ? null : label,
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          visualDensity: VisualDensity.standard,
          foregroundColor: colors.ink,
        ),
        icon: Opacity(
          opacity: onTap == null ? 0.28 : 0.78,
          child: Icon(
            left ? CupertinoIcons.chevron_left : CupertinoIcons.chevron_right,
            size: 16,
          ),
        ),
      ),
    );
  }
}
