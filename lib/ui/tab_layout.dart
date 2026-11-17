import 'package:material_ui/material_ui.dart';

import 'chevron.dart';
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
  const EsokTabLayout({super.key, this.headerAction, required this.child});

  static const gutter = 24.0;

  // The shell's extended body reports the full, measured navigation height here.
  // Let the list scroll behind it, with enough space to reveal the final row.
  static double scrollBottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 16;

  final Widget? headerAction;
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
    this.caption,
    this.detail,
    this.onSelect,
  });

  final String title;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final String? caption;
  final String? detail;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final period = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact && caption != null) ...[
            Text(
              caption!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      height: 1.14,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
              ),
              if (onSelect != null) ...[
                const SizedBox(width: 7),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: colors.muted,
                ),
              ],
            ],
          ),
          if (!compact && detail != null) ...[
            const SizedBox(height: 3),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsokTabLayout.gutter,
        compact ? 0 : 8,
        EsokTabLayout.gutter,
        compact ? 0 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: onSelect == null
                ? period
                : InkWell(
                    onTap: onSelect,
                    borderRadius: BorderRadius.circular(8),
                    child: period,
                  ),
          ),
          const SizedBox(width: 10),
          Material(
            color: colors.soft,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PeriodArrow(
                  label: previousLabel,
                  left: true,
                  onTap: onPrevious,
                ),
                Container(width: 1, height: 18, color: colors.line),
                _PeriodArrow(label: nextLabel, left: false, onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      tooltip: label,
      onPressed: onTap,
      icon: Opacity(
        opacity: onTap == null ? 0.32 : 1,
        child: EsokChevron(left: left, size: 16),
      ),
    );
  }
}
