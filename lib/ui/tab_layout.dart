import 'package:material_ui/material_ui.dart';

import 'chevron.dart';
import 'motion.dart';
import 'theme.dart';

/// A quiet surface for one related group of content, with room for row ink.
class EsokContentGroup extends StatelessWidget {
  const EsokContentGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _groupColor(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

Color _groupColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF141414)
    : const Color(0xFFF3F3F5);

/// Separate list children share one silhouette while still building lazily.
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
    const radius = Radius.circular(16);
    return Material(
      color: _groupColor(context),
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
      MediaQuery.paddingOf(context).bottom + 16;

  final Widget? headerAction;
  final Widget? period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              6,
              headerAction == null ? gutter : 12,
              0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Oh My Esok',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          height: 1.2,
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
      fontSize: 20,
      height: 1.14,
      fontWeight: FontWeight.w700,
      letterSpacing: -.35,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 6, 16, compact ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 292),
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
                            height: (textScaler.scale(20) * 1.14 + 8).clamp(
                              48.0,
                              double.infinity,
                            ),
                            child: const Center(
                              child: EsokSkeletonBlock(width: 124, height: 14),
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
                                  const SizedBox(width: 16),
                                  Flexible(
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: titleStyle,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
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
          if (!compact && _loading)
            SizedBox(
              height:
                  textScaler.scale(detailStyle.fontSize!) * detailStyle.height!,
              child: const Center(
                child: EsokSkeletonBlock(width: 82, height: 8),
              ),
            )
          else if (!compact && detail != null)
            Text(detail!, textAlign: TextAlign.center, style: detailStyle),
        ],
      ),
    );
  }
}

/// Presents a date picker with the app's shared route treatment.
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

/// A rounded, opaque panel for date controls, with a fixed dismiss action.
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
        : colors.line;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            side: BorderSide(color: rim),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 9),
                SizedBox(
                  width: 32,
                  height: 4,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.handle,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 5, 12, 0),
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
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          visualDensity: VisualDensity.standard,
                          foregroundColor: colors.ink,
                          backgroundColor: colors.control,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
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
    return IconButton(
      tooltip: label.isEmpty ? null : label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        visualDensity: VisualDensity.standard,
      ),
      icon: Opacity(
        opacity: onTap == null ? 0.32 : 1,
        child: EsokChevron(left: left, size: 16),
      ),
    );
  }
}
