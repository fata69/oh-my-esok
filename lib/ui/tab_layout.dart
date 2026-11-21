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

/// Sleek Apple iOS 26 tab scaffold: compact Liquid Glass top toolbar + Large Title.
class EsokTabLayout extends StatelessWidget {
  const EsokTabLayout({
    super.key,
    this.toolbarLeading,
    this.headerAction,
    this.eyebrow,
    this.largeTitle,
    this.largeTitleTrailing,
    this.belowHeader,
    this.period,
    required this.child,
  });

  static const gutter = 20.0;

  // The shell's extended body reports the full, measured navigation height here.
  // Let the list scroll behind it, with enough space to reveal the final row.
  static double scrollBottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 20;

  final Widget? toolbarLeading;
  final Widget? headerAction;
  final String? eyebrow;
  final String? largeTitle;
  final Widget? largeTitleTrailing;
  final Widget? belowHeader;
  final Widget? period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final leading = toolbarLeading ?? period;
    final hasToolbar = leading != null || headerAction != null;
    final hasTitle = largeTitle != null || eyebrow != null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasToolbar)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                compact ? 2 : 8,
                gutter,
                compact ? 2 : 4,
              ),
              child: Row(
                children: [
                  if (leading != null)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: leading,
                      ),
                    )
                  else
                    const Spacer(),
                  if (headerAction != null) ...[
                    if (leading != null) const SizedBox(width: 8),
                    headerAction!,
                  ],
                ],
              ),
            ),
          if (hasTitle)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter + 2,
                hasToolbar ? (compact ? 2 : 8) : (compact ? 4 : 12),
                gutter + 2,
                compact ? 4 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eyebrow != null)
                          Text(
                            eyebrow!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: colors.muted,
                            ),
                          ),
                        if (largeTitle != null)
                          Semantics(
                            header: true,
                            child: Text(
                              largeTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontSize: compact ? 24 : 30,
                                height: 1.15,
                                letterSpacing: -0.7,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (largeTitleTrailing != null) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: largeTitleTrailing!,
                    ),
                  ],
                ],
              ),
            ),
          ?belowHeader,
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Compact, content-hugging Liquid Glass date/month pill (Apple iOS 26 toolbar style).
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
    this.centered = false,
  }) : _loading = false;

  const EsokPeriodHeader.loading({super.key, this.centered = false})
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
  final bool centered;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final pillHeight = compact ? 34.0 : 38.0;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 13.5,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: colors.ink,
    );

    final pill = EsokGlass(
      radius: const BorderRadius.all(Radius.circular(22)),
      shadow: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: pillHeight),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodArrow(
              label: previousLabel,
              left: true,
              height: pillHeight,
              onTap: onPrevious,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: EsokSkeletonBlock(width: 82, height: 11, radius: 5),
              )
            else if (onSelect == null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              )
            else
              Flexible(
                child: Tooltip(
                  message: selectLabel,
                  child: InkWell(
                    onTap: onSelect,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                  ),
                ),
              ),
            _PeriodArrow(
              label: nextLabel,
              left: false,
              height: pillHeight,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );

    if (!centered) return pill;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, compact ? 0 : 4, 8, compact ? 4 : 8),
      child: Center(child: pill),
    );
  }
}

/// Compact 38dp circular Liquid Glass icon button for the top Apple toolbar.
class EsokToolbarIconButton extends StatelessWidget {
  const EsokToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final size = compact ? 34.0 : 38.0;
    final fg = color ?? (active ? colors.tint : colors.ink);
    return ApplePressable(
      child: Tooltip(
        message: tooltip,
        child: EsokGlass(
          radius: const BorderRadius.all(Radius.circular(20)),
          shadow: false,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: 17, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact 38dp stadium Liquid Glass action pill (e.g. "Tutup hari") for the top toolbar.
class EsokToolbarPillButton extends StatelessWidget {
  const EsokToolbarPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.compactLabelWhenTight = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool compactLabelWhenTight;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.height < 480;
    final height = compact ? 34.0 : 38.0;
    final fg = color ?? colors.tint;
    final iconOnly =
        compactLabelWhenTight &&
        (media.size.width < 355 || media.textScaler.scale(13) > 19);

    if (iconOnly) {
      return EsokToolbarIconButton(
        icon: icon,
        tooltip: label,
        onTap: onTap,
        color: fg,
      );
    }

    return ApplePressable(
      child: Tooltip(
        message: label,
        child: EsokGlass(
          radius: const BorderRadius.all(Radius.circular(20)),
          shadow: false,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool left;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return ApplePressable(
      child: IconButton(
        tooltip: label.isEmpty ? null : label,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: 34, minHeight: height),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colors.ink,
        ),
        icon: Opacity(
          opacity: onTap == null ? 0.25 : 0.72,
          child: Icon(
            left ? CupertinoIcons.chevron_left : CupertinoIcons.chevron_right,
            size: 13,
          ),
        ),
      ),
    );
  }
}
